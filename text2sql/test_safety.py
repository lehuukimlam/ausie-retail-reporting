"""
Lightweight safety checks for ask-your-data (no Gemini, no network).

Run from repo root:
  python -m text2sql.test_safety
"""

from __future__ import annotations

from text2sql.executor import assert_safe_select
from text2sql.pii import mask_pii


def _expect_fail(sql: str, label: str) -> None:
    try:
        assert_safe_select(sql)
    except ValueError:
        return
    raise AssertionError(f"Expected rejection for: {label}")


def _expect_ok(sql: str, label: str) -> None:
    assert_safe_select(sql)


def test_allow_gold_only() -> None:
    _expect_ok(
        "select store_name from main_gold.dim_location limit 5",
        "gold dim",
    )
    _expect_ok(
        "select sum(f.revenue_ex_gst) "
        "from main_gold.fact_sales f "
        "join main_gold.dim_location l on f.location_key = l.location_key",
        "gold join",
    )
    _expect_ok(
        "with t as (select location_key from main_gold.dim_location) "
        "select * from t",
        "cte over gold",
    )


def test_reject_silver_and_substring_trick() -> None:
    _expect_fail(
        "select * from main_silver.silver_customer",
        "silver",
    )
    # Old guard only checked substring 'main_gold' — must still fail.
    _expect_fail(
        "select 'main_gold' as decoy from main_silver.silver_store",
        "substring decoy",
    )
    _expect_fail(
        "select * from raw.customer",
        "raw",
    )


def test_reject_env_and_file_reads() -> None:
    _expect_fail("select * from read_csv('.env')", "read_csv .env")
    _expect_fail("select * from read_text('.env')", "read_text .env")
    _expect_fail(
        "select * from main_gold.fact_sales where path = '.env'",
        "literal .env path hint",
    )


def test_mask_pii() -> None:
    text = "Contact Alice.Smith@Example.COM or +61 412 345 678 please"
    masked = mask_pii(text)
    assert "Alice.Smith@Example.COM" not in masked
    assert "@" not in masked or "[email masked]" in masked
    assert "[email masked]" in masked
    assert "[phone masked]" in masked
    assert "412 345 678" not in masked


def main() -> None:
    test_allow_gold_only()
    test_reject_silver_and_substring_trick()
    test_reject_env_and_file_reads()
    test_mask_pii()
    print("OK: text2sql safety checks passed.")


if __name__ == "__main__":
    main()
