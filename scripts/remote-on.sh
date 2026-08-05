#!/usr/bin/env bash
set -euo pipefail

sudo systemctl start tailscaled
systemctl --user start app-dev.lizardbyte.app.Sunshine

echo "Acceso remoto iniciado:"
echo "  - tailscaled: activo"
echo "  - Sunshine: activo"
