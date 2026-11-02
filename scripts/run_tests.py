"""Compile and run every self-checking testbench in tb/ with Icarus Verilog.

    python scripts/run_tests.py            # all testbenches
    python scripts/run_tests.py frame_awb  # names containing the given text

A testbench passes when it exits normally, prints a PASS or RESULT line, and
reports no FAIL line and no non-zero "errors=" count. Requires iverilog and vvp
on PATH (tested with Icarus Verilog 12). Build artifacts go to build/sim/.
"""
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HDL = sorted((ROOT / "hdl").glob("*.v"))
OUT = ROOT / "build" / "sim"


def run(tb, keyword):
    top = re.search(r"^module\s+(tb_\w+)", tb.read_text(), re.M).group(1)
    if keyword and keyword not in top:
        return None
    OUT.mkdir(parents=True, exist_ok=True)
    vvp = OUT / f"{top}.vvp"
    # -g2005: custom_ae_frame_stats uses `sequence` as a signal name.
    build = subprocess.run(["iverilog", "-g2005", "-s", top, "-o", str(vvp), str(tb), *map(str, HDL)],
                           capture_output=True, text=True)
    if build.returncode:
        return top, False, build.stderr.strip().splitlines()[:3], 0.0
    start = time.time()
    sim = subprocess.run(["vvp", "-n", str(vvp)], capture_output=True, text=True, cwd=OUT)
    lines = sim.stdout.splitlines()
    (OUT / f"{top}.log").write_text(sim.stdout + sim.stderr, encoding="utf-8")
    summary = [l for l in lines if l.startswith(("PASS", "RESULT", "FAIL"))]
    ok = (sim.returncode == 0 and summary
          and not any(l.startswith("FAIL") for l in lines)
          and not any(int(n) for n in re.findall(r"errors=(\d+)", "\n".join(summary))))
    return top, bool(ok), summary[-2:], time.time() - start


def main():
    keyword = sys.argv[1] if len(sys.argv) > 1 else ""
    results = [r for r in (run(tb, keyword) for tb in sorted((ROOT / "tb").glob("tb_*.v"))) if r]
    for top, ok, summary, seconds in results:
        print(f"{'PASS' if ok else 'FAIL'}  {top:<28} {seconds:6.1f}s  {' | '.join(summary)}")
    failed = [r for r in results if not r[1]]
    print(f"{len(results) - len(failed)}/{len(results)} testbenches passed")
    sys.exit(1 if failed or not results else 0)


if __name__ == "__main__":
    main()
