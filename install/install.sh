#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

official_resolver="$repo_root/scripts/resolve-packages.sh"
aur_resolver="$repo_root/scripts/resolve-aur-packages.sh"
machine_selector="$repo_root/scripts/select-machine.sh"
stow_preflight="$repo_root/scripts/stow-preflight.sh"

usage() {
    cat <<USAGE
Uso:

    $0 <perfil>

Perfiles disponibles:

    amd-current
    omen

Ejemplo:

    $0 omen
USAGE
}

if [[ -z "$profile" ]]; then
    usage
    exit 1
fi

case "$profile" in
    amd-current|omen)
        ;;
    *)
        echo "Perfil no reconocido: $profile" >&2
        usage
        exit 1
        ;;
esac

if (( EUID == 0 )); then
    echo "No ejecutes este script como root." >&2
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    echo "Este instalador está diseñado para Arch Linux." >&2
    exit 1
fi

for script in \
    "$official_resolver" \
    "$aur_resolver" \
    "$machine_selector" \
    "$stow_preflight"
do
    if [[ ! -x "$script" ]]; then
        echo "Script ausente o no ejecutable: $script" >&2
        exit 1
    fi
done

mapfile -t official_packages < <(
    "$official_resolver" "$profile"
)

if printf '%s\n' "${official_packages[@]}" |
   grep -q '^lib32-'; then

    if ! pacman-conf --repo-list |
       grep -qx 'multilib'; then
        cat >&2 <<'ERROR'
El perfil contiene paquetes lib32, pero [multilib] no está habilitado.

Edita /etc/pacman.conf y descomenta:

    [multilib]
    Include = /etc/pacman.d/mirrorlist

Después ejecuta:

    sudo pacman -Syu

y vuelve a lanzar el instalador.
ERROR
        exit 1
    fi
fi

echo "=== Actualizando el sistema ==="

sudo pacman -Syu --needed base-devel git

echo
echo "=== Instalando paquetes oficiales ==="

sudo pacman -S --needed "${official_packages[@]}"

if ! command -v yay >/dev/null 2>&1; then
    echo
    echo "=== Instalando yay ==="

    build_root="$(mktemp -d)"

    cleanup_yay() {
        rm -rf "$build_root"
    }

    trap cleanup_yay EXIT

    git clone \
        https://aur.archlinux.org/yay.git \
        "$build_root/yay"

    (
        cd "$build_root/yay"
        makepkg -si --needed
    )

    cleanup_yay
    trap - EXIT
fi

mapfile -t aur_packages < <(
    "$aur_resolver" "$profile"
)

if (( ${#aur_packages[@]} > 0 )); then
    echo
    echo "=== Instalando paquetes AUR ==="

    yay -S --needed "${aur_packages[@]}"
fi

echo
echo "=== Seleccionando la máquina ==="

"$machine_selector" "$profile"

echo
echo "=== Creando directorios personales ==="

mkdir -p \
    "$HOME/Desktop" \
    "$HOME/Downloads"

echo
echo "=== Comprobando conflictos de Stow ==="

"$stow_preflight"

echo
echo "=== Desplegando configuraciones ==="

for package_dir in "$repo_root/configs"/*; do
    [[ -d "$package_dir" ]] || continue

    package_name="$(basename "$package_dir")"

    stow \
        --restow \
        --verbose=1 \
        --dir="$repo_root/configs" \
        --target="$HOME" \
        "$package_name"
done

echo
echo "=== Lector PDF predeterminado ==="

xdg-mime default \
    org.kde.okular.desktop \
    application/pdf


echo
echo "=== Default web browser ==="

xdg-settings set default-web-browser firefox.desktop

for mime in \
    text/html \
    application/xhtml+xml \
    x-scheme-handler/http \
    x-scheme-handler/https
do
    xdg-mime default firefox.desktop "$mime"
done

cat <<'NEXT'

Instalación base completada.

El instalador NO habilita servicios automáticamente.

Revisa y habilita manualmente lo necesario:

    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
    sudo systemctl enable --now sddm
    sudo systemctl enable --now firewalld

Para Tailscale:

    sudo systemctl enable --now tailscaled
    sudo tailscale up

Sunshine debe configurarse y probarse antes de habilitarlo:

    systemctl --user start app-dev.lizardbyte.app.Sunshine

Validación:

    ./scripts/check-desktop-config.sh
    ./scripts/stow-preflight.sh
    ./scripts/validate-packages.sh <perfil>

NEXT
