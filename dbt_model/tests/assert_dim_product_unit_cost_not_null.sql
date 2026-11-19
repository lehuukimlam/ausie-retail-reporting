/*
  Business rule: product versions must have unit_cost_ex_gst so margin is not
  silently 100% (fact used to coalesce null cost to 0).
*/
select
    product_key,
    product_id,
    sku,
    unit_cost_ex_gst
from {{ ref('dim_product') }}
where unit_cost_ex_gst is null
