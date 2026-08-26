/*
  SILVER: silver_staff
  ----------
  Purpose: Staff versions ready for point-in-time join onto sales.
  Logic:
  - Grain: one row per staff VERSION (staff_version_id), not one row per person.
  - staff_id = stable person key across versions.
  - Names (first_name / last_name): kept as landed — no Title Case / trim rules yet
    (same policy as customer names for now).
  - role_name / store_id / state_text can change between versions (promotion, transfer).
  - effective_from / effective_to / is_current define which version is valid on a given date.
  - state_text kept; state_code added (same AU mapping as silver_store / silver_customer).
  - email: lower(trim) into email; keep email_raw for audit (same idea as customers).
  - country is not on staff in OLTP; store link carries location context.
*/
select
    staff_version_id,
    staff_id,
    staff_number,
    store_id,
    first_name,
    last_name,
    email as email_raw,
    lower(trim(email)) as email,
    role_name,
    state_text,
    case
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('NSW', 'NEWSOUTHWALES') then 'NSW'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('VIC', 'VICTORIA') then 'VIC'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('QLD', 'QUEENSLAND') then 'QLD'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('WA', 'WESTERNAUSTRALIA') then 'WA'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('SA', 'SOUTHAUSTRALIA') then 'SA'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('TAS', 'TASMANIA') then 'TAS'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('NT', 'NORTHERNTERRITORY') then 'NT'
        when upper(trim(replace(replace(coalesce(state_text, ''), '.', ''), ' ', '')))
            in ('ACT', 'AUSTRALIANCAPITALTERRITORY') then 'ACT'
        else null
    end as state_code,
    effective_from,
    effective_to,
    is_current,
    created_at
from {{ ref('staff') }}
