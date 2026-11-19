/*
  GOLD: dim_customer
  ----------
  Purpose: Customer VERSION dimension for fact_sales. PK = customer_key.
  Relationship: one dim_customer version → many fact_sales rows (1:M).
           Guest / unknown sales keep customer_key NULL on the fact (no guest bucket row).
  Logic:
  - Built from snapshot_customer (warehouse SCD2); CRM OLTP remains Type-1.
  - Grain: one row per customer VERSION, not one forever person.
  - customer_key = dbt_scd_id (stable surrogate per snapshot version).
  - customer_id = durable CRM id across versions.
  - Names / email / phone / suburb / state_code / postcode / country as-of that version
    (email is cleaned lower/trim from silver via the snapshot).
  - valid_from / valid_to / is_current from dbt_valid_* (dates for reporting joins).
  - Earliest version per customer: valid_from fixed to 1900-01-01 (not created_at).
    Seed / CI often leave created_at null then stamp "today", which would put the
    window after 2024–2025 sales and leave fact_sales.customer_key null.
  - customer_number can be NULL in source (seed edge case) — still a valid dim row.
  - Fact joins the version valid on business_date_local (half-open window).
*/
select
    dbt_scd_id as customer_key,
    customer_id,
    customer_number,
    first_name,
    last_name,
    trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) as customer_name,
    email,
    phone,
    suburb,
    state_code,
    postcode_text as postcode,
    country_code,
    case
        when row_number() over (
            partition by customer_id
            order by dbt_valid_from
        ) = 1
        then date '1900-01-01'
        else cast(dbt_valid_from as date)
    end as valid_from,
    cast(dbt_valid_to as date) as valid_to,
    (dbt_valid_to is null) as is_current
from {{ ref('snapshot_customer') }}
