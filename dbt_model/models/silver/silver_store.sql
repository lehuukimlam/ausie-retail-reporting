/*
  SILVER: silver_store
  ----------
  Purpose: Cleaned store dimension-ready attributes from bronze store.
  Logic:
  - Keep all bronze columns including messy state_text (audit / original).
  - Add state_code: map common AU spellings to NSW/VIC/QLD/WA/SA/TAS/NT/ACT.
    Examples: "N.S.W." / "New South Wales" → NSW; "Victoria" → VIC.
  - country_code: passed through (seed uses AU); no rewrite here.
  - Names (store_name): kept as landed — no rename/standardise yet.
  - channel + timezone_name: passed through for later sales timezone logic.
*/
select
    store_id,
    store_code,
    store_name,
    channel,
    timezone_name,
    address_line_1,
    address_line_2,
    suburb,
    state_text,
    {{ au_state_code('state_text') }} as state_code,
    postcode_text,
    country_code,
    phone,
    is_active,
    created_at,
    updated_at
from {{ ref('store') }}
