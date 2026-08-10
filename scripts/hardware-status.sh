#!/usr/bin/env bash
set -u

# Waybar hardware telemetry.
# Outputs one JSON object.

if ! command -v jq >/dev/null 2>&1; then
    printf '{"text":"HW ?","tooltip":"jq is required"}\n'
    exit 0
fi

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

read_millidegrees() {
    local file="$1"
    [[ -r "$file" ]] || return 1

    awk -v v="$(cat "$file" 2>/dev/null)" \
        'BEGIN { printf "%.0f", v / 1000 }'
}

# ============================================================
# CPU temperature
# ============================================================

find_cpu_temp_file() {
    local h name label candidate wanted

    for h in /sys/class/hwmon/hwmon*; do
        [[ -r "$h/name" ]] || continue
        name="$(cat "$h/name" 2>/dev/null)"

        case "$name" in
            coretemp)
                wanted="Package id 0"
                ;;
            k10temp|zenpower)
                wanted="Tctl"
                ;;
            cpu_thermal|cpu-thermal)
                if [[ -r "$h/temp1_input" ]]; then
                    printf '%s' "$h/temp1_input"
                    return 0
                fi
                continue
                ;;
            *)
                continue
                ;;
        esac

        for label in "$h"/temp*_label; do
            [[ -r "$label" ]] || continue

            if [[ "$(cat "$label" 2>/dev/null)" == "$wanted" ]]; then
                candidate="${label%_label}_input"

                if [[ -r "$candidate" ]]; then
                    printf '%s' "$candidate"
                    return 0
                fi
            fi
        done

        # AMD fallback
        if [[ "$name" == "k10temp" || "$name" == "zenpower" ]]; then
            for label in "$h"/temp*_label; do
                [[ -r "$label" ]] || continue

                if [[ "$(cat "$label" 2>/dev/null)" == "Tdie" ]]; then
                    candidate="${label%_label}_input"

                    if [[ -r "$candidate" ]]; then
                        printf '%s' "$candidate"
                        return 0
                    fi
                fi
            done
        fi
    done

    # Generic thermal-zone fallback
    for h in /sys/class/thermal/thermal_zone*; do
        [[ -r "$h/type" && -r "$h/temp" ]] || continue

        name="$(cat "$h/type" 2>/dev/null)"

        case "${name,,}" in
            *x86_pkg_temp*|*cpu*thermal*|*soc*thermal*)
                printf '%s' "$h/temp"
                return 0
                ;;
        esac
    done

    return 1
}

# ============================================================
# Fan discovery
# ============================================================

find_fan_hwmon() {
    local h file count
    local best=""
    local best_count=0

    # Pick whichever hwmon interface exposes the largest number
    # of readable tachometers.
    #
    # On the OMEN this naturally picks the HP interface with
    # fan1 + fan2 instead of the duplicate one-fan ACPI interface.
    for h in /sys/class/hwmon/hwmon*; do
        [[ -r "$h/name" ]] || continue

        count=0

        for file in "$h"/fan*_input; do
            [[ -r "$file" ]] && ((count+=1))
        done

        if (( count > best_count )); then
            best="$h"
            best_count="$count"
        fi
    done

    if [[ -n "$best" ]]; then
        printf '%s' "$best"
        return 0
    fi

    return 1
}

# ============================================================
# NVIDIA GPU discovery
# ============================================================

find_nvidia_gpu() {
    local d vendor class

    command -v nvidia-smi >/dev/null 2>&1 || return 1

    for d in /sys/bus/pci/devices/*; do
        [[ -r "$d/vendor" && -r "$d/class" ]] || continue

        vendor="$(cat "$d/vendor" 2>/dev/null)"
        class="$(cat "$d/class" 2>/dev/null)"

        if [[ "$vendor" == "0x10de" ]] &&
           { [[ "$class" == 0x0300* ]] || [[ "$class" == 0x0302* ]]; }; then

            printf '%s' "$d"
            return 0
        fi
    done

    return 1
}

# ============================================================
# Check for a genuine NVIDIA user workload
# ============================================================

nvidia_user_workload_active() {
    local proc uid comm fd target environ
    local has_gpu_node
    local has_uvm

    for proc in /proc/[0-9]*; do
        [[ -r "$proc/status" ]] || continue
        [[ -r "$proc/comm" ]] || continue
        [[ -d "$proc/fd" ]] || continue

        uid="$(awk '/^Uid:/ {print $2; exit}' \
            "$proc/status" 2>/dev/null)"

        [[ "$uid" == "$UID" ]] || continue

        comm="$(cat "$proc/comm" 2>/dev/null)"

        # Desktop/infrastructure processes can keep NVIDIA device
        # nodes open without representing a real dGPU workload.
        case "$comm" in
            Xorg|Xwayland|Hyprland|hyprpaper|waybar|\
            nvidia-smi|nvidia-powerd|nvidia-persistenced|\
            "RDD Process")
                continue
                ;;
        esac

        has_gpu_node=0
        has_uvm=0

        for fd in "$proc"/fd/*; do
            [[ -e "$fd" || -L "$fd" ]] || continue

            target="$(readlink "$fd" 2>/dev/null || true)"

            case "$target" in
                /dev/nvidia[0-9]*)
                    has_gpu_node=1
                    ;;

                /dev/nvidia-uvm|/dev/nvidia-uvm-tools)
                    has_uvm=1
                    ;;
            esac
        done

        # CUDA / compute workload.
        if (( has_uvm )); then
            return 0
        fi

        # A graphics workload counts only if it is explicitly using
        # NVIDIA PRIME render offload.
        if (( has_gpu_node )) && [[ -r "$proc/environ" ]]; then

            environ="$(
                tr '\0' '\n' < "$proc/environ" 2>/dev/null || true
            )"

            if grep -Eq \
                '^(__NV_PRIME_RENDER_OFFLOAD=1|__GLX_VENDOR_LIBRARY_NAME=nvidia|__VK_LAYER_NV_optimus=NVIDIA_only)$' \
                <<< "$environ"; then

                return 0
            fi
        fi
    done

    return 1
}

# ============================================================
# Collect telemetry
# ============================================================

parts=()
tooltip_sections=()
css_class="normal"

# ------------------------------------------------------------
# CPU
# ------------------------------------------------------------

cpu_file="$(find_cpu_temp_file 2>/dev/null || true)"

if [[ -n "$cpu_file" ]]; then
    cpu_temp="$(read_millidegrees "$cpu_file" 2>/dev/null || true)"

    if [[ "$cpu_temp" =~ ^[0-9]+$ ]]; then
        parts+=("CPU ${cpu_temp}°")
        tooltip_sections+=(
            "CPU\nTemperature: ${cpu_temp} °C"
        )
    fi
fi

# ------------------------------------------------------------
# NVIDIA GPU
# ------------------------------------------------------------

nvidia_dir="$(find_nvidia_gpu 2>/dev/null || true)"

if [[ -n "$nvidia_dir" ]]; then

    gpu_runtime_file="$nvidia_dir/power/runtime_status"
    gpu_runtime="unknown"

    if [[ -r "$gpu_runtime_file" ]]; then
        gpu_runtime="$(cat "$gpu_runtime_file" 2>/dev/null)"
    fi

    case "$gpu_runtime" in

        suspended|suspending)

            parts+=("GPU sleep")

            tooltip_sections+=(
                "GPU\nNVIDIA dGPU: runtime suspended\nTelemetry intentionally not queried"
            )

            css_class="gpu-sleeping"
            ;;

        *)

            if nvidia_user_workload_active; then

                telemetry="$(
                    timeout 3 nvidia-smi \
                        --query-gpu=temperature.gpu,utilization.gpu,power.draw,memory.used,memory.total,pstate \
                        --format=csv,noheader,nounits \
                        2>/dev/null |
                    head -n1 || true
                )"

                if [[ -n "$telemetry" ]]; then

                    IFS=',' read -r \
                        gpu_temp \
                        gpu_util \
                        gpu_power \
                        gpu_mem_used \
                        gpu_mem_total \
                        gpu_pstate <<< "$telemetry"

                    gpu_temp="$(trim "$gpu_temp")"
                    gpu_util="$(trim "$gpu_util")"
                    gpu_power="$(trim "$gpu_power")"
                    gpu_mem_used="$(trim "$gpu_mem_used")"
                    gpu_mem_total="$(trim "$gpu_mem_total")"
                    gpu_pstate="$(trim "$gpu_pstate")"

                    parts+=("GPU ${gpu_temp}°")

                    tooltip_sections+=(
                        "GPU\nTemperature: ${gpu_temp} °C\nUtilization: ${gpu_util}%\nPower: ${gpu_power} W\nVRAM: ${gpu_mem_used} / ${gpu_mem_total} MiB\nP-state: ${gpu_pstate}"
                    )

                    css_class="gpu-active"

                else

                    parts+=("GPU active")

                    tooltip_sections+=(
                        "GPU\nNVIDIA dGPU: active\nTelemetry query failed"
                    )

                    css_class="gpu-active"
                fi

            else

                # Something woke the GPU, but no normal user workload
                # is using it. Do NOT run nvidia-smi here because that
                # would prolong the wake period.

                parts+=("GPU wake")

                tooltip_sections+=(
                    "GPU\nNVIDIA dGPU: active\nNo user GPU workload detected\nTelemetry intentionally skipped so the GPU can suspend"
                )

                css_class="gpu-waking"
            fi
            ;;
    esac
fi

# ------------------------------------------------------------
# Fans
# ------------------------------------------------------------

fan_hwmon="$(find_fan_hwmon 2>/dev/null || true)"

if [[ -n "$fan_hwmon" ]]; then

    fan_driver="$(cat "$fan_hwmon/name" 2>/dev/null || echo hwmon)"

    max_rpm=0
    fan_lines=""

    for fan_file in "$fan_hwmon"/fan*_input; do

        [[ -r "$fan_file" ]] || continue

        rpm="$(cat "$fan_file" 2>/dev/null || true)"
        [[ "$rpm" =~ ^[0-9]+$ ]] || continue

        (( rpm > max_rpm )) && max_rpm="$rpm"

        fan_base="${fan_file%_input}"
        fan_number="${fan_base##*fan}"
        fan_label_file="${fan_base}_label"

        if [[ -r "$fan_label_file" ]]; then
            fan_label="$(cat "$fan_label_file" 2>/dev/null)"
        else
            fan_label="Fan $fan_number"
        fi

        fan_lines+="${fan_label}: ${rpm} RPM"$'\n'
    done

    if (( max_rpm > 0 )); then

        if (( max_rpm >= 1000 )); then
            fan_short="$(
                awk -v r="$max_rpm" \
                    'BEGIN { printf "%.1fk", r / 1000 }'
            )"
        else
            fan_short="$max_rpm"
        fi

        parts+=("FAN ${fan_short}")

        fan_lines="${fan_lines%$'\n'}"

        tooltip_sections+=(
            "Fans (${fan_driver})\n${fan_lines}"
        )
    fi
fi

# ============================================================
# JSON output
# ============================================================

text=""

for part in "${parts[@]}"; do
    [[ -n "$text" ]] && text+="  "
    text+="$part"
done

tooltip=""

for section in "${tooltip_sections[@]}"; do
    [[ -n "$tooltip" ]] && tooltip+=$'\n\n'
    tooltip+="$section"
done

# Convert escaped "\n" sequences used above into real line breaks.
tooltip="${tooltip//\\n/$'\n'}"

jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text:$text, tooltip:$tooltip, class:$class}'
