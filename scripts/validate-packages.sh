#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_root="$repo_root/packages"
resolver="$repo_root/scripts/resolve-packages.sh"

usage() {
    cat <<USAGE
Usage:

    $0 <profile>

Example:

    $0 omen
USAGE
}

if [[ -z "$profile" ]]; then
    usage >&2
    exit 1
fi

if [[ ! -x "$resolver" ]]; then
    echo "Missing or non-executable resolver: $resolver" >&2
    exit 1
fi

profile_file="$packages_root/profiles/$profile.txt"

if [[ ! -f "$profile_file" ]]; then
    echo "Profile does not exist: $profile_file" >&2
    exit 1
fi

errors=0

echo "=== Manifest sorting ==="

while IFS= read -r -d '' file; do
    relative="${file#"$repo_root"/}"

    if sort -c "$file" 2>/dev/null; then
        printf '[OK] %s\n' "$relative"
    else
        printf '[ERROR] Not sorted: %s\n' "$relative" >&2
        errors=$((errors + 1))
    fi
done < <(
    find "$packages_root" \
        -type f \
        -name '*.txt' \
        -print0
)

echo
echo "=== Resolving profile: $profile ==="

packages_text="$("$resolver" "$profile")"

if [[ -z "$packages_text" ]]; then
    echo "[ERROR] Profile resolved to an empty package list." >&2
    errors=$((errors + 1))
    packages=()
else
    mapfile -t packages < <(
        printf '%s\n' "$packages_text"
    )
fi

echo
echo "=== Official package availability ==="

for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue

    if pacman -Si "$package" >/dev/null 2>&1; then
        printf '[OK] %s\n' "$package"
    else
        printf \
            '[ERROR] Not found in enabled Pacman repositories: %s\n' \
            "$package" >&2
        errors=$((errors + 1))
    fi
done

echo
echo "=== Foreign installed packages ==="

mapfile -t foreign_packages < <(
    pacman -Qqm 2>/dev/null || true
)

if (( ${#foreign_packages[@]} == 0 )); then
    echo "[OK] No foreign packages installed."
else
    for package in "${foreign_packages[@]}"; do
        printf '[ERROR] Foreign package installed: %s\n' \
            "$package" >&2
        errors=$((errors + 1))
    done
fi

echo
echo "=== Validation result ==="

if (( errors == 0 )); then
    echo "[OK] Package validation passed."
else
    printf '[ERROR] Validation failed with %d error(s).\n' \
        "$errors" >&2
fi

exit "$errors"
