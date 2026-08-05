#!/usr/bin/env bash
set -euo pipefail

systemctl --user stop app-dev.lizardbyte.app.Sunshine || true
sudo systemctl stop tailscaled || true

echo "Acceso remoto detenido."
