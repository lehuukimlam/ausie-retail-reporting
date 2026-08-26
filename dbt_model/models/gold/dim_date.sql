/*
  GOLD: dim_date
  ----------
  Purpose: Date dimension for fact_sales (star schema). PK = date_key.
  Relationship: one dim_date row → many fact_sales rows (1:M).
  Logic:
  - Not from MySQL — generate a day spine for 2024-01-01 .. 2025-12-31 (covers seed).
  - date_key = YYYYMMDD integer (stable, readable surrogate).
  - fiscal_year_au: Australian FY starts July.
      e.g. 2024-06-30 → FY 2024; 2024-07-01 → FY 2025.
  - season_au (meteorological-style for AU):
      Summer Dec-Feb, Autumn Mar-May, Winter Jun-Aug, Spring Sep-Nov.
  - Retail flags (v1 heuristics, not a full retail calendar table):
      is_boxing_day = 26 Dec
      is_eofy       = 30 Jun (EOFY peak day marker; real EOFY is a period)
      is_click_frenzy = first Tue in Nov (approx Click Frenzy timing; refine later)
  - Names: month_name / day_name from the date (English).
  - country: calendar is AU-oriented (FY/season); no country_code column needed.
*/
with spine as (
    select cast(d as date) as full_date
    from generate_series(
        date '2024-01-01',
        date '2025-12-31',
        interval '1 day'
    ) as t(d)
),
enriched as (
    select
        full_date,
        (year(full_date) * 10000 + month(full_date) * 100 + day(full_date)) as date_key,
        year(full_date) as calendar_year,
        month(full_date) as calendar_month,
        monthname(full_date) as month_name,
        day(full_date) as calendar_day,
        dayname(full_date) as day_name,
        week(full_date) as iso_week,
        case
            when month(full_date) >= 7 then year(full_date) + 1
            else year(full_date)
        end as fiscal_year_au,
        case
            when month(full_date) in (12, 1, 2) then 'Summer'
            when month(full_date) in (3, 4, 5) then 'Autumn'
            when month(full_date) in (6, 7, 8) then 'Winter'
            else 'Spring'
        end as season_au,
        (month(full_date) = 12 and day(full_date) = 26) as is_boxing_day,
        (month(full_date) = 6 and day(full_date) = 30) as is_eofy,
        (
            month(full_date) = 11
            and dayofweek(full_date) = 2
            and day(full_date) <= 7
        ) as is_click_frenzy
    from spine
)
select * from enriched
