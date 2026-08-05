#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if ! command -v stow >/dev/null 2>&1; then
    echo "Error: GNU Stow no está instalado." >&2
    echo "Instálalo con: sudo pacman -S stow" >&2
    exit 1
fi

if [[ ! -d "$stow_root" ]]; then
    echo "Error: no existe $stow_root" >&2
    exit 1
fi

echo "Repositorio: $repo_root"
echo "Directorio Stow: $stow_root"
echo "Destino: $target"
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
        echo "Simulación correcta: $package"
    else
        echo "Conflicto detectado: $package" >&2
        status=1
    fi

    echo
done

exit "$status"
