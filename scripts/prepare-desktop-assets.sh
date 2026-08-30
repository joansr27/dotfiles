#!/usr/bin/env bash
set -uo pipefail

mode="prepare"

case "${1:-}" in
    "")
        ;;
    --check)
        mode="check"
        ;;
    *)
        echo "Usage: $0 [--check]" >&2
        exit 2
        ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets_dir="$repo_root/assets"
cache_dir="$HOME/.cache/dotfiles/assets"

if ! command -v magick >/dev/null 2>&1; then
    echo "[ERROR] ImageMagick is required (missing command: magick)." >&2
    exit 1
fi

resolve_source() {
    local stem="$1"
    local path
    local -a candidates=()

    shopt -s nullglob nocaseglob

    for path in "$assets_dir/$stem".*; do
        [[ -f "$path" ]] || continue

        if magick identify -quiet "${path}[0]" >/dev/null 2>&1; then
            candidates+=("$path")
        fi
    done

    shopt -u nullglob nocaseglob

    if (( ${#candidates[@]} == 0 )); then
        echo "[ERROR] No readable image found for assets/$stem.*" >&2
        return 1
    fi

    if (( ${#candidates[@]} > 1 )); then
        echo "[ERROR] More than one readable image matches assets/$stem.*:" >&2
        printf '        %s\n' "${candidates[@]}" >&2
        echo "        Keep exactly one source file for this asset." >&2
        return 1
    fi

    printf '%s\n' "${candidates[0]}"
}

prepare_asset() {
    local stem="$1"
    local source destination stamp signature old_signature temp temp_stamp

    if ! source="$(resolve_source "$stem")"; then
        return 1
    fi

    if [[ "$mode" == "check" ]]; then
        printf '[OK] %-9s -> %s\n' "$stem" "$source"
        return 0
    fi

    destination="$cache_dir/$stem.png"
    stamp="$cache_dir/$stem.sha256"
    signature="$(sha256sum -- "$source")"
    old_signature=""

    if [[ -f "$stamp" ]]; then
        old_signature="$(<"$stamp")"
    fi

    if [[ -f "$destination" && "$signature" == "$old_signature" ]]; then
        printf '[OK] %-9s cache is current\n' "$stem"
        return 0
    fi

    temp="$(mktemp "$cache_dir/.${stem}.XXXXXX.png")"
    temp_stamp="$(mktemp "$cache_dir/.${stem}.XXXXXX.sha256")"

    if ! magick "${source}[0]" -auto-orient "$temp"; then
        rm -f "$temp" "$temp_stamp"
        echo "[ERROR] Failed to convert $source" >&2
        return 1
    fi

    printf '%s\n' "$signature" > "$temp_stamp"

    mv -f "$temp" "$destination"
    mv -f "$temp_stamp" "$stamp"

    printf '[OK] %-9s -> %s\n' "$stem" "$destination"
}

if [[ "$mode" == "prepare" ]]; then
    mkdir -p "$cache_dir"
fi

status=0

for stem in wallpaper hyprlock profile; do
    if ! prepare_asset "$stem"; then
        status=1
    fi
done

exit "$status"
