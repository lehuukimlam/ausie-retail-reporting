# Data transformation (business guide)

This guide explains **what we clean**, **why dbt**, **how layers relate**, **how we test gold**, and **how to see the model graph in the UI**.

Technical SQL lives under `dbt_model/models/`. Architecture: [data-architecture-stack.md](./data-architecture-stack.md). Schemas / ERD: [data-understanding.md](./data-understanding.md).

---

## 1. The story in plain language

| Layer | Business meaning |
|-------|------------------|
| **MySQL (OLTP)** | The “shop systems” — tills, product master, customers, online orders (our synthetic seed today). |
| **DuckDB `raw`** | Exact copy of those tables, landed by DLT. Nothing “fixed” yet. |
| **Bronze (dbt)** | Same data, organised for the warehouse. Still “as received.” |
| **Silver (dbt)** | **Cleaned** for analytics: standard states, emails, GST helpers, local vs UTC time. |
| **Gold (dbt)** | **Reporting model** — dimensions + `fact_sales` so an owner/accountant can slice revenue by store, product, day, staff, customer. |

**dbt** is the tool that runs and versions those SQL steps (like a controlled Power Query / SQL notebook pipeline). Analysts and engineers share the same definitions in Git.

---

## 2. Cleaning steps (silver) — business terms

### Stores (`silver_store` → `dim_location`)
- Keep the messy state text from the source (e.g. `N.S.W.`, `Victoria`) for audit.
- Add a standard **state code** (`NSW`, `VIC`, …) so dashboards don’t split one state into three spellings.
- Keep **channel** (offline / online) and **timezone** (Sydney vs Perth, etc.) for correct “trading day” logic.

### Customers (`silver_customer` → `dim_customer`)
- Keep original **email** as landed; also store a **normalised email** (lowercase, trimmed) so `Alice.Smith@Example.COM` matches `alice.smith@example.com`.
- Names left as received (no forced Title Case in v1).
- Same state-code idea as stores.
- **Guest checkout** has no customer id — gold keeps that as blank on the sale line (we don’t invent a fake “Guest” customer).

### Staff (`silver_staff` → `dim_staff`)
- People **change role / store over time**. We keep **versions** (old role closed, new role opened), not one forever-row.
- Email normalised like customers.
- Sales point at the **version that was true when the sale happened**.

### Products (`silver_product` → `dim_product`)
- Products also have **versions** (name / price / category change mid-year).
- Product master prices are **ex-GST**; tills often show **inc-GST**. Silver adds both so finance and ops can reconcile.
- Sales use the **product version on the ticket**, not “whatever is current today.”

### In-store sales (`silver_sales_*`)
- Receipt money stays **GST-inclusive** as on the till.
- We add **ex-GST** helpers using the GST amount on the receipt.
- Till time is **local store time** (no timezone on the raw stamp). We attach store timezone → **UTC** plus a **local business date** (the trading day).
- **Returns** are negative lines linked to an original sale.

### Online orders (`silver_online_order_*`)
- Same GST and date ideas; staff is usually blank (no cashier).
- Shipping state cleaned to a standard code where possible.
- Guest orders allowed (no customer id).

---

## 3. Gold model (reporting) — business terms

We use a **star schema** (not snowflake in v1):

- **Dimensions** = who / what / where / when (date, location, product version, staff version, customer).
- **`fact_sales`** = each **sale or return line**, with amounts and foreign keys to those dimensions.

Important relationship idea:

- Dimensions are **not** many-to-many with each other.
- The **fact** is the link: many sales lines can share one store, one product version, one day, etc. (many facts → one dim row).

`fact_sales` combines **in-store + online** into one place so channel reporting is consistent.

---

## 4. Data testing (gold)

We run automated checks with **`dbt test`** so broken keys don’t silently break reports.

Configured in `dbt_model/models/gold/schema.yml`:

| Check | Business meaning |
|-------|------------------|
| **unique / not_null** on dim keys and `fact_sales_key` | No duplicate or blank “ID cards” for date, store, product, staff, customer, or fact lines. |
| **relationships** (fact → dims) | Every sale’s store / product / date (and staff/customer when present) must exist in the dimension. Orphans = broken report joins. |
| **accepted_values** on `channel` | Only `offline` or `online` — no typos creating a fake third channel. |
| Nullable `staff_key` / `customer_key` | Online lines may have no staff; guests may have no customer — tests allow blank there. |

**How to run** (from `dbt_model`, venv on):

```bat
dbt test --select path:models/gold --profiles-dir .
```

Current seed: **all gold tests passing**.

---

## 5. Seeing dbt in the UI (lineage / dependencies)

dbt can generate a local website that shows **which models depend on which** (the DAG / lineage graph).

### Generate and open docs

From `dbt_model` with `(.venv)`:

```bat
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

Then open the URL it prints (usually `http://127.0.0.1:8080`).

### What to click

1. **Project** / model list — open e.g. `fact_sales`.
2. **Depends on** / lineage — see silver parents and dims.
3. Click **`fact_sales`** → graph view to zoom parents/children.
4. Column descriptions from `schema.yml` appear on the model page.
5. Press **Ctrl+C** in the terminal to stop the docs server when finished.

Optional: in Cursor/VS Code, a **dbt Power User** (or similar) extension can show lineage inside the editor — nice later; `dbt docs serve` works without extra plugins.

---

## 6. Typical daily commands (reminder)

```bat
cd C:\Users\admin\Projects\ausie-retail-reporting
.venv\Scripts\activate.bat

python ingestion\load_mysql.py

cd dbt_model
dbt run --profiles-dir .
dbt test --select path:models/gold --profiles-dir .
```

---

## 7. What’s next (not today)

- Scale generators (~50 stores / ~8k SKUs / 24 months) once this pipe stays trusted  
- More silver dirt (late files, POS retry duplicates in bronze)  
- Richer retail calendar flags  
- Dashboard / charts on gold  

---

## Session checkpoint

| Done | Status |
|------|--------|
| MySQL DDL + small seed | Yes |
| DLT → DuckDB raw | Yes |
| Bronze / silver / gold | Yes |
| Gold dbt tests | Yes (passing) |
| This transformation guide | Yes |
