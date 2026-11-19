/*
  SILVER: silver_online_order_header
  ----------
  Purpose: Cleaned Shopify-style order headers for omnichannel facts.
  Logic:
  - Bronze money is GST-INCLUSIVE (+ shipping_inc_gst).
  - order_at treated as local wall time in fulfilment store timezone
    (fallback Australia/Sydney if store missing — online often Sydney).
      business_date_local = date of order_at
      order_at_utc = order_at AT TIME ZONE store timezone
  - customer_id NULL = guest checkout; shipping_name may still have a label.
  - shipping_state_text kept (messy); shipping_state_code mapped like other silvers.
  - shipping_country_code passed through (AU in seed).
  - Names: shipping_name kept as landed (customer-facing label, not CRM name rules).
  - Returns: order_type RETURN + original_online_order_header_id.
  - total_ex_gst = total_inc_gst - gst_amount.
*/
select
    h.online_order_header_id,
    h.order_number,
    h.source_system,
    h.source_event_id,
    h.customer_id,
    h.fulfilment_store_id,
    h.original_online_order_header_id,
    h.order_type,
    h.order_status,
    h.order_at,
    cast(h.order_at as date) as business_date_local,
    (h.order_at at time zone coalesce(st.timezone_name, 'Australia/Sydney'))
        as order_at_utc,
    h.subtotal_inc_gst,
    h.discount_inc_gst,
    h.shipping_inc_gst,
    h.gst_amount,
    h.total_inc_gst,
    (h.total_inc_gst - h.gst_amount) as total_ex_gst,
    h.shipping_name,
    h.shipping_address_line_1,
    h.shipping_address_line_2,
    h.shipping_suburb,
    h.shipping_state_text,
    {{ au_state_code('h.shipping_state_text') }} as shipping_state_code,
    h.shipping_postcode_text,
    h.shipping_country_code,
    st.channel as fulfilment_channel,
    st.timezone_name as fulfilment_timezone_name,
    st.state_code as fulfilment_store_state_code,
    h.created_at,
    h.updated_at
from {{ ref('online_order_header') }} as h
left join {{ ref('silver_store') }} as st
    on h.fulfilment_store_id = st.store_id
