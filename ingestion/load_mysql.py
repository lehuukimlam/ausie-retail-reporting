"""
Copy retail tables from MySQL into DuckDB — full replace or incremental merge.

Modes:
  replace (default) — wipe/reload raw tables (first load / rebuild)
  incremental       — merge dims; pull only new fact rows by created_at watermark

How to run (venv on, from the project folder):
  python ingestion/load_mysql.py
  python ingestion/load_mysql.py --mode incremental

Usually called from orchestration/run_pipeline.py (replace)
or orchestration/run_incremental.py (incremental).
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
from urllib.parse import quote_plus

import dlt
from dotenv import load_dotenv
from dlt.sources.sql_database import sql_database

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

DIM_TABLES = ["store", "staff", "product", "customer"]
FACT_TABLES = [
    "sales_header",
    "sales_line",
    "online_order_header",
    "online_order_line",
]
OLTP_TABLES = DIM_TABLES + FACT_TABLES

FACT_PRIMARY_KEYS = {
    "sales_header": "sales_header_id",
    "sales_line": "sales_line_id",
    "online_order_header": "online_order_header_id",
    "online_order_line": "online_order_line_id",
}

DIM_PRIMARY_KEYS = {
    "store": "store_id",
    "staff": "staff_version_id",
    "product": "product_version_id",
    "customer": "customer_id",
}


def mysql_url() -> str:
    user = quote_plus(os.environ["MYSQL_USER"])
    password = quote_plus(os.environ["MYSQL_PASSWORD"])
    host = os.environ.get("MYSQL_HOST", "127.0.0.1")
    port = os.environ.get("MYSQL_PORT", "3306")
    database = os.environ.get("MYSQL_DATABASE", "ausie_retail_oltp")
    return f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"


def run_replace(duckdb_path: Path) -> None:
    source = sql_database(mysql_url(), table_names=OLTP_TABLES)
    pipeline = dlt.pipeline(
        pipeline_name="ausie_oltp",
        destination=dlt.destinations.duckdb(str(duckdb_path)),
        dataset_name="raw",
    )
    info = pipeline.run(source, write_disposition="replace")
    print(info)


def run_incremental(duckdb_path: Path) -> None:
    """
    Dims: merge on primary key (pick up rare master changes).
    Facts: merge + incremental on created_at (only new/changed rows since last run).
    """
    source = sql_database(mysql_url(), table_names=OLTP_TABLES)

    for name, pk in DIM_PRIMARY_KEYS.items():
        getattr(source, name).apply_hints(
            primary_key=pk,
            write_disposition="merge",
        )

    for name, pk in FACT_PRIMARY_KEYS.items():
        getattr(source, name).apply_hints(
            primary_key=pk,
            write_disposition="merge",
            incremental=dlt.sources.incremental("created_at"),
        )

    pipeline = dlt.pipeline(
        pipeline_name="ausie_oltp",
        destination=dlt.destinations.duckdb(str(duckdb_path)),
        dataset_name="raw",
    )
    info = pipeline.run(source)
    print(info)


def main() -> None:
    parser = argparse.ArgumentParser(description="MySQL → DuckDB raw load")
    parser.add_argument(
        "--mode",
        choices=("replace", "incremental"),
        default="replace",
        help="replace = full reload; incremental = merge + created_at watermark",
    )
    args = parser.parse_args()

    duckdb_path = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")
    duckdb_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Load mode: {args.mode}")
    print(f"DuckDB: {duckdb_path}")

    if args.mode == "incremental":
        run_incremental(duckdb_path)
    else:
        run_replace(duckdb_path)


if __name__ == "__main__":
    main()
