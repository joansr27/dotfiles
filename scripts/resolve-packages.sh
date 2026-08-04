#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_root="$repo_root/packages"

if [[ -z "$profile" ]]; then
    echo "Uso: $0 <perfil>"
    echo "Ejemplo: $0 amd-current"
    exit 1
fi

profile_file="$packages_root/profiles/$profile.txt"

if [[ ! -f "$profile_file" ]]; then
    echo "Perfil inexistente: $profile_file" >&2
    exit 1
fi

while IFS= read -r package_file; do
    [[ -z "$package_file" || "$package_file" =~ ^[[:space:]]*# ]] && continue

    full_path="$packages_root/$package_file"

    if [[ ! -f "$full_path" ]]; then
        echo "Archivo no encontrado: $full_path" >&2
        exit 1
    fi

    grep -Ev '^[[:space:]]*(#|$)' "$full_path"
done < "$profile_file" | sort -u
