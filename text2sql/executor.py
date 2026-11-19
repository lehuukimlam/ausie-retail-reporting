"""
Run text-to-SQL queries safely against DuckDB gold tables.

What this does:
  Parses the SQL (DuckDB AST), allows only approved main_gold tables,
  disables external file access (blocks .env / CSV reads), then runs
  read-only and returns rows as a simple table.

Safety rules:
  - Warehouse opened read-only + enable_external_access=false
  - Only a single SELECT / WITH ... SELECT
  - Block DDL/DML keywords
  - Relation allowlist: main_gold.<GOLD_TABLES> or CTEs only
  - Table functions (read_csv, read_text, …) rejected
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

import duckdb
from dotenv import load_dotenv

from text2sql.schema import GOLD_SCHEMA, GOLD_TABLES

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")
ALLOWED_TABLES = frozenset(GOLD_TABLES)

BLOCKED = re.compile(
    r"\b("
    r"insert|update|delete|drop|alter|create|attach|detach|copy|"
    r"pragma|call|execute|grant|revoke|truncate|merge|replace|"
    r"install|load|export|import"
    r")\b",
    re.IGNORECASE,
)

SECRET_PATH_HINT = re.compile(
    r"(?:^|[\\/])\.env(?:$|[\\/])|\.env\b|credentials|secrets?[\\/]",
    re.IGNORECASE,
)


def _walk(node: Any, pred) -> list[Any]:
    found: list[Any] = []
    if isinstance(node, dict):
        if pred(node):
            found.append(node)
        for v in node.values():
            found.extend(_walk(v, pred))
    elif isinstance(node, list):
        for item in node:
            found.extend(_walk(item, pred))
    return found


def _parse_ast(sql: str) -> dict:
    """Serialize SQL to DuckDB JSON AST (no warehouse needed)."""
    con = duckdb.connect()
    try:
        raw = con.execute("select json_serialize_sql(?)", [sql]).fetchone()[0]
    finally:
        con.close()
    data = json.loads(raw)
    if data.get("error"):
        raise ValueError(f"Could not parse SQL: {data.get('error_message') or data}")
    return data


def _cte_names(ast: dict) -> set[str]:
    names: set[str] = set()
    for node in _walk(ast, lambda n: isinstance(n, dict) and "cte_map" in n):
        cte_map = node.get("cte_map") or {}
        for entry in cte_map.get("map") or []:
            key = entry.get("key")
            if isinstance(key, str) and key:
                names.add(key.lower())
    return names


def _assert_gold_relations(ast: dict) -> None:
    ctes = _cte_names(ast)

    for fn in _walk(ast, lambda n: isinstance(n, dict) and n.get("type") == "TABLE_FUNCTION"):
        fname = ((fn.get("function") or {}).get("function_name") or "").lower()
        raise ValueError(
            f"Table function '{fname or 'unknown'}' is not allowed "
            "(no external files / .env / CSV reads)."
        )

    for base in _walk(ast, lambda n: isinstance(n, dict) and n.get("type") == "BASE_TABLE"):
        schema = (base.get("schema_name") or "").lower()
        table = (base.get("table_name") or "").lower()
        if not table:
            raise ValueError("Could not resolve a table name in the SQL.")

        if not schema:
            if table in ctes:
                continue
            if table in ALLOWED_TABLES:
                # Unqualified gold table — OK (search path / prompt uses main_gold.)
                continue
            allowed = ", ".join(f"{GOLD_SCHEMA}.{t}" for t in sorted(ALLOWED_TABLES))
            raise ValueError(
                f"Table '{table}' is not an approved gold table. Use only: {allowed}."
            )

        if schema != GOLD_SCHEMA.lower():
            raise ValueError(
                f"Schema '{schema}' is not allowed. "
                f"Queries may only use {GOLD_SCHEMA} gold tables."
            )
        if table not in ALLOWED_TABLES:
            raise ValueError(
                f"Table '{GOLD_SCHEMA}.{table}' is not on the gold allowlist."
            )


def assert_safe_select(sql: str) -> None:
    cleaned = sql.strip().rstrip(";")
    if not cleaned:
        raise ValueError("Empty SQL.")

    if ";" in cleaned:
        raise ValueError("Only one SQL statement is allowed.")

    if BLOCKED.search(cleaned):
        raise ValueError("That SQL is not allowed (read-only SELECT only).")

    if SECRET_PATH_HINT.search(cleaned):
        raise ValueError("References to secrets / .env paths are not allowed.")

    lowered = cleaned.lower()
    if not (lowered.startswith("select") or lowered.startswith("with")):
        raise ValueError("Only SELECT queries are allowed.")

    ast = _parse_ast(cleaned)
    statements = ast.get("statements") or []
    if len(statements) != 1:
        raise ValueError("Only one SQL statement is allowed.")

    _assert_gold_relations(ast)


def _connect_readonly() -> duckdb.DuckDBPyConnection:
    if not DUCKDB_PATH.exists():
        raise FileNotFoundError(
            f"Warehouse not found: {DUCKDB_PATH}. Run the pipeline first."
        )
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)
    # Belt-and-braces: engine refuses file reads even if SQL slipped past the AST check.
    con.execute("SET enable_external_access=false")
    return con


def run_sql(sql: str, max_rows: int = 200) -> tuple[list[str], list[tuple]]:
    """
    Returns (column_names, rows).
    Caps rows so a bad query cannot dump the whole warehouse to the screen.
    """
    assert_safe_select(sql)

    wrapped = f"select * from ({sql.strip().rstrip(';')}) as q limit {int(max_rows)}"
    con = _connect_readonly()
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
