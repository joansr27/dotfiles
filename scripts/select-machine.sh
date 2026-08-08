#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hypr_root="$repo_root/configs/hypr/.config/hypr"
profiles_root="$hypr_root/machines"
machine_link="$hypr_root/machine.conf"

if [[ -z "$profile" ]]; then
    echo "Usage: $0 <profile>" >&2
    echo "Available profiles:" >&2

    find "$profiles_root" \
        -maxdepth 1 \
        -type f \
        -name '*.conf' \
        -printf '  %f\n' \
        | sed 's/\.conf$//' \
        | sort >&2

    exit 1
fi

profile_file="$profiles_root/$profile.conf"

if [[ ! -f "$profile_file" ]]; then
    echo "Machine profile does not exist: $profile_file" >&2
    exit 1
fi

if [[ -e "$machine_link" && ! -L "$machine_link" ]]; then
    echo "Error: $machine_link exists and is not a symbolic link." >&2
    exit 1
fi

ln -sfn \
    "machines/$profile.conf" \
    "$machine_link"

echo "Selected profile: $profile"
echo "Link:"
ls -l "$machine_link"
