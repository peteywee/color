#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
RUNTIME_DIR="${COLOR_RUNTIME_HOME:-$HOME/.local/share/tss/color}"

echo "[INFO] Bootstrapping color environment"
echo "[INFO] Source repo: $SCRIPT_DIR"
echo "[INFO] Runtime dir: $RUNTIME_DIR"

exec "$SCRIPT_DIR/install_runtime.sh" --runtime-dir "$RUNTIME_DIR" "$@"
