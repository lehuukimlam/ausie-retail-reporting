/*
  BRONZE: store
  ----------
  Purpose: Pass-through of DLT `raw.store` (MySQL OLTP copy). No cleaning yet.
  Grain: one row per store / channel location (incl. ONLINE).
  Notes:
  - state_text can be messy (NSW vs N.S.W.) — cleaned in silver_store.state_code
  - country_code expected AU from seed; not validated here
  - channel: offline | online
  - timezone_name used later for local → UTC (silver sales)
*/
select * from {{ source('mysql_oltp', 'store') }}
