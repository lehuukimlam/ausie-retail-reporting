/*
  GOLD: dim_location
  ----------
  Purpose: Store / channel dimension for fact_sales. PK = location_key.
  Relationship: one dim_location row → many fact_sales rows (1:M).
  Logic:
  - Built from silver_store (already has state_code, channel, timezone).
  - location_key = store_id (OLTP surrogate; stable 1:1 with store_code).
  - Includes offline stores + ONLINE channel row (store_code = ONLINE).
  - state_code = conformed AU code; state_text not carried to gold (available in silver).
  - country_code passed through (AU in seed).
  - store_name kept as landed (no rename).
  - Not snowflaked: no separate dim_region table in v1.
*/
select
    store_id as location_key,
    store_code,
    store_name,
    channel,
    state_code,
    postcode_text as postcode,
    suburb,
    timezone_name,
    country_code,
    is_active
from {{ ref('silver_store') }}
