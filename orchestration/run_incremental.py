"""
Incremental refresh: new MySQL rows → DuckDB → dbt → tests → Power BI export.

Use this after synthetic/generate_trading_days.py (or any new OLTP activity).
Does NOT full-replace raw tables — DLT merges dims and pulls new facts by created_at.

How to run (venv on, from the project folder):
  python orchestration/run_incremental.py

Optional:
  --skip-test
  --skip-export
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
DBT_EXE = Path(sys.executable).parent / "dbt.exe"


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
        description="Incremental sync: MySQL deltas → gold → Power BI export"
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
    dbt = str(DBT_EXE if DBT_EXE.exists() else "dbt")
    log("Incremental pipeline start")
    log(f"Project folder: {ROOT}")

    run_step(
        "Incremental MySQL -> DuckDB (merge + created_at)",
        [python, str(INGEST_SCRIPT), "--mode", "incremental"],
        cwd=ROOT,
    )

    run_step(
        "Rebuild bronze, silver, and gold",
        [dbt, "run", "--profiles-dir", "."],
        cwd=DBT_DIR,
    )

    if not args.skip_test:
        run_step(
            "Run gold quality checks",
            [
                dbt,
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

    log("Incremental pipeline SUCCESS")


if __name__ == "__main__":
    main()
