#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMP_DIR="$ROOT_DIR/neonatal3/sourcecode/tb/veeresh_compiler"
SCRIPT_DIR="$ROOT_DIR/neonatal3/scripts"
START_INDEX="${MNIST_START:-0}"
COUNT="${MNIST_COUNT:-10000}"
CASE_ROOT="${MNIST_CASE_ROOT:-$COMP_DIR/build_output/mnist_cases}"
LOG_DIR="$SCRIPT_DIR/mnist_logs"
SUMMARY="$LOG_DIR/summary.csv"

mkdir -p "$LOG_DIR"
rm -f "$SUMMARY"
rm -rf /tmp/yashb_xcelium_mnist.d

cd "$SCRIPT_DIR"
set +e
xrun -f xrun_mnist.rtl \
    +MNIST_START="$START_INDEX" \
    +MNIST_COUNT="$COUNT" \
    +MNIST_CASE_ROOT="$CASE_ROOT" \
    +MNIST_SUMMARY="$SUMMARY" \
    | tee "$LOG_DIR/xrun_mnist.log"
xrun_rc=${PIPESTATUS[0]}
set -e

echo "[MNIST_SIM] summary: $SUMMARY"
if [[ -f "$SUMMARY" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        python3 "$SCRIPT_DIR/analyze_mnist_results.py" "$SUMMARY" --xrun-log "$LOG_DIR/xrun_mnist.log" --out "$LOG_DIR/report.txt"
    else
        echo "[MNIST_SIM] python3 not found on this machine; copy mnist_logs to laptop and run analyze_mnist_results.py there."
    fi
fi
exit "$xrun_rc"
