"""
Run text-to-SQL queries safely against DuckDB gold tables.

What this does:
  Checks the SQL is read-only, then runs it on the warehouse file and
  returns rows as a simple table (list of dicts).

Safety rules:
  - Warehouse opened read-only
  - Only SELECT / WITH ... SELECT allowed
  - Block words that change or export data
  - Query must mention main_gold (stay on reporting layer)
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import duckdb
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")

BLOCKED = re.compile(
    r"\b("
    r"insert|update|delete|drop|alter|create|attach|detach|copy|"
    r"pragma|call|execute|grant|revoke|truncate|merge|replace|"
    r"install|load|export|import"
    r")\b",
    re.IGNORECASE,
)


def assert_safe_select(sql: str) -> None:
    cleaned = sql.strip().rstrip(";")
    if not cleaned:
        raise ValueError("Empty SQL.")

    # Allow a single statement only
    if ";" in cleaned:
        raise ValueError("Only one SQL statement is allowed.")

    if BLOCKED.search(cleaned):
        raise ValueError("That SQL is not allowed (read-only SELECT only).")

    lowered = cleaned.lower()
    if not (lowered.startswith("select") or lowered.startswith("with")):
        raise ValueError("Only SELECT queries are allowed.")

    if "main_gold" not in lowered:
        raise ValueError("Query must use main_gold tables only.")


def run_sql(sql: str, max_rows: int = 200) -> tuple[list[str], list[tuple]]:
    """
    Returns (column_names, rows).
    Caps rows so a bad query cannot dump the whole warehouse to the screen.
    """
    assert_safe_select(sql)

    if not DUCKDB_PATH.exists():
        raise FileNotFoundError(
            f"Warehouse not found: {DUCKDB_PATH}. Run the pipeline first."
        )

    wrapped = f"select * from ({sql.strip().rstrip(';')}) as q limit {int(max_rows)}"
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)
    try:
        result = con.execute(wrapped)
        columns = [d[0] for d in result.description]
        rows = result.fetchall()
        return columns, rows
    finally:
        con.close()


def format_table(columns: list[str], rows: list[tuple]) -> str:
    if not columns:
        return "(no columns)"
    if not rows:
        return " | ".join(columns) + "\n(no rows)"

    str_rows = [[("" if v is None else str(v)) for v in row] for row in rows]
    widths = [len(c) for c in columns]
    for row in str_rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt(cells: list[str]) -> str:
        return " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(cells))

    lines = [fmt(columns), "-+-".join("-" * w for w in widths)]
    lines.extend(fmt(row) for row in str_rows)
    return "\n".join(lines)


def main() -> None:
    import sys

    sql = " ".join(sys.argv[1:]).strip()
    if not sql:
        sql = (
            "select l.store_name, sum(f.revenue_inc_gst) as revenue "
            "from main_gold.fact_sales f "
            "join main_gold.dim_location l on f.location_key = l.location_key "
            "group by 1 order by 2 desc"
        )
    cols, rows = run_sql(sql)
    print(format_table(cols, rows))


if __name__ == "__main__":
    main()
