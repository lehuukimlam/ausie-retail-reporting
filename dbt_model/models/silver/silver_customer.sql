/*
  SILVER: silver_customer
  ----------
  Purpose: Clean customer attributes for matching and reporting.
  Logic:
  - Names (first_name / last_name): kept as landed — no Title Case yet
    (real CRM often has mixed quality; we may standardise later).
  - Email:
      email_raw = original from bronze (audit)
      email     = lower(trim(...)) so Alice.Smith@Example.COM matches alice.smith@example.com
  - state_text kept; state_code added (same AU mapping as silver_store).
  - country_code passed through (AU in seed).
  - phone / address passed through (format cleaning can come later).
*/
select
    customer_id,
    customer_number,
    first_name,
    last_name,
    email as email_raw,
    lower(trim(email)) as email,
    phone,
    address_line_1,
    address_line_2,
    suburb,
    state_text,
    {{ au_state_code('state_text') }} as state_code,
    postcode_text,
    country_code,
    created_at,
    updated_at
from {{ ref('customer') }}
