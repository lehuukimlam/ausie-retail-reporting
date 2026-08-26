/*
  BRONZE: online_order_line
  ----------
  Purpose: Pass-through of online order lines from DLT.
  Grain: one product line on an online order.
  Notes:
  - Prices GST-INCLUSIVE; qty negative on returns
  - product_version_id = version at order time
  - original_online_order_line_id links refund/return lines
*/
select * from {{ source('mysql_oltp', 'online_order_line') }}
