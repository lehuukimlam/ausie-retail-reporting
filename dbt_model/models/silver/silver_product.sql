/*
  SILVER: silver_product
  ----------
  Purpose: Product versions ready for margin / POS reconciliation.
  Logic:
  - Keep SCD fields: product_id, product_version_id, effective_from/to, is_current.
  - Names: product_name, category_name, brand_name kept as landed (history matters).
  - Money (AU GST):
      ERP bronze = EX-GST (unit_cost_ex_gst, unit_price_ex_gst, gst_rate)
      Add INC-GST helpers:
        unit_price_inc_gst = unit_price_ex_gst * (1 + gst_rate)
        unit_cost_inc_gst  = unit_cost_ex_gst  * (1 + gst_rate)  [null-safe]
      POS sales lines are already INC-GST — silver sales will use both for checks.
  - country is not on product (catalog is AU retailer-wide).
*/
select
    product_version_id,
    product_id,
    sku,
    product_name,
    category_name,
    brand_name,
    unit_of_measure,
    unit_cost_ex_gst,
    unit_price_ex_gst,
    round(unit_price_ex_gst * (1 + gst_rate), 4) as unit_price_inc_gst,
    case
        when unit_cost_ex_gst is null then null
        else round(unit_cost_ex_gst * (1 + gst_rate), 4)
    end as unit_cost_inc_gst,
    gst_rate,
    is_active,
    effective_from,
    effective_to,
    is_current,
    created_at
from {{ ref('product') }}
