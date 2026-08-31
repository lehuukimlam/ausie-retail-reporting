"""
Copy retail tables from MySQL into DuckDB (raw landing area).

What this does:
  Connects to the MySQL database using settings in .env, then loads the
  listed tables into DuckDB under the `raw` schema. dbt bronze models
  read from that raw copy next.

How to run (venv on, from the project folder):
  python ingestion/load_mysql.py

Usually this runs as step 1 of orchestration/run_pipeline.py.
"""

from pathlib import Path

from dotenv import load_dotenv
from urllib.parse import quote_plus
import os
import dlt
from dlt.sources.sql_database import sql_database

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

OLTP_TABLES = [
    "store",
    "staff",
    "product",
    "customer",
    "sales_header",
    "sales_line",
    "online_order_header",
    "online_order_line",
]


def mysql_url() -> str:
    user = quote_plus(os.environ["MYSQL_USER"])
    password = quote_plus(os.environ["MYSQL_PASSWORD"])
    host = os.environ.get("MYSQL_HOST", "127.0.0.1")
    port = os.environ.get("MYSQL_PORT", "3306")
    database = os.environ.get("MYSQL_DATABASE", "ausie_retail_oltp")
    return f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"


def main() -> None:
    duckdb_path = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")
    duckdb_path.parent.mkdir(parents=True, exist_ok=True)

    source = sql_database(mysql_url(), table_names=OLTP_TABLES)
    pipeline = dlt.pipeline(
        pipeline_name="ausie_oltp",
        destination=dlt.destinations.duckdb(str(duckdb_path)),
        dataset_name="raw",
    )
    info = pipeline.run(source, write_disposition="replace")
    print(info)


if __name__ == "__main__":
    main()
