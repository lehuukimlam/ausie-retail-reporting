/*
  GOLD: dim_staff
  ----------
  Purpose: Staff dimension (SCD2 versions) for fact_sales. PK = staff_key.
  Relationship: one dim_staff version → many fact_sales rows (1:M).
           Online lines may have NULL staff_key on the fact.
  Logic:
  - Grain: one row per staff VERSION (not one row per person).
  - staff_key = staff_version_id (FK used on fact_sales).
  - staff_id / staff_number = durable person keys across versions.
  - Names: first_name + last_name kept as landed; also staff_name concat for reporting.
  - role_name can change across versions (promotion) — that is why versions exist.
  - home_store_id = store_id on this version (transfer history).
  - email = cleaned lower/trim from silver; email_raw not carried to gold.
  - state_code from silver (conformed); country not on staff.
  - valid_from / valid_to / is_current map from effective_* SCD window.
  - Sales already store staff_version_id — fact joins that key directly (point-in-time).
*/
select
    staff_version_id as staff_key,
    staff_id,
    staff_number,
    store_id as home_store_id,
    first_name,
    last_name,
    trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) as staff_name,
    email,
    role_name,
    state_code,
    cast(effective_from as date) as valid_from,
    cast(effective_to as date) as valid_to,
    is_current
from {{ ref('silver_staff') }}
