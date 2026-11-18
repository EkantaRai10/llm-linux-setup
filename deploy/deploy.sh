#!/usr/bin/env bash
set -euo pipefail
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo -e "Working directory: $WORK_DIR \n"
cd "$WORK_DIR"

echo -e "==> Installing dependencies for llama.cpp \n"
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

echo -e "==> Building llama.cpp \n"
cmake -B build
cmake --build build --config Release -j"$(nproc)"
echo "==> Build completed. Binary: $WORK_DIR/inference/llama.cpp/build/bin/llama-server"

# ---- Create env file if missing ----
ENV_FILE="$WORK_DIR/config/inference.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "\n==> Creating $ENV_FILE"
    mkdir -p "$WORK_DIR/config"

    DEFAULT_MODEL="$HOME/models/model.gguf"

    read -rp "Model path [$DEFAULT_MODEL]: " MODEL_PATH
    read -rp "Host [127.0.0.1]: " HOST
    read -rp "Port [8080]: " PORT
    read -rp "Context size [4096]: " CONTEXT_SIZE
    read -rp "Parallel slots [1]: " PARALLEL_SLOTS
    read -rp "Threads [$(nproc)]: " THREADS

    cat > "$ENV_FILE" <<EOF
LLAMA_SERVER="$WORK_DIR/inference/llama.cpp/build/bin/llama-server"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
CONTEXT_SIZE="${CONTEXT_SIZE:-4096}"
PARALLEL_SLOTS="${PARALLEL_SLOTS:-1}"
THREADS="${THREADS:-$(nproc)}"
EOF
    chmod 600 "$ENV_FILE"
else
    echo -e "\n==> Using existing $ENV_FILE"
fi

# ---- systemd service ----
SERVICE_USER="${SUDO_USER:-$(id -un)}"

# ---- Create API keys file if missing ----
KEYS_FILE="$WORK_DIR/config/api-keys.txt"

if [[ ! -f "$KEYS_FILE" ]]; then
    echo -e "\n==> Creating $KEYS_FILE"
    mkdir -p "$WORK_DIR/config"
    : > "$KEYS_FILE"

    echo "Enter API keys one per line. Press Enter on an empty line to finish."
    while true; do
        read -rsp "API key: " KEY || break
        echo
        [[ -z "$KEY" ]] && break
        echo "$KEY" >> "$KEYS_FILE"
    done

    if [[ ! -s "$KEYS_FILE" ]]; then
        echo "WARNING: No keys entered. The server will run WITHOUT authentication."
    fi

    sudo chown "$SERVICE_USER":"$SERVICE_USER" "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
else
    echo -e "\n==> Using existing $KEYS_FILE"
fi

echo -e "\n==> Creating systemd service"

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
sudo chown "$SERVICE_USER":"$SERVICE_USER" "$WORK_DIR/config/inference.env"
sudo chmod 644 "$WORK_DIR/config/inference.env"
sudo systemctl daemon-reload
sudo systemctl enable llama.service
sudo systemctl restart llama.service

echo -e "\n==> Done. Check status with: systemctl status llama"