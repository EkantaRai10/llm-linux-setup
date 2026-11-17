#!/usr/bin/env bash
set -euo pipefail
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo -e "Working directory: $WORK_DIR \n"
cd "$WORK_DIR"

echo -e "==> Installing dependencies for llama.cpp Install C++ build prerequisites (Debian/Ubuntu example) \n"
# 1. Install C++ build prerequisites (Debian/Ubuntu example)
sudo apt-get update
sudo apt-get install -y \
    git \
    build-essential \
    cmake

cd "$WORK_DIR/inference"
if [ ! -d "llama.cpp" ]; then
    echo -e "==> Cloning llama.cpp repository \n"
    git clone https://github.com/ggml-org/llama.cpp.git
fi
cd "$WORK_DIR/inference/llama.cpp"
# if ! command -v cmake &> /dev/null; then
#     echo "CMake is not installed. Installing..."
#     sudo apt-get update
#     sudo apt-get install -y git build-essential cmake
# else
#     echo "CMake is already installed."
# fi

echo -e "==> Building llama.cpp \n"
cmake -B build
cmake --build build --config Release -j"$(nproc)"


echo "==> Build completed. Binary: $WORK_DIR/inference/llama.cpp/build/bin/llama-server"
# # Create a user for the inference service
# if ! id -u llama &>/dev/null; then
#     sudo useradd -m -s /bin/bash llama
#     sudo chown -R llama:llama "$WORK_DIR/inference/llama.cpp"
#     echo "User 'llama' created successfully."
# fi
SERVICE_USER="${SUDO_USER:-$(id -un)}"
echo "==> Creating systemd service for the inference service"
# Create a systemd service file for the inference service
sudo tee /etc/systemd/system/llama.service > /dev/null <<EOF
[Unit]
Description=GKavach AI Inference Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/inference/start.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now llama.service

