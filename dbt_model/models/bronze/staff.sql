/*
  BRONZE: staff
  ----------
  Purpose: Pass-through of DLT `raw.staff`. No cleaning yet.
  Grain: one row per staff VERSION (SCD2-style), not one row per person.
  Notes:
  - staff_id = person; staff_version_id = version PK
  - Names (first_name / last_name) kept as landed; no title-casing in bronze
  - role_name / home store can change across versions (effective_from / effective_to)
  - is_current marks the latest version
*/
select * from {{ source('mysql_oltp', 'staff') }}
