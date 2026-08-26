/*
  BRONZE: product
  ----------
  Purpose: Pass-through of DLT `raw.product`. No cleaning yet.
  Grain: one row per product VERSION (SCD2-style).
  Notes:
  - Prices here are EX-GST (ERP style): unit_cost_ex_gst, unit_price_ex_gst
  - gst_rate usually 0.10 in AU
  - POS sales are INC-GST — reconciliation happens in silver (see silver_product)
  - product_name / category can change across versions
*/
select * from {{ source('mysql_oltp', 'product') }}
