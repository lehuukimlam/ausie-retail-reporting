"""
Pipeline runner: refresh the warehouse and Power BI files in one go.

What this does (in order):
  1. Copy store systems data from MySQL into DuckDB (DLT)
  2. Rebuild bronze, silver, and gold tables (dbt)
  3. Run gold quality checks (dbt test) — stops if checks fail
  4. Export gold tables to Parquet so Power BI can refresh

When to run:
  Once a day after trading, or earlier if you need a mid-day refresh.
  Schedule this script (Windows Task Scheduler or similar) as needed.

How to run (venv on, from the project folder):
  python orchestration/run_pipeline.py

Optional:
  --skip-ingest   skip MySQL copy (only rebuild models + export)
  --skip-test     skip quality checks (not recommended)
  --skip-export   skip Power BI Parquet export
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
EXPORT_SCRIPT = ROOT / "powerbi" / "export_for_pbi.py"


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
    parser = argparse.ArgumentParser(
        description="Refresh warehouse and Power BI export files"
    )
    parser.add_argument(
        "--skip-ingest",
        action="store_true",
        help="Skip copying MySQL into DuckDB",
    )
    parser.add_argument(
        "--skip-test",
        action="store_true",
        help="Skip gold quality checks",
    )
    parser.add_argument(
        "--skip-export",
        action="store_true",
        help="Skip writing Parquet files for Power BI",
    )
    args = parser.parse_args()

    python = sys.executable
    log("Pipeline start")
    log(f"Project folder: {ROOT}")

    if not args.skip_ingest:
        run_step(
            "Copy MySQL data into DuckDB",
            [python, str(INGEST_SCRIPT)],
            cwd=ROOT,
        )
    else:
        log("SKIP: MySQL copy")

    run_step(
        "Rebuild bronze, silver, and gold",
        [python, "-m", "dbt", "run", "--profiles-dir", "."],
        cwd=DBT_DIR,
    )

    if not args.skip_test:
        run_step(
            "Run gold quality checks",
            [
                python,
                "-m",
                "dbt",
                "test",
                "--select",
                "path:models/gold",
                "--profiles-dir",
                ".",
            ],
            cwd=DBT_DIR,
        )
    else:
        log("SKIP: quality checks")

    if not args.skip_export:
        run_step(
            "Export reporting tables for Power BI",
            [python, str(EXPORT_SCRIPT)],
            cwd=ROOT,
        )
    else:
        log("SKIP: Power BI export")

    log("Pipeline SUCCESS")


if __name__ == "__main__":
    main()
