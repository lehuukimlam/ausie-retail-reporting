/*
  Business rule: revenue_ex_gst + gst_amount ≈ revenue_inc_gst (AUD cents).
*/
select
    fact_sales_key,
    revenue_ex_gst,
    gst_amount,
    revenue_inc_gst,
    round(revenue_ex_gst + gst_amount - revenue_inc_gst, 2) as gst_gap
from {{ ref('fact_sales') }}
where abs(round(revenue_ex_gst + gst_amount - revenue_inc_gst, 2)) > 0.02
