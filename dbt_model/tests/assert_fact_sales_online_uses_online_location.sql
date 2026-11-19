/*
  Online channel lines must use the ONLINE dim_location row — not a physical
  fulfilment store. Channel reporting (fact.channel) stays separate from
  fulfilment_store_id on silver.
*/
select
    f.fact_sales_key,
    f.channel,
    f.location_key,
    loc.store_code,
    loc.channel as location_channel
from {{ ref('fact_sales') }} as f
inner join {{ ref('dim_location') }} as loc
    on f.location_key = loc.location_key
where f.channel = 'online'
  and loc.store_code <> 'ONLINE'
