#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

usage() {
    cat <<'USAGE'
Usage:

  add-package.sh \
      --package <package-name> \
      --manifest <relative-manifest-path> \
      [--profiles <profile1,profile2>] \
      [--no-install] \
      [--dry-run]

Examples:

  # Add an official package to an existing common manifest
  ./scripts/add-package.sh \
      --package firefox \
      --manifest common/07-applications.txt

  # Add an official package to a feature used by both machines
  ./scripts/add-package.sh \
      --package example \
      --manifest features/example.txt \
      --profiles amd-current,omen

  # Validate and record without installing on this machine
  ./scripts/add-package.sh \
      --no-install \
      --package example \
      --manifest hardware/omen-intel-nvidia.txt

Manifest paths are relative to packages/ and must be inside:

  common/
  features/
  hardware/

Only packages available from an enabled Pacman repository are accepted.

All modified package manifests and profile files are sorted automatically.

This script never stages, commits, or pushes changes.
USAGE
}

package_name=""
manifest_rel=""
profiles_csv=""
install_package=1
dry_run=0

while (($# > 0)); do
    case "$1" in
        --package)
            [[ $# -ge 2 ]] || {
                echo "Missing value for --package" >&2
                exit 1
            }
            package_name="$2"
            shift 2
            ;;
        --manifest)
            [[ $# -ge 2 ]] || {
                echo "Missing value for --manifest" >&2
                exit 1
            }
            manifest_rel="$2"
            shift 2
            ;;
        --profiles)
            [[ $# -ge 2 ]] || {
                echo "Missing value for --profiles" >&2
                exit 1
            }
            profiles_csv="$2"
            shift 2
            ;;
        --no-install)
            install_package=0
            shift
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$package_name" || -z "$manifest_rel" ]]; then
    usage >&2
    exit 1
fi

if [[ ! "$package_name" =~ ^[A-Za-z0-9][A-Za-z0-9@._+:-]*$ ]]; then
    echo "Invalid package name: $package_name" >&2
    exit 1
fi

if [[ "$manifest_rel" = /* ||
      "$manifest_rel" == *".."* ||
      "$manifest_rel" != *.txt ]]; then
    echo "Invalid manifest path: $manifest_rel" >&2
    echo "Use a relative .txt path without '..'." >&2
    exit 1
fi

case "$manifest_rel" in
    common/*.txt|features/*.txt|hardware/*.txt)
        ;;
    *)
        echo "Invalid manifest location: $manifest_rel" >&2
        echo "Allowed roots: common/, features/, hardware/" >&2
        exit 1
        ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_root="$repo_root/packages"
profiles_root="$packages_root/profiles"
resolver="$repo_root/scripts/resolve-packages.sh"

cd "$repo_root"

manifest_path="$packages_root/$manifest_rel"
manifest_parent="$(dirname "$manifest_path")"

parent_real="$(realpath -m "$manifest_parent")"
root_real="$(realpath -m "$packages_root")"

case "$parent_real/" in
    "$root_real"/*)
        ;;
    *)
        echo "Manifest escapes package root: $manifest_path" >&2
        exit 1
        ;;
esac

if [[ ! -x "$resolver" ]]; then
    echo "Missing or non-executable resolver: $resolver" >&2
    exit 1
fi

echo "Validating official package: $package_name"

if ! pacman -Si "$package_name" >/dev/null 2>&1; then
    echo \
        "Package not found in enabled Pacman repositories: $package_name" \
        >&2
    exit 1
fi

find_package_matches() {
    find \
        "$packages_root/common" \
        "$packages_root/features" \
        "$packages_root/hardware" \
        -type f \
        -name '*.txt' \
        -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
        if grep -qxF "$package_name" "$file"; then
            printf '%s\n' "$file"
        fi
    done
}

existing_matches="$(find_package_matches)"

if [[ -n "$existing_matches" ]] &&
   ! grep -qxF "$manifest_path" <<< "$existing_matches"; then

    echo "Package is already recorded in another manifest:" >&2
    echo "$existing_matches" >&2
    exit 1
fi

profiles=()

if [[ -n "$profiles_csv" ]]; then
    IFS=',' read -r -a profiles <<< "$profiles_csv"

    for profile in "${profiles[@]}"; do
        if [[ ! "$profile" =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "Invalid profile name: $profile" >&2
            exit 1
        fi

        profile_file="$profiles_root/$profile.txt"

        if [[ ! -f "$profile_file" ]]; then
            echo "Profile does not exist: $profile_file" >&2
            exit 1
        fi
    done
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"

echo
echo "Planned operation:"
echo "  Branch:    ${current_branch:-unknown}"
echo "  Package:   $package_name"
echo "  Manifest:  $manifest_rel"
echo "  Install:   $([[ $install_package -eq 1 ]] && echo yes || echo no)"
echo "  Dry run:   $([[ $dry_run -eq 1 ]] && echo yes || echo no)"

if ((${#profiles[@]} > 0)); then
    echo "  Profiles:  ${profiles[*]}"
else
    echo "  Profiles:  no profile file will be modified"
fi

if (( dry_run == 1 )); then
    exit 0
fi

if (( install_package == 1 )); then
    echo
    echo "Installing from official Pacman repositories: $package_name"

    sudo pacman -S --needed "$package_name"
fi

mkdir -p "$manifest_parent"
touch "$manifest_path"

if ! grep -qxF "$package_name" "$manifest_path"; then
    printf '%s\n' "$package_name" >> "$manifest_path"
fi

sort -u "$manifest_path" -o "$manifest_path"

for profile in "${profiles[@]}"; do
    profile_file="$profiles_root/$profile.txt"

    if ! grep -qxF "$manifest_rel" "$profile_file"; then
        printf '%s\n' "$manifest_rel" >> "$profile_file"
    fi

    sort -u "$profile_file" -o "$profile_file"
done

echo
echo "Updated manifest:"
sed 's/^/  /' "$manifest_path"

referencing_profiles=()

while IFS= read -r profile_file; do
    if grep -qxF "$manifest_rel" "$profile_file"; then
        referencing_profiles+=(
            "$(basename "$profile_file" .txt)"
        )
    fi
done < <(
    find "$profiles_root" \
        -maxdepth 1 \
        -type f \
        -name '*.txt' \
        | sort
)

if ((${#referencing_profiles[@]} == 0)); then
    echo
    echo "[WARN] No profile currently references:"
    echo "  $manifest_rel"
    echo
    echo "Use --profiles profile1,profile2 or update a profile deliberately."
else
    echo
    echo "Profiles using this manifest:"
    printf '  %s\n' "${referencing_profiles[@]}"
fi

for profile in "${referencing_profiles[@]}"; do
    echo
    echo "Resolving profile: $profile"

    if ! "$resolver" "$profile" |
         grep -qxF "$package_name"; then

        echo \
            "Package is not present in resolved profile: $profile" \
            >&2
        exit 1
    fi

    echo "  [OK] $package_name"
done

echo
echo "Checking package/profile manifest sorting:"

sorting_errors=0

while IFS= read -r -d '' file; do
    relative="${file#"$repo_root"/}"

    if sort -c "$file" 2>/dev/null; then
        printf '  [OK] %s\n' "$relative"
    else
        printf '  [ERROR] Not sorted: %s\n' "$relative" >&2
        sorting_errors=$((sorting_errors + 1))
    fi
done < <(
    find "$packages_root" \
        -type f \
        -name '*.txt' \
        -print0
)

if (( sorting_errors > 0 )); then
    exit 1
fi

echo
echo "Git changes:"

git diff -- \
    "$manifest_path" \
    "$profiles_root" || true

cat <<'NEXT'

Package registration completed.

Review before committing:

  git status --short
  git diff --check
  git diff

Validate profiles:

  ./scripts/validate-packages.sh amd-current
  ./scripts/validate-packages.sh omen

Then stage only the intended files and commit them.
NEXT
