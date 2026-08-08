#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
official_resolver="$repo_root/scripts/resolve-packages.sh"
aur_resolver="$repo_root/scripts/resolve-aur-packages.sh"

if [[ -z "$profile" ]]; then
    echo "Usage: $0 <profile>" >&2
    echo "Example: $0 omen" >&2
    exit 1
fi

official_tmp="$(mktemp)"
aur_tmp="$(mktemp)"

cleanup() {
    rm -f "$official_tmp" "$aur_tmp"
}

trap cleanup EXIT

"$official_resolver" "$profile" > "$official_tmp"
"$aur_resolver" "$profile" > "$aur_tmp"

errors=0

echo "=== Official packages ==="

while IFS= read -r package; do
    [[ -n "$package" ]] || continue

    if pacman -Si "$package" >/dev/null 2>&1; then
        printf '[OK] %s\n' "$package"
    else
        printf '[ERROR] Not found in Pacman: %s\n' "$package" >&2
        errors=$((errors + 1))
    fi
done < "$official_tmp"

echo
echo "=== AUR packages ==="

if command -v yay >/dev/null 2>&1; then
    while IFS= read -r package; do
        [[ -n "$package" ]] || continue

        if yay -Si "$package" >/dev/null 2>&1; then
            printf '[OK] %s\n' "$package"
        else
            printf '[ERROR] Not found in AUR: %s\n' "$package" >&2
            errors=$((errors + 1))
        fi
    done < "$aur_tmp"
else
    echo "[WARN] yay is not installed; AUR packages cannot be validated."
fi

echo
echo "=== Duplicates between Pacman and AUR ==="

duplicates="$(
    comm -12 \
        <(sort -u "$official_tmp") \
        <(sort -u "$aur_tmp")
)"

if [[ -n "$duplicates" ]]; then
    echo "$duplicates" >&2
    errors=$((errors + 1))
else
    echo "[OK] No duplicates found."
fi

exit "$errors"
