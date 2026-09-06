"""
Build a plain-English + SQL description of gold tables for the AI chat.

What this does:
  Reads column names and types from the DuckDB warehouse (gold schema only)
  and turns them into text the language model can use when writing SQL.

Why:
  The AI must only know about reporting tables (fact + dims), not raw MySQL
  or bronze/silver. That keeps answers aligned with Power BI.

How to try it (venv on, from the project folder):
  python -m text2sql.schema
"""

from __future__ import annotations

import os
from pathlib import Path

import duckdb
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")
GOLD_SCHEMA = "main_gold"

# Only these tables are allowed for text-to-SQL
GOLD_TABLES = [
    "fact_sales",
    "dim_date",
    "dim_location",
    "dim_product",
    "dim_staff",
    "dim_customer",
]

# Short business notes so the AI picks the right columns
TABLE_NOTES = {
    "fact_sales": (
        "One row = one sale or return line. "
        "Join dims on date_key, location_key, product_key, staff_key, customer_key. "
        "staff_key can be null for online; customer_key can be null for guests. "
        "Money: revenue_inc_gst, revenue_ex_gst, discount_inc_gst, gst_amount, product_cost_ex_gst. "
        "channel is 'offline' or 'online'. is_return is true for returns."
    ),
    "dim_date": (
        "Calendar day. PK date_key (YYYYMMDD). "
        "Use full_date, calendar_year, calendar_month, fiscal_year_au, season_au."
    ),
    "dim_location": (
        "Store or online channel. PK location_key. "
        "Use store_name, store_code, state_code, channel."
    ),
    "dim_product": (
        "Product version (not only current SKU). PK product_key. "
        "Use product_name, category_name, brand_name, sku."
    ),
    "dim_staff": (
        "Staff version. PK staff_key. "
        "Use staff_name, role_name. Online sales may have no staff."
    ),
    "dim_customer": (
        "Customer. PK customer_key. "
        "Use customer_name, email, state_code. Guests are missing on the fact."
    ),
}


def connect() -> duckdb.DuckDBPyConnection:
    if not DUCKDB_PATH.exists():
        raise FileNotFoundError(
            f"Warehouse not found: {DUCKDB_PATH}. Run the pipeline first."
        )
    return duckdb.connect(str(DUCKDB_PATH), read_only=True)


def list_gold_columns(con: duckdb.DuckDBPyConnection, table: str) -> list[tuple[str, str]]:
    rows = con.execute(
        """
        select column_name, data_type
        from information_schema.columns
        where table_schema = ?
          and table_name = ?
        order by ordinal_position
        """,
        [GOLD_SCHEMA, table],
    ).fetchall()
    return [(name, dtype) for name, dtype in rows]


def build_schema_prompt(con: duckdb.DuckDBPyConnection | None = None) -> str:
    """Return text describing gold tables for the LLM prompt."""
    own_con = con is None
    if own_con:
        con = connect()

    parts = [
        "You are helping with Australian retail sales reporting.",
        "Write DuckDB SQL only. Use ONLY these tables in schema main_gold.",
        "Prefer joins from fact_sales to dimensions. Do not invent tables or columns.",
        "Do not run DDL or change data (no INSERT/UPDATE/DELETE/DROP/ALTER/COPY).",
        "",
    ]

    try:
        for table in GOLD_TABLES:
            fq = f"{GOLD_SCHEMA}.{table}"
            cols = list_gold_columns(con, table)
            if not cols:
                raise RuntimeError(f"Missing gold table: {fq}")

            parts.append(f"TABLE {fq}")
            parts.append(f"  Note: {TABLE_NOTES[table]}")
            parts.append("  Columns:")
            for name, dtype in cols:
                parts.append(f"    - {name} ({dtype})")
            parts.append("")
    finally:
        if own_con and con is not None:
            con.close()

    return "\n".join(parts).strip() + "\n"


def main() -> None:
    text = build_schema_prompt()
    print(text)
    print("---")
    print(f"Schema characters: {len(text)}")
    print("OK: gold schema context ready for the AI step.")


if __name__ == "__main__":
    main()
