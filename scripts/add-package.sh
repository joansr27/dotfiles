#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:

  add-package.sh \
      --source <official|aur> \
      --package <package-name> \
      --manifest <relative-manifest-path> \
      [--profiles <profile1,profile2>] \
      [--no-install] \
      [--dry-run]

Examples:

  # Official package in an existing common manifest
  ./scripts/add-package.sh \
      --source official \
      --package firefox \
      --manifest common/07-applications.txt

  # Official package in a new feature used by both machines
  ./scripts/add-package.sh \
      --source official \
      --package example \
      --manifest features/example.txt \
      --profiles amd-current,omen

  # AUR package in the common AUR manifest
  ./scripts/add-package.sh \
      --source aur \
      --package example-bin \
      --manifest common.txt

  # Validate and record without installing on this machine
  ./scripts/add-package.sh \
      --no-install \
      --source official \
      --package example \
      --manifest hardware/omen-intel-nvidia.txt

Manifest paths are relative to:

  official: packages/
  aur:      packages/aur/

This script never stages, commits, or pushes changes.
USAGE
}

source_type=""
package_name=""
manifest_rel=""
profiles_csv=""
install_package=1
dry_run=0

while (($# > 0)); do
    case "$1" in
        --source)
            [[ $# -ge 2 ]] || { echo "Missing value for --source" >&2; exit 1; }
            source_type="$2"
            shift 2
            ;;
        --package)
            [[ $# -ge 2 ]] || { echo "Missing value for --package" >&2; exit 1; }
            package_name="$2"
            shift 2
            ;;
        --manifest)
            [[ $# -ge 2 ]] || { echo "Missing value for --manifest" >&2; exit 1; }
            manifest_rel="$2"
            shift 2
            ;;
        --profiles)
            [[ $# -ge 2 ]] || { echo "Missing value for --profiles" >&2; exit 1; }
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

if [[ -z "$source_type" || -z "$package_name" || -z "$manifest_rel" ]]; then
    usage >&2
    exit 1
fi

case "$source_type" in
    official|aur)
        ;;
    *)
        echo "Invalid source: $source_type" >&2
        echo "Expected: official or aur" >&2
        exit 1
        ;;
esac

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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

current_branch="$(git branch --show-current 2>/dev/null || true)"

if [[ "$current_branch" == "main" ]]; then
    echo "[WARN] You are on main."
    echo "Create a package branch before recording the change:"
    echo
    echo "  git switch -c packages/add-$package_name"
    echo
fi

official_root="$repo_root/packages"
aur_root="$repo_root/packages/aur"

if [[ "$source_type" == "official" ]]; then
    manifest_root="$official_root"
    profiles_root="$official_root/profiles"
    resolver="$repo_root/scripts/resolve-packages.sh"
else
    manifest_root="$aur_root"
    profiles_root="$aur_root/profiles"
    resolver="$repo_root/scripts/resolve-aur-packages.sh"
fi

manifest_path="$manifest_root/$manifest_rel"
manifest_parent="$(dirname "$manifest_path")"
parent_real="$(realpath -m "$manifest_parent")"
root_real="$(realpath -m "$manifest_root")"

case "$parent_real/" in
    "$root_real"/*)
        ;;
    *)
        echo "Manifest escapes its allowed root: $manifest_path" >&2
        exit 1
        ;;
esac

find_aur_matches() {
    [[ -d "$aur_root" ]] || return 0

    find "$aur_root" \
        -type f \
        -name '*.txt' \
        ! -path '*/profiles/*' \
        -print0 |
    while IFS= read -r -d '' file; do
        grep -qxF "$package_name" "$file" && printf '%s\n' "$file"
    done
}

find_official_matches() {
    find \
        "$official_root/common" \
        "$official_root/features" \
        "$official_root/hardware" \
        -type f \
        -name '*.txt' \
        -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
        grep -qxF "$package_name" "$file" && printf '%s\n' "$file"
    done
}

official_matches="$(find_official_matches)"
aur_matches="$(find_aur_matches)"

if [[ "$source_type" == "official" && -n "$aur_matches" ]]; then
    echo "Package is already recorded as AUR:" >&2
    echo "$aur_matches" >&2
    exit 1
fi

if [[ "$source_type" == "aur" && -n "$official_matches" ]]; then
    echo "Package is already recorded as official:" >&2
    echo "$official_matches" >&2
    exit 1
fi

if [[ "$source_type" == "official" && -n "$official_matches" ]]; then
    if ! grep -qxF "$manifest_path" <<< "$official_matches"; then
        echo "Package is already recorded in another official manifest:" >&2
        echo "$official_matches" >&2
        exit 1
    fi
fi

if [[ "$source_type" == "aur" && -n "$aur_matches" ]]; then
    if ! grep -qxF "$manifest_path" <<< "$aur_matches"; then
        echo "Package is already recorded in another AUR manifest:" >&2
        echo "$aur_matches" >&2
        exit 1
    fi
fi

if [[ "$source_type" == "official" ]]; then
    echo "Validating official package: $package_name"

    if ! pacman -Si "$package_name" >/dev/null 2>&1; then
        echo "Package not found in enabled Pacman repositories: $package_name" >&2
        exit 1
    fi
else
    if ! command -v yay >/dev/null 2>&1; then
        echo "yay is required to validate AUR packages." >&2
        exit 1
    fi

    echo "Validating AUR package: $package_name"

    if ! yay -Si "$package_name" >/dev/null 2>&1; then
        echo "Package not found by yay: $package_name" >&2
        exit 1
    fi
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

echo
echo "Planned operation:"
echo "  Source:    $source_type"
echo "  Package:   $package_name"
echo "  Manifest:  ${manifest_path#"$repo_root"/}"
echo "  Install:   $([[ $install_package -eq 1 ]] && echo yes || echo no)"
echo "  Dry run:   $([[ $dry_run -eq 1 ]] && echo yes || echo no)"

if ((${#profiles[@]} > 0)); then
    echo "  Profiles:  ${profiles[*]}"
else
    echo "  Profiles:  no profile file will be modified"
fi

if ((dry_run == 1)); then
    exit 0
fi

if ((install_package == 1)); then
    echo
    echo "Installing: $package_name"

    if [[ "$source_type" == "official" ]]; then
        sudo pacman -S --needed "$package_name"
    else
        echo
        echo "Review the PKGBUILD and changes shown by yay before accepting."
        yay -S --needed "$package_name"
    fi
fi

mkdir -p "$(dirname "$manifest_path")"
touch "$manifest_path"

if ! grep -qxF "$package_name" "$manifest_path"; then
    printf '%s\n' "$package_name" >> "$manifest_path"
fi

sort -u -o "$manifest_path" "$manifest_path"

for profile in "${profiles[@]}"; do
    profile_file="$profiles_root/$profile.txt"

    if ! grep -qxF "$manifest_rel" "$profile_file"; then
        printf '%s\n' "$manifest_rel" >> "$profile_file"
    fi

    sort -u -o "$profile_file" "$profile_file"
done

echo
echo "Updated manifest:"
sed 's/^/  /' "$manifest_path"

referencing_profiles=()

while IFS= read -r profile_file; do
    if grep -qxF "$manifest_rel" "$profile_file"; then
        referencing_profiles+=("$(basename "$profile_file" .txt)")
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
    echo "Use --profiles profile1,profile2 or update the profile manually."
else
    echo
    echo "Profiles using this manifest:"
    printf '  %s\n' "${referencing_profiles[@]}"
fi

if [[ -x "$resolver" ]]; then
    for profile in "${referencing_profiles[@]}"; do
        echo
        echo "Resolving profile: $profile"

        if ! "$resolver" "$profile" | grep -qxF "$package_name"; then
            echo "Package is not present in resolved profile: $profile" >&2
            exit 1
        fi

        echo "  [OK] $package_name"
    done
fi

echo
echo "Git changes:"
git diff -- \
    "$manifest_path" \
    "$profiles_root" || true

cat <<NEXT

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
