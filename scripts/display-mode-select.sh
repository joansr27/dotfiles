#!/usr/bin/env bash
set -u

MODE="${1:-select}"

if ! command -v hyprctl >/dev/null 2>&1 ||
   ! command -v jq >/dev/null 2>&1; then

    if [[ "$MODE" == "--status" ]]; then
        printf '{"text":"","tooltip":"hyprctl/jq unavailable"}\n'
    fi

    exit 0
fi

# ============================================================
# Waybar status
# ============================================================

status() {
    local json focused hz text tooltip

    json="$(hyprctl -j monitors 2>/dev/null || true)"

    if [[ -z "$json" ]]; then
        printf '{"text":"","tooltip":"No monitor data"}\n'
        return
    fi

    focused="$(
        jq -c \
            '([.[] | select(.focused == true)] | first) // (.[0] // empty)' \
            <<< "$json"
    )"

    if [[ -z "$focused" ]]; then
        printf '{"text":"","tooltip":"No active monitors"}\n'
        return
    fi

    hz="$(jq -r '.refreshRate | round' <<< "$focused")"

    text="${hz} Hz"

    tooltip="$(
        jq -r '
            [
                .[] |
                "\(.name): \(.width)x\(.height) @ \(.refreshRate | round) Hz"
            ]
            | join("\n")
        ' <<< "$json"
    )"

    jq -cn \
        --arg text "$text" \
        --arg tooltip "$tooltip" \
        '{
            text: $text,
            tooltip: $tooltip,
            class: "display-mode"
        }'
}

# ============================================================
# Wofi selector
# ============================================================

select_mode() {
    local json record
    local name mode x y scale transform mirror vrr
    local width height refresh current_mode
    local label choice rule

    local -a records
    local -a labels

    command -v wofi >/dev/null 2>&1 || exit 0

    json="$(hyprctl -j monitors 2>/dev/null || true)"
    [[ -n "$json" ]] || exit 0

    mapfile -t records < <(
        jq -r '
            .[]
            | select(.disabled == false)
            | . as $m
            | $m.availableModes[]?
            | [
                $m.name,
                .,
                ($m.x | tostring),
                ($m.y | tostring),
                ($m.scale | tostring),
                ($m.transform | tostring),
                ($m.mirrorOf // "none"),
                ($m.vrr | tostring),
                ($m.width | tostring),
                ($m.height | tostring),
                ($m.refreshRate | tostring)
            ]
            | @tsv
        ' <<< "$json"
    )

    ((${#records[@]} > 0)) || exit 0

    labels=()

    for record in "${records[@]}"; do

        IFS=$'\t' read -r \
            name \
            mode \
            x \
            y \
            scale \
            transform \
            mirror \
            vrr \
            width \
            height \
            refresh <<< "$record"

        current_mode="$(
            printf '%sx%s@%.2fHz' \
                "$width" \
                "$height" \
                "$refresh"
        )"

        label="${name}  ·  ${mode}"

        if [[ "$mode" == "$current_mode" ]]; then
            label+="  [current]"
        fi

        labels+=("$label")
    done

    lines="${#labels[@]}"
    (( lines > 12 )) && lines=12

    choice="$(
        printf '%s\n' "${labels[@]}" |
            wofi \
                --dmenu \
                --prompt "Refresh rate" \
                --lines "$lines" \
                2>/dev/null ||
            true
    )"

    [[ -n "$choice" ]] || exit 0

    selected=-1

    for i in "${!labels[@]}"; do
        if [[ "${labels[$i]}" == "$choice" ]]; then
            selected="$i"
            break
        fi
    done

    (( selected >= 0 )) || exit 0

    record="${records[$selected]}"

    IFS=$'\t' read -r \
        name \
        mode \
        x \
        y \
        scale \
        transform \
        mirror \
        vrr \
        width \
        height \
        refresh <<< "$record"

    # availableModes contains "...Hz"; monitor rules use RES@RATE.
    mode="${mode%Hz}"

    rule="${name},${mode},${x}x${y},${scale}"

    if [[ "$transform" =~ ^[0-7]$ &&
          "$transform" != "0" ]]; then

        rule+=",transform,${transform}"
    fi

    if [[ -n "$mirror" &&
          "$mirror" != "none" ]]; then

        rule+=",mirror,${mirror}"
    fi

    case "$vrr" in
        true)
            rule+=",vrr,1"
            ;;
        1|2|3)
            rule+=",vrr,${vrr}"
            ;;
    esac

    hyprctl keyword monitor "$rule" \
        >/dev/null 2>&1 ||
        exit 1

    # Immediately refresh Waybar's display module.
    pkill -RTMIN+13 waybar 2>/dev/null || true
}

case "$MODE" in
    --status)
        status
        ;;
    *)
        select_mode
        ;;
esac
