#!/usr/bin/env bash
set -euo pipefail

package="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if [[ -z "$package" ]]; then
    echo "Uso: $0 <paquete>" >&2
    echo "Ejemplo: $0 waybar" >&2
    exit 1
fi

if [[ ! -d "$stow_root/$package" ]]; then
    echo "Error: no existe el paquete Stow '$package'." >&2
    exit 1
fi

stow \
    --delete \
    --verbose=2 \
    --dir="$stow_root" \
    --target="$target" \
    "$package"

echo "Enlaces eliminados para: $package"
