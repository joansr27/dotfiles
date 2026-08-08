#!/usr/bin/env bash
set -euo pipefail

sunshine_unit="app-dev.lizardbyte.app.Sunshine"
tailscaled_was_active=0

# Sunshine should never be started by this helper while the host firewall is
# disabled. This is an additional local safeguard; Tailscale grants remain
# responsible for restricting which tailnet clients may reach Sunshine.
if ! systemctl is-active --quiet firewalld; then
    echo "Error: firewalld is not active." >&2
    echo "Start it first with:" >&2
    echo "  sudo systemctl start firewalld" >&2
    exit 1
fi

# Remember whether Tailscale was already running so a failed startup does not
# unnecessarily stop a daemon that was active before this script was called.
if systemctl is-active --quiet tailscaled; then
    tailscaled_was_active=1
else
    sudo systemctl start tailscaled
fi

cleanup_tailscale_on_failure() {
    if (( tailscaled_was_active == 0 )); then
        sudo systemctl stop tailscaled || true
    fi
}

# tailscaled can take a moment to reconnect after being started.
tailscale_ready=0

for _ in {1..10}; do
    if tailscale status --json 2>/dev/null |
       jq -e '.BackendState == "Running"' >/dev/null; then
        tailscale_ready=1
        break
    fi

    sleep 1
done

if (( tailscale_ready == 0 )); then
    echo "Error: Tailscale did not reach the Running state." >&2
    echo "Check:" >&2
    echo "  tailscale status" >&2

    cleanup_tailscale_on_failure
    exit 1
fi

if ! tailscale ip -4 >/dev/null 2>&1; then
    echo "Error: no Tailscale IPv4 address is available." >&2

    cleanup_tailscale_on_failure
    exit 1
fi

if ! systemctl --user start "$sunshine_unit"; then
    echo "Error: Sunshine failed to start." >&2

    cleanup_tailscale_on_failure
    exit 1
fi

echo "Remote access started:"
echo "  - firewalld: active"
echo "  - Tailscale: connected"
echo "  - Sunshine: active"
