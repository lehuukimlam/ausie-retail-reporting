/*
  GOLD: dim_customer
  ----------
  Purpose: Customer dimension for fact_sales. PK = customer_key.
  Relationship: one dim_customer → many fact_sales rows (1:M).
           Guest / unknown sales keep customer_key NULL on the fact (no guest bucket row in v1).
  Logic:
  - customer_key = customer_id from CRM / OLTP.
  - Names (first_name / last_name): kept as landed; customer_name concat for reporting.
  - email = cleaned lower/trim from silver (not email_raw).
  - state_code = conformed AU code; country_code passed through (AU in seed).
  - customer_number can be NULL in source (seed edge case) — still a valid dim row.
  - No SCD2 on customer in v1 (unlike staff/product).
*/
select
    customer_id as customer_key,
    customer_number,
    first_name,
    last_name,
    trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) as customer_name,
    email,
    phone,
    suburb,
    state_code,
    postcode_text as postcode,
    country_code
from {{ ref('silver_customer') }}
