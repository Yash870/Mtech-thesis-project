#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${MNIST_LOG_DIR:-$ROOT_DIR/neonatal3/scripts/mnist_logs}"
SUMMARY="$LOG_DIR/summary.csv"
XRUN_LOG="$LOG_DIR/xrun_mnist.log"
REPORT="$LOG_DIR/report.txt"

python3 "$ROOT_DIR/neonatal3/scripts/analyze_mnist_results.py" "$SUMMARY" --xrun-log "$XRUN_LOG" --out "$REPORT"
echo "[MNIST_ANALYZE] report: $REPORT"
