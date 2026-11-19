# Customer history (SCD2) — business summary

A short re-read for owners, analysts, and hiring managers. Aussie specialty retail context: multi-store + online, loyalty customers, revenue by state.

**SCD2** here means: when a customer’s details change, we **keep the old row and open a new one**, with dates that say when each version was true — instead of overwriting the past.

| Read next | What you get |
|-----------|----------------|
| [README](../README.md) | Business context and requirements |
| [data-product.md](./data-product.md) | Power BI + ask-your-data |
| [data-transformation.md](./data-transformation.md) | Cleaning, tests, refresh |
| [data-understanding.md](./data-understanding.md) | Glossary + gold dictionary |

---

## 1. Why it mattered

Loyalty customer records in the shop CRM are **Type-1**: one row per person. If Alice moves from NSW to VIC, the system updates her address and **forgets** that she used to be in NSW.

Without warehouse history, any report that slices sales by **customer state** would rewrite the past. Last year’s Sydney sales could suddenly look like Victorian sales after she moves. That breaks trust for owner/accountant views of “where did revenue come from?”

Staff and product already kept versions in the shop systems. **Customers did not** — so this upgrade focused on making customer history real in the reporting warehouse.

---

## 2. What we built

Three linked steps:

1. **History capture** — each time cleaned customer details change, the warehouse keeps a dated version (via a dbt snapshot), rather than only “who they are today.”
2. **Versioned customer list** — the reporting customer table is one row per **version** (with from/to dates and a “current” flag), not one forever row per person.
3. **Sales use the right day** — each sale line links to the customer version that was true **on that trading day**, not today’s details.

Guests (no loyalty id) still have a blank customer on the sale. We do not invent a fake “Guest” person.

---

## 3. Result / proof

**Alice demo (plain language):** Alice shops while living in NSW. Those sales stay attributed to **NSW**. She later moves to VIC; a new sale after the move attributes to **VIC**. Older sales do **not** flip to VIC when her CRM record is updated.

Automated checks also confirm customer versions do not overlap in time and that each person has exactly one “current” version.

Demo runner (technical): `python synthetic/demo_customer_state_move.py`.

---

## 4. Impact on requirements and the data product

| Area | What changes / what stays true |
|------|--------------------------------|
| **Requirements** | Supports cleaned, trustworthy reporting (historical slices by customer attributes) without changing the business meaning of revenue, returns, or channel. |
| **Power BI / dashboards** | Same gold tables; customer key now means a **version**. State (and similar) on a sale reflects the customer **as at the sale date**. |
| **Ask-your-data** | Same idea: join the customer version on the sale; use `state_code` for history-aware questions. |
| **Guests** | Still blank customer on the fact — allowed and tested. |
| **Staff / product** | Already versioned in the shop systems; sales keep the version **stamped on the ticket**. Customer history is **warehouse-built** because the CRM only stores “current.” |

---

## 5. What to remember

> - Overwriting loyalty details used to **rewrite** revenue-by-state history.  
> - We now keep **dated customer versions** and attach each sale to the version true **that day**.  
> - Guests stay blank; staff/product versions come from the till/ERP, not the same customer snapshot path.  
> - Proof: Alice’s pre-move sales stay NSW; post-move sales show VIC.

---

## For technical readers

Implementation landed in PRs [#23](https://github.com/lehuukimlam/ausie-retail-reporting/pull/23) (snapshot), [#24](https://github.com/lehuukimlam/ausie-retail-reporting/pull/24) (gold join), and [#25](https://github.com/lehuukimlam/ausie-retail-reporting/pull/25) (tests & Alice demo). Cleaning and test behaviour: [data-transformation.md](./data-transformation.md).
