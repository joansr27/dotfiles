#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

official_resolver="$repo_root/scripts/resolve-packages.sh"
machine_selector="$repo_root/scripts/select-machine.sh"
stow_preflight="$repo_root/scripts/stow-preflight.sh"

usage() {
    cat <<USAGE
Usage:

    $0 <profile>

Available profiles:

    amd-current
    omen

Example:

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
        echo "Unrecognized profile: $profile" >&2
        usage
        exit 1
        ;;
esac

if (( EUID == 0 )); then
    echo "Do not run this script as root." >&2
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    echo "This installer is designed for Arch Linux." >&2
    exit 1
fi

for script in \
    "$official_resolver" \
    "$machine_selector" \
    "$stow_preflight"
do
    if [[ ! -x "$script" ]]; then
        echo "Missing or non-executable script: $script" >&2
        exit 1
    fi
done

official_packages_text="$("$official_resolver" "$profile")"

if [[ -z "$official_packages_text" ]]; then
    echo "Official package profile resolved to an empty list." >&2
    exit 1
fi

mapfile -t official_packages < <(
    printf '%s\n' "$official_packages_text"
)

if printf '%s\n' "${official_packages[@]}" |
   grep -q '^lib32-'; then

    if ! pacman-conf --repo-list |
       grep -qx 'multilib'; then
        cat >&2 <<'ERROR'
The profile contains lib32 packages, but [multilib] is not enabled.

Edit /etc/pacman.conf and uncomment:

    [multilib]
    Include = /etc/pacman.d/mirrorlist

Then run:

    sudo pacman -Syu

and run the installer again.
ERROR
        exit 1
    fi
fi

echo "=== Updating system ==="

sudo pacman -Syu --needed base-devel git

echo
echo "=== Installing official packages ==="

sudo pacman -S --needed "${official_packages[@]}"

echo
echo "=== Selecting machine profile ==="

"$machine_selector" "$profile"

echo
echo "=== Installing machine-specific system configuration ==="

if [[ "$profile" == "omen" ]]; then
    lid_policy="$repo_root/system/omen/etc/systemd/logind.conf.d/60-lid-lock.conf"

    if [[ ! -f "$lid_policy" ]]; then
        echo "Missing OMEN lid policy: $lid_policy" >&2
        exit 1
    fi

    sudo install \
        -Dm644 \
        "$lid_policy" \
        /etc/systemd/logind.conf.d/60-lid-lock.conf
fi

echo
echo "=== Creating user directories ==="

mkdir -p \
    "$HOME/Desktop" \
    "$HOME/Downloads"

echo
echo "=== Checking for Stow conflicts ==="

"$stow_preflight"

echo
echo "=== Deploying configurations ==="

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
echo "=== Default PDF reader ==="

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

Base installation completed.

The installer does NOT enable services automatically.

Review the system, then enable the required core services:

    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
    sudo systemctl enable --now firewalld
    sudo systemctl enable --now cronie
    sudo systemctl enable --now power-profiles-daemon
    sudo systemctl enable sddm

Remote desktop is not configured by this repository.

External KVM hardware such as PiKVM is the preferred future approach.
Tailscale and WayVNC are installed only as optional packages and remain
unconfigured.

First confirm that SDDM, Hyprland, graphics, audio, networking, and local input
work correctly.

Remote access is a separate future project. See the remote-access policy in
README.md for the current repository scope.

Validation:

    ./scripts/check-desktop-config.sh
    ./scripts/stow-preflight.sh
    ./scripts/validate-packages.sh <profile>

NEXT
