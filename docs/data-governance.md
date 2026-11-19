# Data governance

How reporting data is kept **trustworthy** for this project — and which of those rules are **enforced in dbt / CI**, not only written down.

Written for a mixed audience: business-leaning portfolio readers and technical reviewers. Field and metric definitions live in [data-understanding.md](./data-understanding.md) (sections 5–6). Cleaning and gold tests overview: [data-transformation.md](./data-transformation.md).

| Read next | What you get |
|-----------|----------------|
| [README](../README.md) | Business context, requirements, use cases, CI badge |
| [data-understanding.md](./data-understanding.md) | Glossary + gold dictionary |
| [data-transformation.md](./data-transformation.md) | Cleaning, tests, refresh checks |
| [data-product.md](./data-product.md) | Power BI + ask-your-data |

---

## 1. Responsibilities

| Role | Responsibility |
|------|----------------|
| **Analyst (maintainer)** | Implements models, docs, tests, and pipelines; investigates failed refreshes |
| **Owner** (stakeholder) | Decides which performance questions matter (store, channel, product) |
| **Accountant** (stakeholder) | Cares about GST basis, returns, cost, and consistent money definitions |

This portfolio uses **synthetic** retail data. Stakeholder roles above are the intended consumers of the design. Any real-world reference (e.g. a store owner who reviewed the approach) is separate from automated approval of every metric.

---

## 2. Reporting rules

| Rule | What it means | Status | Evidence |
|------|---------------|--------|----------|
| **Gold is the only reporting source** | Power BI and ask-your-data must not bypass gold for business answers | Implemented | Parquet from gold; text-to-SQL restricted to `main_gold` |
| **Same definitions everywhere** | Revenue / returns / channel / category mean the same in docs, PBI, and chat | Manual + docs | [Glossary](./data-understanding.md#5-business-terms-and-reporting-definitions) |
| **Required checks before “validated” refresh** | Gold dbt tests must pass on the normal pipeline path before export | Implemented | `run_pipeline.py` / `run_incremental.py` |
| **Do not call skipped-test runs validated** | `--skip-test` is for development only | Manual | Runner flags |
| **AI is read-only on gold** | No writes; AST allowlist of gold tables; no silver/raw; no file/`.env` reads; email/phone masked before Gemini | Implemented | `text2sql/executor.py`, `text2sql/pii.py` |
| **Definition changes are recorded** | If Revenue or Category meaning changes, update glossary, dbt descriptions, AI context, and report labels together | Manual | Git + this docs set |
| **Governance as code** | Freshness, contracts, business rules, and consumer lineage live in dbt YAML/SQL and fail CI when broken | Implemented | Section 3 below; PR #28 |

---

## 3. Governance as code (what shipped)

“Governance as code” means the trust rules are **machine-checked** in the same repo as the models. YAML and SQL under `dbt_model/` are the source of truth; this page explains them for humans.

| Capability | Where it lives | What fails if wrong |
|------------|----------------|---------------------|
| Source freshness | `models/sources.yml` | `dbt source freshness` (CI step) |
| Owner / PII tags | `sources.yml`, gold `schema.yml`, project `meta` | Docs / lineage metadata (not a runtime gate by itself) |
| Gold contracts | `models/gold/schema.yml` (`contract.enforced`) | `dbt run` / `dbt build` on gold |
| Exposures | `models/exposures.yml` | Documented in `dbt docs`; deps must resolve |
| Business-rule tests | `tests/assert_*.sql` + column tests | `dbt build` / `dbt test` |
| Shared state mapping | `macros/au_state_code.sql` | Wrong mapping shows up in silver/gold + tests |

### 3.1 Source freshness

Raw landings are declared as dbt **source** `mysql_oltp` (DuckDB schema `raw`). Each table uses **`created_at`** as `loaded_at_field`.

Default windows (dimensions / masters): **warn** after 36 hours, **error** after 72 hours. Sales and online order tables are tighter: **warn** 24h / **error** 48h.

**Business meaning:** engineering can say “the warehouse has not seen new OLTP rows recently” separately from “the latest trading date in gold is D.”

**CI note:** `scripts/ci_seed_duckdb.py` stamps `created_at` / `updated_at` to **now** so freshness can pass without a live MySQL feed. A local warehouse left on old seed timestamps will fail freshness until re-seeded — that is intentional for a useful CI gate.

### 3.2 Owner and PII tags

Ownership and sensitivity are tagged in YAML so docs and lineage tools can surface them:

- Project default: models carry `meta.owner: analyst`.
- Sources: table-level `owner`; customer, staff, and shipping identity fields use `meta.contains_pii: true` and `tags: [pii]`.
- Gold: `dim_customer` / `dim_staff` (and name/email/phone columns) are marked the same way.

**Honest limit:** this is **portfolio practice on synthetic data**, not a production DLP or access-control system. Secrets still stay in local `.env` (never committed).

### 3.3 Gold model contracts

Every gold model (`dim_date`, `dim_location`, `dim_product`, `dim_staff`, `dim_customer`, `fact_sales`) has **`contract: enforced: true`** with explicit column `data_type`s matched to DuckDB.

**Business meaning:** reporting tables cannot silently change shape or types — a breaking rename or type drift fails the build before Parquet / dashboards update.

**Tradeoff:** DuckDB is type-sensitive (e.g. `bigint` vs unsigned variants). Contracts are kept accurate to what the adapter builds so CI stays green and useful.

### 3.4 Exposures (Power BI + Streamlit)

`models/exposures.yml` declares the two gold consumers:

| Exposure | Type | Audience | Feed |
|----------|------|----------|------|
| **Power BI owner / accountant dashboards** | Dashboard | Owner, accountant | `powerbi/export/*.parquet` after a green pipeline |
| **Ask-your-data (Streamlit + Gemini)** | Application | Analyst, owner | Live DuckDB `main_gold` (read-only) |

Both depend on the full gold star (`fact_sales` + dimensions). Exposures **document** lineage; they do not deploy Power BI or Streamlit.

### 3.5 Business-rule tests

Beyond keys and relationships (see [transformation — testing](./data-transformation.md#4-testing-gold-what-we-check)), these rules protect money logic:

| Rule | Check | Why it matters |
|------|-------|----------------|
| **GST identity** | `revenue_ex_gst + gst_amount ≈ revenue_inc_gst` (2¢ tolerance) | Inc-GST totals stay reconcilable to ex-GST + GST |
| **Returns qty** | If `is_return`, then `qty < 0` | Returns reduce revenue when summed — positive return qty would inflate sales |
| **Unit cost present** | `dim_product.unit_cost_ex_gst` not null; fact `product_cost_ex_gst` not null | Avoids silent **100% margin** when cost was missing |

`fact_sales` no longer uses `coalesce(unit_cost, 0)`. Missing cost surfaces as null / test failure instead of zero cost.

Singular tests live under `dbt_model/tests/` (`assert_fact_sales_gst_identity`, `assert_fact_sales_returns_negative_qty`, `assert_dim_product_unit_cost_not_null`).

### 3.6 Shared `au_state_code` macro

Australian state / territory labels used to be a **copy-pasted CASE** in four silver models. One macro, `au_state_code()`, now maps messy text (`N.S.W.`, `Victoria`, …) to standard codes (`NSW`, `VIC`, …) for:

- `silver_store`
- `silver_customer`
- `silver_staff`
- `silver_online_order_header` (shipping state)

**Business meaning:** one spelling policy for state reporting — dashboards should not split “Victoria” and “VIC” into two states because the CASE drifted.

### 3.7 How this runs in CI and dbt

GitHub Actions (`.github/workflows/ci.yml`) on every PR and on `main`:

1. Seed DuckDB from `mysql/seed.sql` (no MySQL / DLT in Actions)  
2. `dbt parse`  
3. **`dbt source freshness`**  
4. `dbt run` (bronze/silver + non-customer gold)  
5. `dbt snapshot` (`snapshot_customer`)  
6. **`dbt build`** on gold models + all singular/generic tests (SCD + business rules)  
7. SQLFluff on `dbt_model/models` (relaxed rules; macros loaded for Jinja)

Locally (from `dbt_model`, after a seed / pipeline load):

```bash
dbt source freshness --profiles-dir .
dbt build --select path:models/gold path:tests --profiles-dir .
dbt docs generate --profiles-dir .   # lineage includes exposures + tags
```

**Green CI** means freshness, contracts, gold tests (including business rules), and lint all passed on the committed seed — not that every store filed complete data for a calendar day.

---

## 4. Freshness for stakeholders (“as of”)

There is **no** gold column for warehouse import time (`imported_at` / `loaded_at`). Stakeholders should treat freshness as:

1. **Last successful refresh** — when `run_incremental.py` (or full pipeline) finished with **tests passed** and Parquet exported  
2. **Latest trading date in gold** — max trading date in `fact_sales` / Date dimension  
3. **Source freshness (engineering)** — `dbt source freshness` warn/error windows on raw landings (section 3.1)

| Claim | OK? |
|-------|-----|
| “Pipeline finished green” | Process freshness |
| “Latest sale day in the model is D” | Data coverage in gold |
| “Every store has filed complete data for D” | **Not** proven by a green run alone |

**Manual practice:** note the refresh time (and timezone) when you demo; refresh Power BI after export; keep ask-your-data closed during a refresh and reopen only after a green run.

---

## 5. Data handling

- Data in this repo demo is **synthetic** (not live customer PII from a production retailer).  
- PII **tags** mark where real identity fields would sit — see section 3.2.  
- Secrets (`MYSQL_PASSWORD`, `GEMINI_API_KEY`) stay in local `.env` — never commit.  
- Ask-your-data sends the gold schema description and the user question to **Gemini** (external API) to draft SQL; results are computed locally in DuckDB.  
- Rebuild path: MySQL seed/generators → pipeline → gold → Parquet.

---

## 6. Failure handling

| Situation | What to do |
|-----------|------------|
| Gold **tests fail** (keys, SCD, or business rules) | Do not treat export / dashboards as validated; investigate; fix; rerun |
| **Source freshness** errors | Check landing / seed timestamps; re-run extract or CI seed; do not ignore a red freshness step in CI |
| **Contract** fails on gold | Column rename/type drift — align `schema.yml` and the model SQL together |
| **Incremental** missed an expected row | Check MySQL `created_at` / watermark behaviour — see [transformation refresh section](./data-transformation.md#6-refresh-checks-failure-handling-and-incremental-limits) |
| Power BI and chat **disagree** | Compare data version (export vs live DuckDB), filters, dates, and which revenue field (inc vs ex GST) |
| Ambiguous question (“sales last month”) | Use glossary defaults or clarify — do not invent a silent definition |

---

## 7. Limitations (honest)

- Incremental fact load uses a **`created_at` cursor** — new inserts are covered; **in-place amendments** that keep an old `created_at` may not be picked up.  
- Stopping Parquet export after a failed test does **not** by itself freeze DuckDB that Streamlit reads — use the manual reopen practice above.  
- dbt tests check keys, relationships, allowed values, GST identity, return signs, and non-null cost — they do **not** prove every revenue total is economically correct.  
- Owner / PII tags and exposures improve discoverability; they do **not** enforce row-level security or deploy dashboards.  
- Read-only AI does **not** guarantee a correct business answer.  
- Demo volume is a **smaller seed** plus synthetic trading days; architecture is sized for larger mid-size retail.  
- CI freshness depends on seeding “now”; it validates the **check is wired**, not a production SLA against live stores.

---

## 8. Change log (definitions)

| Date | Change | Assets to check |
|------|--------|-----------------|
| 2026-11-19 | Governance as code: freshness, owner/PII tags, gold contracts, exposures, business-rule tests, `au_state_code` macro, CI freshness step | this page, `sources.yml`, `exposures.yml`, gold `schema.yml`, `tests/assert_*`, `macros/au_state_code.sql`, CI workflow, [data-transformation](./data-transformation.md) |
| 2026-09-17 | Added glossary, gold dictionary, governance, refresh/incremental limits; aligned dbt + ask-your-data notes | `data-understanding`, this page, `data-transformation`, `schema.yml`, `text2sql/schema.py`, data-product / README links |
