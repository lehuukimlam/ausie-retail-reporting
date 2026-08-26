/*
  SILVER: silver_sales_header
  ----------
  Purpose: Cleaned in-store POS headers for fact building.
  Logic:
  - Start from bronze sales_header (money already GST-INCLUSIVE).
  - Join silver_store for timezone_name, channel, state_code.
  - transaction_at is naive LOCAL wall time from POS (no offset in OLTP).
      business_date_local = calendar date of that local timestamp (trading day).
      transaction_at_utc   = interpret local time in store timezone → timestamptz (UTC-based).
  - Money:
      Keep all *_inc_gst and gst_amount from bronze.
      total_ex_gst = total_inc_gst - gst_amount (POS-provided GST).
  - customer_id NULL = guest; staff_version_id can be null.
  - Returns: transaction_type = RETURN; original_sales_header_id set.
  - state_text on header kept (messy); prefer store_state_code from silver_store.
*/
select
    h.sales_header_id,
    h.transaction_number,
    h.source_system,
    h.source_event_id,
    h.store_id,
    h.staff_version_id,
    h.customer_id,
    h.original_sales_header_id,
    h.transaction_type,
    h.transaction_at,
    cast(h.transaction_at as date) as business_date_local,
    (h.transaction_at at time zone coalesce(st.timezone_name, 'Australia/Sydney'))
        as transaction_at_utc,
    h.subtotal_inc_gst,
    h.discount_inc_gst,
    h.gst_amount,
    h.total_inc_gst,
    (h.total_inc_gst - h.gst_amount) as total_ex_gst,
    h.state_text,
    st.state_code as store_state_code,
    st.channel as store_channel,
    st.timezone_name as store_timezone_name,
    h.created_at
from {{ ref('sales_header') }} as h
left join {{ ref('silver_store') }} as st
    on h.store_id = st.store_id
