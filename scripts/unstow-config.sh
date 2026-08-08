#!/usr/bin/env bash
set -euo pipefail

package="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if [[ -z "$package" ]]; then
    echo "Usage: $0 <package>" >&2
    echo "Example: $0 waybar" >&2
    exit 1
fi

if [[ ! -d "$stow_root/$package" ]]; then
    echo "Error: Stow package does not exist: '$package'." >&2
    exit 1
fi

stow \
    --delete \
    --verbose=2 \
    --dir="$stow_root" \
    --target="$target" \
    "$package"

echo "Links removed for: $package"
