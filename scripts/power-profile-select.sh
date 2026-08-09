#!/usr/bin/env bash
set -u

MODE="${1:-select}"

# ============================================================
# Waybar status
# ============================================================

status() {

    if ! command -v powerprofilesctl >/dev/null 2>&1 ||
       ! command -v jq >/dev/null 2>&1; then

        printf '{"text":"","tooltip":"Power Profiles Daemon unavailable","class":"unavailable"}\n'
        return 0
    fi

    local current
    local icon
    local label
    local platform
    local epp
    local tooltip

    current="$(
        powerprofilesctl get 2>/dev/null ||
            true
    )"

    if [[ -z "$current" ]]; then
        jq -cn \
            '{
                text: "",
                tooltip: "Power Profiles Daemon unavailable",
                class: "unavailable"
            }'

        return 0
    fi

    case "$current" in

        performance)
            icon=""
            label="Performance"
            ;;

        balanced)
            icon=""
            label="Balanced"
            ;;

        power-saver)
            icon=""
            label="Power saver"
            ;;

        *)
            icon=""
            label="$current"
            ;;
    esac

    platform=""

    if [[ -r /sys/firmware/acpi/platform_profile ]]; then
        platform="$(
            cat /sys/firmware/acpi/platform_profile \
                2>/dev/null
        )"
    fi

    epp=""

    if [[ -r /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference ]]; then

        epp="$(
            cat \
                /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference \
                2>/dev/null
        )"
    fi

    tooltip="Power profile: ${label}"

    if [[ -n "$platform" ]]; then
        tooltip+=$'\n'"Platform profile: ${platform}"
    fi

    if [[ -n "$epp" ]]; then
        tooltip+=$'\n'"CPU EPP: ${epp}"
    fi

    tooltip+=$'\n\n'"Left click: cycle profile"
    tooltip+=$'\n'"Right click: choose profile"

    jq -cn \
        --arg text "$icon" \
        --arg tooltip "$tooltip" \
        --arg class "$current" \
        '{
            text: $text,
            tooltip: $tooltip,
            class: $class
        }'
}

# ============================================================
# Wofi selector
# ============================================================

select_profile() {

    command -v powerprofilesctl >/dev/null 2>&1 ||
        exit 0

    command -v wofi >/dev/null 2>&1 ||
        exit 0

    local current
    local profile
    local label
    local choice

    local -a available
    local -a labels
    local -a profiles

    current="$(
        powerprofilesctl get 2>/dev/null ||
            true
    )"

    [[ -n "$current" ]] || exit 0

    mapfile -t available < <(
        powerprofilesctl list 2>/dev/null |
            sed -nE \
                's/^[[:space:]*]*(power-saver|balanced|performance):.*/\1/p'
    )

    ((${#available[@]} > 0)) || exit 0

    labels=()
    profiles=()

    # Menu order:
    #
    # Performance
    # Balanced
    # Power saver
    #
    # Only actually available profiles are displayed.

    for wanted in \
        performance \
        balanced \
        power-saver
    do

        for profile in "${available[@]}"; do

            [[ "$profile" == "$wanted" ]] ||
                continue

            case "$profile" in
                performance)
                    label="Performance"
                    ;;
                balanced)
                    label="Balanced"
                    ;;
                power-saver)
                    label="Power saver"
                    ;;
                *)
                    label="$profile"
                    ;;
            esac

            if [[ "$profile" == "$current" ]]; then
                label+="  [current]"
            fi

            labels+=("$label")
            profiles+=("$profile")
        done
    done

    choice="$(
        printf '%s\n' "${labels[@]}" |
            wofi \
                --dmenu \
                --prompt "Power profile" \
                --lines "${#labels[@]}" \
                2>/dev/null ||
            true
    )"

    [[ -n "$choice" ]] || exit 0

    for i in "${!labels[@]}"; do

        if [[ "${labels[$i]}" == "$choice" ]]; then

            if [[ "${profiles[$i]}" != "$current" ]] &&
               powerprofilesctl set "${profiles[$i]}"; then

                pkill -RTMIN+14 waybar \
                    2>/dev/null ||
                    true
            fi

            exit 0
        fi
    done
}

case "$MODE" in
    --status)
        status
        ;;
    *)
        select_profile
        ;;
esac
