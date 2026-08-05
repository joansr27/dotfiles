#!/usr/bin/env bash
set -euo pipefail

name="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/$name"
package_root="$repo_root/configs/$name"
destination_dir="$package_root/.config/$name"
target_dir="$HOME/.config/$name"

if [[ -z "$name" ]]; then
    echo "Uso: $0 <nombre>" >&2
    echo "Ejemplo: $0 dunst" >&2
    exit 1
fi

if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Nombre no válido: $name" >&2
    exit 1
fi

if [[ ! -d "$source_dir" ]]; then
    echo "No existe el origen: $source_dir" >&2
    exit 1
fi

if [[ -e "$package_root" ]]; then
    echo "Ya existe el paquete Stow: $package_root" >&2
    exit 1
fi

backup_root="${DOTFILES_BACKUP_ROOT:-$HOME/dotfiles-backup/manual-stow-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$backup_root"

if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    cp -aL "$target_dir" "$backup_root/$name-before-stow"

    if [[ -L "$target_dir" ]]; then
        rm -- "$target_dir"
    else
        mv "$target_dir" "$backup_root/$name-target-before-stow"
    fi
fi

mkdir -p "$package_root/.config"

git -C "$repo_root" mv \
    "$source_dir" \
    "$destination_dir"

stow \
    --simulate \
    --verbose=2 \
    --dir="$repo_root/configs" \
    --target="$HOME" \
    "$name"

read -r -p "Aplicar Stow para '$name' [y/N]? " answer

case "$answer" in
    y|Y|yes|YES)
        stow \
            --restow \
            --verbose=2 \
            --dir="$repo_root/configs" \
            --target="$HOME" \
            "$name"
        ;;
    *)
        echo "No se ha aplicado Stow."
        exit 1
        ;;
esac

echo "Migración completada: $name"
echo "Destino real: $destination_dir"
