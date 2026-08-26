/*
  BRONZE: customer
  ----------
  Purpose: Pass-through of DLT `raw.customer`. No cleaning yet.
  Grain: one row per customer_id.
  Notes:
  - email may have mixed casing (Alice.Smith@Example.COM) — cleaned in silver_customer
  - first_name / last_name kept as landed (no standardisation in bronze)
  - state_text can be messy — silver adds state_code
  - country_code default AU in OLTP; guest checkouts often have NULL customer_id on sales
  - customer_number can be NULL in seed (edge case)
*/
select * from {{ source('mysql_oltp', 'customer') }}
