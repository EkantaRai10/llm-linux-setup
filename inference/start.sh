#!/usr/bin/env bash

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$PROJECT_DIR/config/inference.env"

if [[ ! -f "$MODEL_PATH" ]]; then
    echo "ERROR: Model not found: $MODEL_PATH"
    exit 1
fi

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "ERROR: llama-server binary not found: $LLAMA_SERVER"
    exit 1
fi

echo "Starting GKavach AI Inference Service..."
echo "Model: $MODEL_PATH"
echo "Endpoint: http://$HOST:$PORT"

exec "$LLAMA_SERVER" \
    -m "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    -c "$CONTEXT_SIZE" \
    -np "$PARALLEL_SLOTS" \
    -t "$THREADS"\
    --api-key-file "$PROJECT_DIR/config/api-keys.txt"