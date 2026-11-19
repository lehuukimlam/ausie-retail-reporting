-- Optional MySQL companion for the Alice NSW → VIC SCD2 demo.
-- Prefer the reproducible DuckDB runner:
--   python synthetic/demo_customer_state_move.py
--
-- If you maintain a live MySQL OLTP, run these AFTER the base seed, then:
--   1) ingest → dbt run (silver) → dbt snapshot --select snapshot_customer
--   2) dbt run --select dim_customer fact_sales
-- Pre-move Alice sales (already in seed.sql) should attribute to NSW;
-- the new sale below should attribute to VIC after the snapshot.

USE ausie_retail_oltp;

UPDATE customer
SET
    address_line_1 = '10 Swanston Street',
    address_line_2 = NULL,
    suburb = 'Carlton',
    state_text = 'VIC',
    postcode_text = '3053'
WHERE customer_id = 1;

-- Use a trading date on/after the day you run dbt snapshot for the move.
INSERT INTO sales_header (
    sales_header_id, transaction_number, source_system, source_event_id,
    store_id, staff_version_id, customer_id, original_sales_header_id,
    transaction_type, transaction_at, subtotal_inc_gst, discount_inc_gst,
    gst_amount, total_inc_gst, state_text
) VALUES (
    9001, 'SYD01-DEMO-ALICE-VIC', 'POS', 'POS-DEMO-ALICE-VIC-MOVE',
    1, 507, 1, NULL,
    'SALE', NOW(), 33.00, 0.00,
    3.00, 33.00, 'VIC'
);

INSERT INTO sales_line (
    sales_line_id, sales_header_id, line_number, product_version_id,
    original_sales_line_id, qty, unit_price_inc_gst,
    discount_inc_gst, gst_amount, line_total_inc_gst
) VALUES (
    9001, 9001, 1, 1003, NULL, 1.000, 33.0000, 0.00, 3.00, 33.00
);
