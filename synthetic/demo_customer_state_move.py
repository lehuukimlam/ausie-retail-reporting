"""
Alice NSW → VIC customer SCD2 state-move demo (DuckDB warehouse).

What this proves:
  1. Pre-move Alice sales resolve to the NSW dim_customer version.
  2. After CRM Type-1 update + dbt snapshot, a new sale on/after the move
     date resolves to the VIC version.
  3. Overlap / one-current singular tests still pass.

Prerequisites:
  - DuckDB warehouse already loaded with the MySQL seed in `raw`
    (full replace ingest, or a local seed into raw).
  - Python env with dbt-duckdb available (`dbt` on PATH or next to this interpreter).

How to run (from repo root):
  python synthetic/demo_customer_state_move.py

Notes:
  - Calls `dbt snapshot` itself for the mid-demo capture (pipelines also snapshot on each run).
  - Extends dim_date through 2026 so today's post-move sale can join.
  - Idempotent-ish: resets Alice to NSW and removes prior demo sale rows first.
"""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DBT_DIR = ROOT / "dbt_model"
DUCKDB_PATH = ROOT / os.environ.get("DUCKDB_PATH", "duckdb_warehouse/warehouse.duckdb")

ALICE_ID = 1
DEMO_HEADER_ID = 9001
DEMO_LINE_ID = 9001
DEMO_TXN = "SYD01-DEMO-ALICE-VIC"
DEMO_EVENT = "POS-DEMO-ALICE-VIC-MOVE"


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] {msg}", flush=True)


def dbt_cmd() -> str:
    exe = Path(sys.executable).parent / "dbt"
    if exe.exists():
        return str(exe)
    return "dbt"


def run_dbt(args: list[str]) -> None:
    cmd = [dbt_cmd(), *args, "--profiles-dir", "."]
    log("dbt " + " ".join(args))
    result = subprocess.run(cmd, cwd=DBT_DIR)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def reset_alice_and_demo_rows(con: duckdb.DuckDBPyConnection, move_day: date) -> None:
    log("Reset Alice to NSW seed attributes; drop prior demo sale rows")
    con.execute(
        """
        update raw.customer
        set
            first_name = 'Alice',
            last_name = 'Smith',
            email = 'Alice.Smith@Example.COM',
            phone = '0412 555 101',
            address_line_1 = '18 Harbour Road',
            address_line_2 = null,
            suburb = 'Manly',
            state_text = 'N.S.W.',
            postcode_text = '2095',
            country_code = 'AU',
            updated_at = timestamp '2024-01-01'
        where customer_id = ?
        """,
        [ALICE_ID],
    )
    con.execute("delete from raw.sales_line where sales_line_id = ?", [DEMO_LINE_ID])
    con.execute("delete from raw.sales_header where sales_header_id = ?", [DEMO_HEADER_ID])
    # Keep move_day available for later insert
    _ = move_day


def apply_state_move(con: duckdb.DuckDBPyConnection, move_day: date) -> None:
    log(f"Apply Alice NSW→VIC move; insert post-move sale on {move_day.isoformat()}")
    move_ts = datetime(move_day.year, move_day.month, move_day.day, 12, 0, 0)
    con.execute(
        """
        update raw.customer
        set
            address_line_1 = '10 Swanston Street',
            address_line_2 = null,
            suburb = 'Carlton',
            state_text = 'VIC',
            postcode_text = '3053',
            updated_at = ?
        where customer_id = ?
        """,
        [move_ts, ALICE_ID],
    )
    con.execute(
        """
        insert into raw.sales_header (
            sales_header_id, transaction_number, source_system, source_event_id,
            store_id, staff_version_id, customer_id, original_sales_header_id,
            transaction_type, transaction_at, subtotal_inc_gst, discount_inc_gst,
            gst_amount, total_inc_gst, state_text, created_at
        ) values (
            ?, ?, 'POS', ?,
            1, 507, ?, null,
            'SALE', ?, 33.00, 0.00,
            3.00, 33.00, 'VIC', ?
        )
        """,
        [DEMO_HEADER_ID, DEMO_TXN, DEMO_EVENT, ALICE_ID, move_ts, move_ts],
    )
    con.execute(
        """
        insert into raw.sales_line (
            sales_line_id, sales_header_id, line_number, product_version_id,
            original_sales_line_id, qty, unit_price_inc_gst, discount_inc_gst,
            gst_amount, line_total_inc_gst, created_at
        ) values (
            ?, ?, 1, 1003,
            null, 1.000, 33.0000, 0.00,
            3.00, 33.00, ?
        )
        """,
        [DEMO_LINE_ID, DEMO_HEADER_ID, move_ts],
    )


def alice_sale_states(con: duckdb.DuckDBPyConnection) -> list[tuple]:
    return con.execute(
        """
        select
            f.transaction_id,
            f.date_key,
            c.state_code,
            c.is_current,
            c.valid_from,
            c.valid_to
        from main_gold.fact_sales as f
        inner join main_gold.dim_customer as c
            on f.customer_key = c.customer_key
        where c.customer_id = ?
        order by f.date_key, f.fact_sales_key
        """,
        [ALICE_ID],
    ).fetchall()


def assert_states(rows: list[tuple], expect_demo_vic: bool) -> None:
    if not rows:
        raise AssertionError("No Alice sales resolved to dim_customer")
    pre = [r for r in rows if r[0] != DEMO_TXN]
    demo = [r for r in rows if r[0] == DEMO_TXN]
    bad_pre = [r for r in pre if r[2] != "NSW"]
    if bad_pre:
        raise AssertionError(f"Pre-move Alice sales must be NSW, got: {bad_pre}")
    if expect_demo_vic:
        if not demo:
            raise AssertionError("Missing post-move demo sale on fact_sales")
        bad_demo = [r for r in demo if r[2] != "VIC"]
        if bad_demo:
            raise AssertionError(f"Post-move demo sale must be VIC, got: {bad_demo}")
    log(
        f"OK assertions (expect_demo_vic={expect_demo_vic}): "
        f"{len(pre)} pre-move NSW line(s), {len(demo)} demo line(s)"
    )


def main() -> None:
    if not DUCKDB_PATH.exists():
        raise SystemExit(f"Missing warehouse: {DUCKDB_PATH}")

    move_day = date.today()
    log(f"Warehouse: {DUCKDB_PATH}")
    log(f"Move / post-sale business date: {move_day.isoformat()}")

    con = duckdb.connect(str(DUCKDB_PATH))
    try:
        n_customers = con.execute("select count(*) from raw.customer").fetchone()[0]
        if n_customers < 1:
            raise SystemExit("raw.customer is empty — load the seed into DuckDB first")
    finally:
        con.close()

    # Baseline: Alice NSW, no demo sale, snapshot + gold
    con = duckdb.connect(str(DUCKDB_PATH))
    try:
        reset_alice_and_demo_rows(con, move_day)
    finally:
        con.close()

    run_dbt(["run", "--select", "customer", "silver_customer"])
    run_dbt(["snapshot", "--select", "snapshot_customer"])
    run_dbt(
        [
            "run",
            "--select",
            "dim_date",
            "dim_customer",
            "silver_sales_header",
            "silver_sales_line",
            "fact_sales",
        ]
    )

    con = duckdb.connect(str(DUCKDB_PATH))
    try:
        baseline = alice_sale_states(con)
        log(f"Baseline Alice rows: {len(baseline)}")
        assert_states(baseline, expect_demo_vic=False)
        apply_state_move(con, move_day)
    finally:
        con.close()

    # After move: re-snapshot then rebuild customer dim + sales fact
    run_dbt(["run", "--select", "customer", "silver_customer"])
    run_dbt(["snapshot", "--select", "snapshot_customer"])
    run_dbt(
        [
            "run",
            "--select",
            "dim_date",
            "dim_customer",
            "silver_sales_header",
            "silver_sales_line",
            "fact_sales",
        ]
    )
    run_dbt(
        [
            "test",
            "--select",
            "assert_dim_customer_no_overlap",
            "assert_dim_customer_one_current",
            "path:models/gold",
        ]
    )

    con = duckdb.connect(str(DUCKDB_PATH))
    try:
        after = alice_sale_states(con)
        for row in after:
            log(f"  {row}")
        assert_states(after, expect_demo_vic=True)
        versions = con.execute(
            """
            select customer_id, state_code, valid_from, valid_to, is_current
            from main_gold.dim_customer
            where customer_id = ?
            order by valid_from
            """,
            [ALICE_ID],
        ).fetchall()
        log(f"Alice dim versions: {versions}")
        if len(versions) < 2:
            raise AssertionError("Expected at least two Alice dim_customer versions")
    finally:
        con.close()

    log("STATE-MOVE DEMO SUCCESS")


if __name__ == "__main__":
    main()
