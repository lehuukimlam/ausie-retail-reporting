/*
  SILVER: silver_sales_line
  ----------
  Purpose: Cleaned POS lines; attach header business date for later fact grain.
  Logic:
  - Start from bronze sales_line (prices GST-INCLUSIVE).
  - Join silver_sales_header for business_date_local / store_id / transaction_type.
  - Money:
      Keep unit_price_inc_gst, discount_inc_gst, gst_amount, line_total_inc_gst.
      line_total_ex_gst = line_total_inc_gst - gst_amount.
  - qty can be negative on returns; original_sales_line_id links to original line.
  - product_version_id is the point-in-time product version (do not replace with is_current).
  - No person names here — only FKs.
*/
select
    l.sales_line_id,
    l.sales_header_id,
    l.line_number,
    l.product_version_id,
    l.original_sales_line_id,
    l.qty,
    l.unit_price_inc_gst,
    l.discount_inc_gst,
    l.gst_amount,
    l.line_total_inc_gst,
    (l.line_total_inc_gst - l.gst_amount) as line_total_ex_gst,
    h.business_date_local,
    h.store_id,
    h.transaction_type,
    h.staff_version_id,
    h.customer_id,
    l.created_at
from {{ ref('sales_line') }} as l
inner join {{ ref('silver_sales_header') }} as h
    on l.sales_header_id = h.sales_header_id
