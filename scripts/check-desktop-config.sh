#!/usr/bin/env bash
set -uo pipefail

errors=0

check_path() {
    local path="$1"

    if [[ -e "$path" ]]; then
        printf '[OK] %s\n' "$path"
    else
        printf '[ERROR] No existe: %s\n' "$path" >&2
        errors=$((errors + 1))
    fi
}

check_command() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        printf '[OK] Comando: %s\n' "$command_name"
    else
        printf '[WARN] Comando no encontrado: %s\n' "$command_name"
    fi
}

check_path "$HOME/.config/hypr/hyprland.conf"
check_path "$HOME/.config/hypr/hyprpaper.conf"
check_path "$HOME/.config/waybar/config.jsonc"
check_path "$HOME/.config/waybar/style.css"
check_path "$HOME/.config/kitty/kitty.conf"
check_path "$HOME/.config/nvim/init.lua"
check_path "$HOME/.config/wofi/config"
check_path "$HOME/.config/wofi/style.css"
check_path "$HOME/.config/user-dirs.conf"
check_path "$HOME/.config/user-dirs.dirs"

check_command hyprctl
check_command waybar
check_command kitty
check_command nvim
check_command wofi
check_command xdg-user-dir
check_command stow
check_command wlsunset
check_command swappy

if command -v hyprctl >/dev/null 2>&1 &&
   [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo
    echo "Errores de configuración de Hyprland:"
    hyprctl configerrors || errors=$((errors + 1))
fi

exit "$errors"
