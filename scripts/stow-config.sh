#!/usr/bin/env bash
set -euo pipefail

package="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stow_root="$repo_root/configs"
target="$HOME"

if [[ -z "$package" ]]; then
    echo "Uso: $0 <paquete>" >&2
    echo "Ejemplo: $0 hypr" >&2
    exit 1
fi

if ! command -v stow >/dev/null 2>&1; then
    echo "Error: GNU Stow no está instalado." >&2
    exit 1
fi

if [[ ! -d "$stow_root/$package" ]]; then
    echo "Error: no existe el paquete Stow '$package'." >&2
    echo "Ruta esperada: $stow_root/$package" >&2
    exit 1
fi

echo "Simulando enlaces para: $package"

stow \
    --simulate \
    --verbose=2 \
    --dir="$stow_root" \
    --target="$target" \
    "$package"

echo
read -r -p "Aplicar estos enlaces [y/N]? " answer

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
        echo "Operación cancelada."
        exit 0
        ;;
esac

echo
echo "Paquete enlazado: $package"
