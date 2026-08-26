/*
  BRONZE: online_order_header
  ----------
  Purpose: Pass-through of Shopify-style order headers from DLT.
  Grain: one online order header.
  Notes:
  - Money is GST-INCLUSIVE (plus shipping_inc_gst)
  - customer_id NULL = guest checkout
  - shipping_* name/address kept as landed (customer-facing shipping label)
  - shipping_state_text can be messy — clean when we add silver online models
  - country_code on shipping defaults AU
*/
select * from {{ source('mysql_oltp', 'online_order_header') }}
