{% macro au_state_code(state_text_expr) -%}
{#
  Map messy Australian state / territory labels to standard codes.
  Used by silver_store, silver_customer, silver_staff, silver_online_order_header.
#}
case
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('NSW', 'NEWSOUTHWALES') then 'NSW'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('VIC', 'VICTORIA') then 'VIC'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('QLD', 'QUEENSLAND') then 'QLD'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('WA', 'WESTERNAUSTRALIA') then 'WA'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('SA', 'SOUTHAUSTRALIA') then 'SA'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('TAS', 'TASMANIA') then 'TAS'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('NT', 'NORTHERNTERRITORY') then 'NT'
    when upper(trim(replace(replace(coalesce({{ state_text_expr }}, ''), '.', ''), ' ', '')))
        in ('ACT', 'AUSTRALIANCAPITALTERRITORY') then 'ACT'
    else null
end
{%- endmacro %}
