/*
  GOLD: dim_product
  ----------
  Purpose: Product dimension (SCD2 versions) for fact_sales. PK = product_key.
  Relationship: one dim_product version → many fact_sales rows (1:M).
  Logic:
  - Grain: one row per product VERSION, not one row per SKU.
  - product_key = product_version_id (surrogate used as FK on fact_sales).
  - product_id / sku = durable business keys across versions.
  - Names (product_name, category_name, brand_name): kept as landed for that version.
  - Money: carry both EX-GST (ERP) and INC-GST helpers from silver_product.
  - valid_from / valid_to / is_current = SCD2 window (map from effective_*).
  - Fact must join the version that was true on business_date_local
    (sales lines already store product_version_id from POS — use that FK directly).
  - Star schema: category/brand stay on this dim (no snowflake dim_category in v1).
*/
select
    product_version_id as product_key,
    product_id,
    sku,
    product_name,
    category_name,
    brand_name,
    unit_of_measure,
    unit_cost_ex_gst,
    unit_price_ex_gst,
    unit_price_inc_gst,
    unit_cost_inc_gst,
    gst_rate,
    is_active,
    cast(effective_from as date) as valid_from,
    cast(effective_to as date) as valid_to,
    is_current
from {{ ref('silver_product') }}
