"""
Export reporting tables from DuckDB to Parquet files for Power BI.

What this does:
  Reads the gold (reporting) tables from the warehouse file and saves each
  one as a Parquet file under powerbi/export/.

Why:
  Power BI connects to these files. After the pipeline runs, the files are
  overwritten with fresh data. In Power BI, click Refresh to see the update.

Who uses it:
  Owners and accountants use Power BI. They do not need MySQL or DuckDB.

How to run (venv on, from the project folder):
  python powerbi/export_for_pbi.py

Usually this runs automatically as the last step of orchestration/run_pipeline.py.
"""

from __future__ import annotations

import os
from pathlib import Path

import duckdb
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")
EXPORT_DIR = ROOT / "powerbi" / "export"

# Gold tables live in the main_gold schema after dbt runs
GOLD_SCHEMA = "main_gold"
GOLD_TABLES = [
    "fact_sales",
    "dim_date",
    "dim_location",
    "dim_product",
    "dim_staff",
    "dim_customer",
]


def main() -> None:
    if not DUCKDB_PATH.exists():
        raise SystemExit(
            f"Warehouse file not found: {DUCKDB_PATH}. "
            "Run the pipeline (or dbt) first so gold tables exist."
        )

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)

    for table in GOLD_TABLES:
        out = EXPORT_DIR / f"{table}.parquet"
        fq = f"{GOLD_SCHEMA}.{table}"
        con.execute(f"copy (select * from {fq}) to '{out.as_posix()}' (format parquet)")
        n = con.execute(f"select count(*) from {fq}").fetchone()[0]
        print(f"Exported {fq} -> {out} ({n} rows)")

    con.close()
    print(f"Done. Power BI files are in: {EXPORT_DIR}")


if __name__ == "__main__":
    main()
