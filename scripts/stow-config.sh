#!/usr/bin/env bash
set -euo pipefail

package="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if [[ -z "$package" ]]; then
    echo "Usage: $0 <package>" >&2
    echo "Example: $0 hypr" >&2
    exit 1
fi

if ! command -v stow >/dev/null 2>&1; then
    echo "Error: GNU Stow is not installed." >&2
    exit 1
fi

if [[ ! -d "$stow_root/$package" ]]; then
    echo "Error: Stow package does not exist: '$package'." >&2
    echo "Expected path: $stow_root/$package" >&2
    exit 1
fi

echo "Simulating links for: $package"

stow \
    --simulate \
    --verbose=2 \
    --dir="$stow_root" \
    --target="$target" \
    "$package"

echo
read -r -p "Apply these links [y/N]? " answer

case "$answer" in
    y|Y|yes|YES)
        stow \
            --verbose=2 \
            --restow \
            --dir="$stow_root" \
            --target="$target" \
            "$package"
        ;;
    *)
        echo "Operation cancelled."
        exit 0
        ;;
esac

echo
echo "Stow package linked: $package"
