/*
  SILVER: silver_online_order_line
  ----------
  Purpose: Cleaned online lines + header context for unified fact_sales later.
  Logic:
  - Prices GST-INCLUSIVE; line_total_ex_gst = line_total_inc_gst - gst_amount.
  - qty negative on returns; original_online_order_line_id links to sale line.
  - product_version_id = point-in-time catalog version.
  - Pull business_date_local, customer_id, order_type from silver_online_order_header.
  - No CRM person names on the line — only IDs.
*/
select
    l.online_order_line_id,
    l.online_order_header_id,
    l.line_number,
    l.product_version_id,
    l.original_online_order_line_id,
    l.qty,
    l.unit_price_inc_gst,
    l.discount_inc_gst,
    l.gst_amount,
    l.line_total_inc_gst,
    (l.line_total_inc_gst - l.gst_amount) as line_total_ex_gst,
    h.business_date_local,
    h.fulfilment_store_id as store_id,
    h.order_type,
    h.customer_id,
    h.order_status,
    l.created_at
from {{ ref('online_order_line') }} as l
inner join {{ ref('silver_online_order_header') }} as h
    on l.online_order_header_id = h.online_order_header_id
