"""
CI / local helper: load mysql/seed.sql into DuckDB `raw` without MySQL or DLT.

Used by GitHub Actions so dbt can build on Ubuntu. This does **not** exercise
the MySQL → DLT ingest path — only the warehouse transforms + tests on the
committed seed fixture.

How to run (from repo root):
  python scripts/ci_seed_duckdb.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "mysql" / "seed.sql"
DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")


DDL = {
    "store": """
        create table raw.store (
          store_id bigint, store_code varchar, store_name varchar, channel varchar,
          timezone_name varchar, address_line_1 varchar, address_line_2 varchar,
          suburb varchar, state_text varchar, postcode_text varchar, country_code varchar,
          phone varchar, is_active boolean, created_at timestamp, updated_at timestamp
        )
        """,
    "staff": """
        create table raw.staff (
          staff_version_id bigint, staff_id bigint, staff_number varchar, store_id bigint,
          first_name varchar, last_name varchar, email varchar, role_name varchar,
          state_text varchar, effective_from timestamp, effective_to timestamp,
          is_current boolean, created_at timestamp
        )
        """,
    "product": """
        create table raw.product (
          product_version_id bigint, product_id bigint, sku varchar, product_name varchar,
          category_name varchar, brand_name varchar, unit_of_measure varchar,
          unit_cost_ex_gst decimal(13,4), unit_price_ex_gst decimal(13,4), gst_rate decimal(7,6),
          is_active boolean, effective_from timestamp, effective_to timestamp,
          is_current boolean, created_at timestamp
        )
        """,
    "customer": """
        create table raw.customer (
          customer_id bigint, customer_number varchar, first_name varchar, last_name varchar,
          email varchar, phone varchar, address_line_1 varchar, address_line_2 varchar,
          suburb varchar, state_text varchar, postcode_text varchar, country_code varchar,
          created_at timestamp, updated_at timestamp
        )
        """,
    "sales_header": """
        create table raw.sales_header (
          sales_header_id bigint, transaction_number varchar, source_system varchar,
          source_event_id varchar, store_id bigint, staff_version_id bigint, customer_id bigint,
          original_sales_header_id bigint, transaction_type varchar, transaction_at timestamp,
          subtotal_inc_gst decimal(14,2), discount_inc_gst decimal(14,2), gst_amount decimal(14,2),
          total_inc_gst decimal(14,2), state_text varchar, created_at timestamp
        )
        """,
    "sales_line": """
        create table raw.sales_line (
          sales_line_id bigint, sales_header_id bigint, line_number integer,
          product_version_id bigint, original_sales_line_id bigint, qty decimal(12,3),
          unit_price_inc_gst decimal(13,4), discount_inc_gst decimal(14,2),
          gst_amount decimal(14,2), line_total_inc_gst decimal(14,2), created_at timestamp
        )
        """,
    "online_order_header": """
        create table raw.online_order_header (
          online_order_header_id bigint, order_number varchar, source_system varchar,
          source_event_id varchar, customer_id bigint, fulfilment_store_id bigint,
          original_online_order_header_id bigint, order_type varchar, order_status varchar,
          order_at timestamp, subtotal_inc_gst decimal(14,2), discount_inc_gst decimal(14,2),
          shipping_inc_gst decimal(14,2), gst_amount decimal(14,2), total_inc_gst decimal(14,2),
          shipping_name varchar, shipping_address_line_1 varchar, shipping_address_line_2 varchar,
          shipping_suburb varchar, shipping_state_text varchar, shipping_postcode_text varchar,
          shipping_country_code varchar, created_at timestamp, updated_at timestamp
        )
        """,
    "online_order_line": """
        create table raw.online_order_line (
          online_order_line_id bigint, online_order_header_id bigint, line_number integer,
          product_version_id bigint, original_online_order_line_id bigint, qty decimal(12,3),
          unit_price_inc_gst decimal(13,4), discount_inc_gst decimal(14,2),
          gst_amount decimal(14,2), line_total_inc_gst decimal(14,2), created_at timestamp
        )
        """,
}


def main() -> None:
    if not SEED_PATH.exists():
        raise SystemExit(f"Missing seed file: {SEED_PATH}")

    DUCKDB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DUCKDB_PATH.exists():
        DUCKDB_PATH.unlink()

    con = duckdb.connect(str(DUCKDB_PATH))
    con.execute("create schema raw")
    for ddl in DDL.values():
        con.execute(ddl)

    seed = SEED_PATH.read_text(encoding="utf-8")
    pattern = re.compile(
        r"INSERT INTO (\w+)\s*\((.*?)\)\s*VALUES\s*(.*?);",
        re.S | re.I,
    )
    for match in pattern.finditer(seed):
        table, cols, values = match.group(1), match.group(2), match.group(3)
        cols = re.sub(r"\s+", " ", cols.strip())
        sql = f"INSERT INTO raw.{table} ({cols}) VALUES {values}"
        con.execute(sql)
        n = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
        print(f"raw.{table}: {n} rows", flush=True)

    # Seed omits created_at / updated_at on many inserts.
    # Stamp "now" so `dbt source freshness` can pass in CI (static 2024 dates would always fail).
    fill = [
        ("store", ["created_at", "updated_at"]),
        ("staff", ["created_at"]),
        ("product", ["created_at"]),
        ("customer", ["created_at", "updated_at"]),
        ("sales_header", ["created_at"]),
        ("sales_line", ["created_at"]),
        ("online_order_header", ["created_at", "updated_at"]),
        ("online_order_line", ["created_at"]),
    ]
    for table, cols in fill:
        for col in cols:
            con.execute(f"update raw.{table} set {col} = current_timestamp")

    con.close()
    print(f"Wrote {DUCKDB_PATH}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 — surface clear CI failure
        print(f"ci_seed_duckdb failed: {exc}", file=sys.stderr)
        raise
