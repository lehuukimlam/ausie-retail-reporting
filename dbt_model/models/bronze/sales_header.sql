/*
  BRONZE: sales_header
  ----------
  Purpose: Pass-through of in-store POS headers from DLT `raw.sales_header`.
  Grain: one receipt / transaction header.
  Notes:
  - Money fields are GST-INCLUSIVE (subtotal_inc_gst, total_inc_gst, …)
  - transaction_at is local naive datetime (no timezone offset) — silver will add UTC / business date
  - staff_version_id / customer_id can be NULL (e.g. guest)
  - RETURNS link via original_sales_header_id
  - source_event_id unique in MySQL; bronze retry dupes may be added later in DLT
*/
select * from {{ source('mysql_oltp', 'sales_header') }}
