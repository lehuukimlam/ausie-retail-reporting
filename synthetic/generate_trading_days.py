"""
Insert synthetic POS + online sales for a short trading-day span (default 3 days).

What this does:
  Uses existing stores, staff, products, and customers in MySQL.
  Adds new sale/return-style headers and lines for each trading day
  so we can practise incremental sync without rebuilding the whole seed.

How to run (venv on, from the project folder):
  python synthetic/generate_trading_days.py
  python synthetic/generate_trading_days.py --days 3 --start-date 2025-11-10

Safe to re-run with the same --start-date: rows use fixed source_event_id
values, so MySQL unique keys skip / fail duplicates — use a new start date
or delete prior INC-* events if you need a clean re-insert.
"""

from __future__ import annotations

import argparse
import os
import random
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from urllib.parse import quote_plus

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

# Offline stores only (1–5); online fulfilment uses store 6 in headers via channel logic
OFFLINE_STORES = [
    {"store_id": 1, "code": "SYD01", "staff_version_id": 507, "state": "NSW"},
    {"store_id": 2, "code": "MEL01", "staff_version_id": 503, "state": "VIC"},
    {"store_id": 3, "code": "BNE01", "staff_version_id": 508, "state": "QLD"},
    {"store_id": 4, "code": "PER01", "staff_version_id": 505, "state": "WA"},
    {"store_id": 5, "code": "ADL01", "staff_version_id": 506, "state": "SA"},
]

# Current product versions from seed (ex-GST list prices)
PRODUCTS = [
    {"product_version_id": 1002, "price_ex": Decimal("32.00"), "cost_ex": Decimal("16.00")},
    {"product_version_id": 1003, "price_ex": Decimal("40.00"), "cost_ex": Decimal("20.00")},
    {"product_version_id": 1004, "price_ex": Decimal("10.00"), "cost_ex": Decimal("4.50")},
    {"product_version_id": 1005, "price_ex": Decimal("20.00"), "cost_ex": Decimal("9.00")},
    {"product_version_id": 1006, "price_ex": Decimal("15.00"), "cost_ex": Decimal("7.00")},
    {"product_version_id": 1007, "price_ex": Decimal("18.00"), "cost_ex": Decimal("8.00")},
    {"product_version_id": 1008, "price_ex": Decimal("25.00"), "cost_ex": Decimal("11.00")},
    {"product_version_id": 1012, "price_ex": Decimal("65.00"), "cost_ex": Decimal("31.00")},
    {"product_version_id": 1014, "price_ex": Decimal("35.00"), "cost_ex": Decimal("16.00")},
    {"product_version_id": 1017, "price_ex": Decimal("12.00"), "cost_ex": Decimal("5.00")},
]

CUSTOMER_IDS = [1, 2, 3, 4, 5, 6, 7, 8]
GST = Decimal("0.10")


def mysql_url() -> str:
    user = quote_plus(os.environ["MYSQL_USER"])
    password = quote_plus(os.environ["MYSQL_PASSWORD"])
    host = os.environ.get("MYSQL_HOST", "127.0.0.1")
    port = os.environ.get("MYSQL_PORT", "3306")
    database = os.environ.get("MYSQL_DATABASE", "ausie_retail_oltp")
    return f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"


def money_inc(ex: Decimal) -> Decimal:
    return (ex * (Decimal("1") + GST)).quantize(Decimal("0.01"))


def line_amounts(price_ex: Decimal, qty: int, discount_inc: Decimal = Decimal("0")) -> dict:
    unit_inc = money_inc(price_ex)
    line_inc = (unit_inc * qty - discount_inc).quantize(Decimal("0.01"))
    gst = (line_inc / Decimal("11")).quantize(Decimal("0.01"))  # 1/11 of inc-GST
    return {
        "unit_price_inc_gst": unit_inc,
        "discount_inc_gst": discount_inc,
        "gst_amount": gst,
        "line_total_inc_gst": line_inc,
    }


def insert_pos_sale(conn, day: date, day_index: int, seq: int, rng: random.Random) -> None:
    store = OFFLINE_STORES[seq % len(OFFLINE_STORES)]
    n_lines = rng.randint(1, 3)
    products = rng.sample(PRODUCTS, n_lines)
    customer_id = rng.choice(CUSTOMER_IDS + [None, None])  # guests sometimes
    hour = 10 + (seq % 8)
    minute = (seq * 7) % 60
    txn_at = datetime(day.year, day.month, day.day, hour, minute, 15)
    event_id = f"INC-POS-{day.isoformat()}-{store['code']}-{seq:03d}"
    txn_number = f"{store['code']}-{day.strftime('%Y%m%d')}-I{seq:03d}"

    lines = []
    for i, prod in enumerate(products, start=1):
        qty = rng.randint(1, 2)
        disc = Decimal("0.00")
        if rng.random() < 0.15:
            disc = Decimal("2.20")
        amounts = line_amounts(prod["price_ex"], qty, disc)
        lines.append((i, prod["product_version_id"], qty, amounts))

    subtotal = sum(a["line_total_inc_gst"] + a["discount_inc_gst"] for _, _, _, a in lines)
    discount = sum(a["discount_inc_gst"] for _, _, _, a in lines)
    gst = sum(a["gst_amount"] for _, _, _, a in lines)
    total = sum(a["line_total_inc_gst"] for _, _, _, a in lines)

    result = conn.execute(
        text(
            """
            INSERT INTO sales_header (
                transaction_number, source_system, source_event_id,
                store_id, staff_version_id, customer_id, original_sales_header_id,
                transaction_type, transaction_at, subtotal_inc_gst, discount_inc_gst,
                gst_amount, total_inc_gst, state_text
            ) VALUES (
                :txn_number, 'POS', :event_id,
                :store_id, :staff_version_id, :customer_id, NULL,
                'SALE', :txn_at, :subtotal, :discount, :gst, :total, :state
            )
            """
        ),
        {
            "txn_number": txn_number,
            "event_id": event_id,
            "store_id": store["store_id"],
            "staff_version_id": store["staff_version_id"],
            "customer_id": customer_id,
            "txn_at": txn_at,
            "subtotal": subtotal,
            "discount": discount,
            "gst": gst,
            "total": total,
            "state": store["state"],
        },
    )
    header_id = result.lastrowid

    for line_number, product_version_id, qty, amounts in lines:
        conn.execute(
            text(
                """
                INSERT INTO sales_line (
                    sales_header_id, line_number, product_version_id,
                    original_sales_line_id, qty, unit_price_inc_gst,
                    discount_inc_gst, gst_amount, line_total_inc_gst
                ) VALUES (
                    :header_id, :line_number, :product_version_id,
                    NULL, :qty, :unit_price, :discount, :gst, :line_total
                )
                """
            ),
            {
                "header_id": header_id,
                "line_number": line_number,
                "product_version_id": product_version_id,
                "qty": qty,
                "unit_price": amounts["unit_price_inc_gst"],
                "discount": amounts["discount_inc_gst"],
                "gst": amounts["gst_amount"],
                "line_total": amounts["line_total_inc_gst"],
            },
        )


def insert_online_order(conn, day: date, seq: int, rng: random.Random) -> None:
    store = OFFLINE_STORES[seq % len(OFFLINE_STORES)]  # fulfilment store
    prod = rng.choice(PRODUCTS)
    qty = 1
    amounts = line_amounts(prod["price_ex"], qty)
    guest = rng.random() < 0.4
    customer_id = None if guest else rng.choice(CUSTOMER_IDS)
    hour = 9 + (seq % 10)
    order_at = datetime(day.year, day.month, day.day, hour, 20, 0)
    event_id = f"INC-WEB-{day.isoformat()}-{seq:03d}"
    order_number = f"WEB-{day.strftime('%Y%m%d')}-I{seq:03d}"

    result = conn.execute(
        text(
            """
            INSERT INTO online_order_header (
                order_number, source_system, source_event_id,
                customer_id, fulfilment_store_id, original_online_order_header_id,
                order_type, order_status, order_at,
                subtotal_inc_gst, discount_inc_gst, shipping_inc_gst,
                gst_amount, total_inc_gst,
                shipping_name, shipping_suburb, shipping_state_text,
                shipping_postcode_text, shipping_country_code
            ) VALUES (
                :order_number, 'SHOPIFY', :event_id,
                :customer_id, :fulfil_store_id, NULL,
                'SALE', 'fulfilled', :order_at,
                :subtotal, 0.00, 0.00, :gst, :total,
                :shipping_name, :suburb, :state, '2000', 'AU'
            )
            """
        ),
        {
            "order_number": order_number,
            "event_id": event_id,
            "customer_id": customer_id,
            "fulfil_store_id": store["store_id"],
            "order_at": order_at,
            "subtotal": amounts["line_total_inc_gst"],
            "gst": amounts["gst_amount"],
            "total": amounts["line_total_inc_gst"],
            "shipping_name": "Incremental Guest" if guest else "Loyalty Customer",
            "suburb": "Sydney",
            "state": store["state"],
        },
    )
    header_id = result.lastrowid
    conn.execute(
        text(
            """
            INSERT INTO online_order_line (
                online_order_header_id, line_number, product_version_id,
                original_online_order_line_id, qty, unit_price_inc_gst,
                discount_inc_gst, gst_amount, line_total_inc_gst
            ) VALUES (
                :header_id, 1, :product_version_id, NULL, :qty,
                :unit_price, 0.00, :gst, :line_total
            )
            """
        ),
        {
            "header_id": header_id,
            "product_version_id": prod["product_version_id"],
            "qty": qty,
            "unit_price": amounts["unit_price_inc_gst"],
            "gst": amounts["gst_amount"],
            "line_total": amounts["line_total_inc_gst"],
        },
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic trading days into MySQL")
    parser.add_argument("--days", type=int, default=3, help="Number of trading days (default 3)")
    parser.add_argument(
        "--start-date",
        type=str,
        default=None,
        help="First day YYYY-MM-DD (default: today minus days+1)",
    )
    parser.add_argument("--seed", type=int, default=42, help="RNG seed for repeatable amounts")
    parser.add_argument(
        "--pos-per-day",
        type=int,
        default=4,
        help="POS baskets per day (default 4)",
    )
    parser.add_argument(
        "--online-per-day",
        type=int,
        default=2,
        help="Online orders per day (default 2)",
    )
    args = parser.parse_args()

    if args.days < 1:
        raise SystemExit("--days must be >= 1")

    if args.start_date:
        start = date.fromisoformat(args.start_date)
    else:
        start = date.today() - timedelta(days=args.days)

    rng = random.Random(args.seed)
    engine = create_engine(mysql_url())

    print(f"Generating {args.days} trading day(s) starting {start.isoformat()}")
    inserted_pos = 0
    inserted_web = 0
    skipped = 0
    with engine.connect() as conn:
        for d in range(args.days):
            day = start + timedelta(days=d)
            print(f"  Day {d + 1}/{args.days}: {day.isoformat()}")
            for seq in range(1, args.pos_per_day + 1):
                try:
                    with conn.begin_nested():
                        insert_pos_sale(conn, day, d, seq, rng)
                    inserted_pos += 1
                except IntegrityError:
                    skipped += 1
                    print(f"    skip POS seq={seq} (already exists)")
            for seq in range(1, args.online_per_day + 1):
                try:
                    with conn.begin_nested():
                        insert_online_order(conn, day, seq, rng)
                    inserted_web += 1
                except IntegrityError:
                    skipped += 1
                    print(f"    skip WEB seq={seq} (already exists)")
        conn.commit()

    print(
        f"OK: inserted POS={inserted_pos}, online={inserted_web}, skipped={skipped}."
    )
    print("Next: python orchestration/run_incremental.py")


if __name__ == "__main__":
    main()
