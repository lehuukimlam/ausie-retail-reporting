"""
Orchestrator: run the full warehouse pipeline in order.

Business meaning:
  One "daily run" for the data team — land OLTP data, rebuild bronze/silver/gold,
  then fail if gold quality tests break (so BI does not refresh on bad data).

Steps:
  1) DLT  — MySQL → DuckDB `raw`
  2) dbt run  — bronze → silver → gold
  3) dbt test — gold PK / FK / channel checks

Usage (venv on, from repo root):
  python orchestration/run_pipeline.py

Optional skip flags:
  python orchestration/run_pipeline.py --skip-ingest
  python orchestration/run_pipeline.py --skip-test
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DBT_DIR = ROOT / "dbt_model"
INGEST_SCRIPT = ROOT / "ingestion" / "load_mysql.py"


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] {msg}", flush=True)


def run_step(name: str, cmd: list[str], cwd: Path) -> None:
    log(f"START: {name}")
    log(f"  cmd: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        log(f"FAIL: {name} (exit {result.returncode})")
        raise SystemExit(result.returncode)
    log(f"OK: {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Ausie retail: ingest → dbt → test")
    parser.add_argument(
        "--skip-ingest",
        action="store_true",
        help="Skip DLT MySQL→DuckDB (only dbt run/test)",
    )
    parser.add_argument(
        "--skip-test",
        action="store_true",
        help="Skip dbt test (not recommended for prod-like runs)",
    )
    args = parser.parse_args()

    python = sys.executable
    log("Pipeline start")
    log(f"Repo root: {ROOT}")

    if not args.skip_ingest:
        run_step(
            "DLT ingest (MySQL → DuckDB raw)",
            [python, str(INGEST_SCRIPT)],
            cwd=ROOT,
        )
    else:
        log("SKIP: ingest")

    run_step(
        "dbt run (bronze → silver → gold)",
        [python, "-m", "dbt", "run", "--profiles-dir", "."],
        cwd=DBT_DIR,
    )

    if not args.skip_test:
        run_step(
            "dbt test (gold quality)",
            [python, "-m", "dbt", "test", "--select", "path:models/gold", "--profiles-dir", "."],
            cwd=DBT_DIR,
        )
    else:
        log("SKIP: dbt test")

    log("Pipeline SUCCESS")


if __name__ == "__main__":
    main()
