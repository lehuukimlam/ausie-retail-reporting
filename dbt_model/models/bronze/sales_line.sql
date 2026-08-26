/*
  BRONZE: sales_line
  ----------
  Purpose: Pass-through of POS line items from DLT `raw.sales_line`.
  Grain: one product line on a receipt.
  Notes:
  - unit_price_inc_gst / line_total_inc_gst are GST-INCLUSIVE
  - qty can be negative on returns
  - product_version_id points at the product version sold (point-in-time)
  - original_sales_line_id links a return line to the original sale line
*/
select * from {{ source('mysql_oltp', 'sales_line') }}
