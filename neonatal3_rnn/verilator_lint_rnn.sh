#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

COMMON_FLAGS=(
  --lint-only
  --timing
  -Wall
  -Wno-DECLFILENAME
  -Wno-TIMESCALEMOD
  -Wno-SPECIFYIGN
  -Wno-PINCONNECTEMPTY
  -Wno-PINMISSING
  -Wno-PROCASSINIT
  -Wno-MULTITOP
  -Wno-GENUNNAMED
  -Wno-WIDTHEXPAND
  -Wno-WIDTHTRUNC
  -Wno-WIDTHXZEXPAND
  -Wno-UNUSEDSIGNAL
  -Wno-UNUSEDPARAM
  -Wno-CASEOVERLAP
  -Wno-CASEINCOMPLETE
  -Wno-MULTIDRIVEN
  -Wno-BLKSEQ
  -Wno-SYNCASYNCNET
  -DRTL
  -DARM_UD_MODEL
)

verilator "${COMMON_FLAGS[@]}" \
  --top-module test_rnn_vector_ops \
  -f ../sourcecode/dut_src_list.txt \
  ../sourcecode/tb/test_rnn_vector_ops.v

verilator "${COMMON_FLAGS[@]}" \
  --top-module hardware \
  -f ../sourcecode/dut_src_list.txt

echo "[VERILATOR_LINT_RNN] PASS"
