#!/usr/bin/env bash
set -u

command -v powerprofilesctl >/dev/null 2>&1 || exit 0

current="$(powerprofilesctl get 2>/dev/null || true)"
[[ -n "$current" ]] || exit 0

mapfile -t available < <(
    powerprofilesctl list 2>/dev/null |
        sed -nE \
            's/^[[:space:]*]*(power-saver|balanced|performance):.*/\1/p'
)

((${#available[@]} > 0)) || exit 0

is_available() {
    local wanted="$1"
    local item

    for item in "${available[@]}"; do
        [[ "$item" == "$wanted" ]] && return 0
    done

    return 1
}

preferred=(
    balanced
    performance
    power-saver
)

cycle=()

for profile in "${preferred[@]}"; do
    is_available "$profile" &&
        cycle+=("$profile")
done

((${#cycle[@]} > 0)) || exit 0

next="${cycle[0]}"

for i in "${!cycle[@]}"; do
    if [[ "${cycle[$i]}" == "$current" ]]; then
        next="${cycle[$(( (i + 1) % ${#cycle[@]} ))]}"
        break
    fi
done

if [[ "$next" != "$current" ]] &&
   powerprofilesctl set "$next"; then

    pkill -RTMIN+14 waybar \
        2>/dev/null ||
        true
fi
