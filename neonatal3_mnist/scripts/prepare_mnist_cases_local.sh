#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMP_DIR="$ROOT_DIR/neonatal3/sourcecode/tb/veeresh_compiler"
BUILD_DIR="$ROOT_DIR/picorv_code/build"
START_INDEX="${MNIST_START:-0}"
COUNT="${MNIST_COUNT:-10000}"
CROSS_PREFIX="${CROSS:-}"

cd "$COMP_DIR"
MNIST_START="$START_INDEX" MNIST_COUNT="$COUNT" python3 compiler_mnist.py

cd "$BUILD_DIR"
if [[ -n "$CROSS_PREFIX" ]]; then
    make mnist CROSS="$CROSS_PREFIX"
else
    make mnist
fi

echo "[MNIST_PREP] local preparation complete."
