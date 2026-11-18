#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_FILE="/etc/systemd/system/llama.service"

echo -e "Working directory: $WORK_DIR \n"

# ---- Stop and remove the systemd service ----
if [[ -f "$SERVICE_FILE" ]]; then
    echo "==> Stopping and removing llama.service"
    sudo systemctl stop llama.service || true
    sudo systemctl disable llama.service || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl reset-failed || true
else
    echo "==> No llama.service found, skipping"
fi

# ---- Remove the build and cloned repo (optional) ----
read -rp "Remove llama.cpp source and build? [y/N]: " ANS
if [[ "${ANS,,}" == "y" ]]; then
    rm -rf "$WORK_DIR/inference/llama.cpp"
    echo "==> Removed llama.cpp"
fi

# ---- Remove config (optional) ----
read -rp "Remove config (inference.env and api-keys.txt)? [y/N]: " ANS
if [[ "${ANS,,}" == "y" ]]; then
    rm -f "$WORK_DIR/config/inference.env" "$WORK_DIR/config/api-keys.txt"
    echo "==> Removed config files"
fi

echo -e "\n==> Uninstall complete."
echo "Note: build tools (git, cmake, build-essential) and your model file were left untouched."