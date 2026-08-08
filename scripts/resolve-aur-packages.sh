#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aur_root="$repo_root/packages/aur"
profile_file="$aur_root/profiles/$profile.txt"

if [[ -z "$profile" ]]; then
    echo "Usage: $0 <profile>" >&2
    echo "Example: $0 omen" >&2
    exit 1
fi

if [[ ! -f "$profile_file" ]]; then
    echo "AUR profile does not exist: $profile_file" >&2
    exit 1
fi

while IFS= read -r package_file; do
    [[ -z "$package_file" ||
       "$package_file" =~ ^[[:space:]]*# ]] && continue

    full_path="$aur_root/$package_file"

    if [[ ! -f "$full_path" ]]; then
        echo "AUR file not found: $full_path" >&2
        exit 1
    fi

    grep -Ev '^[[:space:]]*(#|$)' "$full_path"
done < "$profile_file" | sort -u
