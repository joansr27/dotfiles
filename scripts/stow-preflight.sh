#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if ! command -v stow >/dev/null 2>&1; then
    echo "Error: GNU Stow is not installed." >&2
    echo "Install it with: sudo pacman -S stow" >&2
    exit 1
fi

if [[ ! -d "$stow_root" ]]; then
    echo "Error: path does not exist: $stow_root" >&2
    exit 1
fi

echo "Repository: $repo_root"
echo "Stow directory: $stow_root"
echo "Target: $target"
echo

status=0

for package_dir in "$stow_root"/*; do
    [[ -d "$package_dir" ]] || continue

    package="$(basename "$package_dir")"

    echo "=== $package ==="

    if stow \
        --simulate \
        --verbose=2 \
        --dir="$stow_root" \
        --target="$target" \
        "$package"; then
        echo "Simulation successful: $package"
    else
        echo "Conflict detected: $package" >&2
        status=1
    fi

    echo
done

exit "$status"
