#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path


def pct(num, den):
    return 100.0 * num / den if den else 0.0


def read_rows(path):
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "index": int(row["index"]),
                    "hardware_ok": int(row["hardware_ok"]),
                    "predicted": int(row["predicted"]),
                    "true_class": int(row["true_class"]),
                    "class_correct": int(row["class_correct"]),
                })
            except (KeyError, TypeError, ValueError):
                # Ignore a partially written trailing line if analyzing while xrun is still active.
                continue
    return rows


def parse_xrun_log(path):
    info = {
        "hardware_success_line": None,
        "final_summary_line": None,
        "finish_line": None,
        "xrun_exit_line": None,
        "xrun_total_time": None,
    }
    if not path or not Path(path).exists():
        return info

    for line in Path(path).read_text(errors="replace").splitlines():
        if "MNIST HARDWARE SUCCESSFUL" in line or "MNIST HARDWARE FAILED" in line:
            info["hardware_success_line"] = line.strip()
        if line.startswith("[MNIST] hardware_pass="):
            info["final_summary_line"] = line.strip()
        if "Simulation complete" in line:
            info["finish_line"] = line.strip()
        if "TOOL:" in line and "xrun" in line and "Exiting" in line:
            info["xrun_exit_line"] = line.strip()
            m = re.search(r"total:\s*([0-9:]+)", line)
            if m:
                info["xrun_total_time"] = m.group(1)
    return info


def build_report(rows, xrun_info=None):
    total = len(rows)
    hw_pass = sum(r["hardware_ok"] for r in rows)
    cls_pass = sum(r["class_correct"] for r in rows)
    hw_fail = total - hw_pass
    cls_fail = total - cls_pass

    confusion = [[0 for _ in range(10)] for _ in range(10)]
    support = [0 for _ in range(10)]
    correct = [0 for _ in range(10)]
    predicted_counts = [0 for _ in range(10)]
    hw_failed_rows = []

    for r in rows:
        t = r["true_class"]
        p = r["predicted"]
        if r["hardware_ok"] == 0:
            hw_failed_rows.append(r)
        if 0 <= p < 10:
            predicted_counts[p] += 1
        if 0 <= t < 10 and 0 <= p < 10:
            confusion[t][p] += 1
            support[t] += 1
            if t == p:
                correct[t] += 1

    lines = []
    lines.append("MNIST Hardware Accelerator Result Report")
    lines.append("========================================")
    lines.append(f"samples_completed      : {total}")
    if rows:
        lines.append(f"index_range            : {rows[0]['index']}..{rows[-1]['index']}")
    lines.append(f"hardware_pass          : {hw_pass}/{total} ({pct(hw_pass, total):.2f}%)")
    lines.append(f"hardware_fail          : {hw_fail}/{total} ({pct(hw_fail, total):.2f}%)")
    lines.append(f"classification_correct : {cls_pass}/{total} ({pct(cls_pass, total):.2f}%)")
    lines.append(f"classification_wrong   : {cls_fail}/{total} ({pct(cls_fail, total):.2f}%)")

    if xrun_info:
        lines.append("")
        lines.append("Xcelium Run")
        if xrun_info.get("xrun_total_time"):
            lines.append(f"xrun_total_time        : {xrun_info['xrun_total_time']}")
        if xrun_info.get("final_summary_line"):
            lines.append(f"xrun_final_summary     : {xrun_info['final_summary_line']}")
        if xrun_info.get("hardware_success_line"):
            lines.append(f"xrun_status            : {xrun_info['hardware_success_line']}")
        if xrun_info.get("finish_line"):
            lines.append(f"simulation_finish      : {xrun_info['finish_line']}")

    lines.append("")
    lines.append("Per-Class Accuracy")
    lines.append("class,total,correct,accuracy_percent")
    for d in range(10):
        lines.append(f"{d},{support[d]},{correct[d]},{pct(correct[d], support[d]):.2f}")

    lines.append("")
    lines.append("Prediction Distribution")
    lines.append("class,predicted_count,predicted_percent")
    for d in range(10):
        lines.append(f"{d},{predicted_counts[d]},{pct(predicted_counts[d], total):.2f}")

    lines.append("")
    lines.append("Confusion Matrix")
    lines.append("rows=true_class, columns=predicted_class")
    lines.append("true\\pred," + ",".join(str(i) for i in range(10)))
    for d in range(10):
        lines.append(str(d) + "," + ",".join(str(v) for v in confusion[d]))

    lines.append("")
    lines.append("Hardware Failed Samples")
    if hw_failed_rows:
        lines.append("index,predicted,true_class,class_correct")
        for r in hw_failed_rows[:50]:
            lines.append(f"{r['index']},{r['predicted']},{r['true_class']},{r['class_correct']}")
        if len(hw_failed_rows) > 50:
            lines.append(f"... {len(hw_failed_rows) - 50} more hardware failures not shown")
    else:
        lines.append("none")

    lines.append("")
    lines.append("First 50 Classification Misses")
    lines.append("index,predicted,true_class,hardware_ok")
    misses = [r for r in rows if r["class_correct"] == 0]
    for r in misses[:50]:
        lines.append(f"{r['index']},{r['predicted']},{r['true_class']},{r['hardware_ok']}")
    if len(misses) > 50:
        lines.append(f"... {len(misses) - 50} more misses not shown")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Analyze full-MNIST hardware summary.csv")
    ap.add_argument("summary", help="Path to mnist_logs/summary.csv")
    ap.add_argument("--xrun-log", default=None, help="Optional path to xrun_mnist.log")
    ap.add_argument("--out", default=None, help="Report output path; default: report.txt next to summary")
    args = ap.parse_args()

    summary = Path(args.summary)
    out = Path(args.out) if args.out else summary.with_name("report.txt")
    rows = read_rows(summary)
    xrun_info = parse_xrun_log(args.xrun_log)
    report = build_report(rows, xrun_info)
    out.write_text(report)
    print(report, end="")
    print(f"[MNIST_ANALYZE] wrote {out}")


if __name__ == "__main__":
    main()
