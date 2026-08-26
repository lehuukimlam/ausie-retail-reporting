/*
  GOLD: fact_sales
  ----------
  Purpose: Sales fact at LINE grain — the linking table of the star schema.
  Relationships (each many fact rows → one dim row, i.e. M:1 from fact to dim):
    fact_sales.date_key      → dim_date.date_key
    fact_sales.location_key  → dim_location.location_key
    fact_sales.staff_key     → dim_staff.staff_key          (NULL for online)
    fact_sales.product_key   → dim_product.product_key      (product VERSION)
    fact_sales.customer_key  → dim_customer.customer_key    (NULL for guest)
  Logic:
  - UNION of in-store POS lines + online order lines into one conformed fact.
  - Grain: one row per sale/return line (not header).
  - FKs are dim PKs (surrogates), not a snowflake of dim-to-dim links.
  - product_key / staff_key use the VERSION ids already on the silver lines
    (point-in-time as captured by POS/ERP — do not re-pick is_current).
  - channel: 'offline' for POS, 'online' for web.
  - Measures: qty, revenue inc/ex GST, discount inc GST, product_cost_ex_gst (from dim_product).
  - is_return from transaction_type / order_type = RETURN; qty may be negative.
  - Degenerate: source_system, transaction_id, line_id, original_transaction_id.
  - fact_sales_key: POS uses sales_line_id; online uses 1_000_000_000 + line id (no clash).
*/
with pos as (
    select
        l.sales_line_id as fact_sales_key,
        (year(l.business_date_local) * 10000
            + month(l.business_date_local) * 100
            + day(l.business_date_local)) as date_key,
        l.store_id as location_key,
        l.staff_version_id as staff_key,
        l.product_version_id as product_key,
        l.customer_id as customer_key,
        'offline' as channel,
        'POS' as source_system,
        h.transaction_number as transaction_id,
        cast(l.line_number as varchar) as line_id,
        cast(h.original_sales_header_id as varchar) as original_transaction_id,
        (upper(l.transaction_type) = 'RETURN') as is_return,
        l.qty,
        l.line_total_inc_gst as revenue_inc_gst,
        l.line_total_ex_gst as revenue_ex_gst,
        l.discount_inc_gst,
        l.gst_amount,
        l.unit_price_inc_gst
    from {{ ref('silver_sales_line') }} as l
    inner join {{ ref('silver_sales_header') }} as h
        on l.sales_header_id = h.sales_header_id
),
web as (
    select
        (1000000000 + l.online_order_line_id) as fact_sales_key,
        (year(l.business_date_local) * 10000
            + month(l.business_date_local) * 100
            + day(l.business_date_local)) as date_key,
        l.store_id as location_key,
        cast(null as bigint) as staff_key,
        l.product_version_id as product_key,
        l.customer_id as customer_key,
        'online' as channel,
        'ECOM' as source_system,
        h.order_number as transaction_id,
        cast(l.line_number as varchar) as line_id,
        cast(h.original_online_order_header_id as varchar) as original_transaction_id,
        (upper(l.order_type) = 'RETURN') as is_return,
        l.qty,
        l.line_total_inc_gst as revenue_inc_gst,
        l.line_total_ex_gst as revenue_ex_gst,
        l.discount_inc_gst,
        l.gst_amount,
        l.unit_price_inc_gst
    from {{ ref('silver_online_order_line') }} as l
    inner join {{ ref('silver_online_order_header') }} as h
        on l.online_order_header_id = h.online_order_header_id
),
unioned as (
    select * from pos
    union all
    select * from web
)
select
    u.fact_sales_key,
    u.date_key,
    u.location_key,
    u.staff_key,
    u.product_key,
    u.customer_key,
    u.channel,
    u.source_system,
    u.transaction_id,
    u.line_id,
    u.original_transaction_id,
    u.is_return,
    u.qty,
    u.revenue_inc_gst,
    u.revenue_ex_gst,
    u.discount_inc_gst,
    u.gst_amount,
    u.unit_price_inc_gst,
    round(coalesce(p.unit_cost_ex_gst, 0) * u.qty, 4) as product_cost_ex_gst
from unioned as u
left join {{ ref('dim_product') }} as p
    on u.product_key = p.product_key
