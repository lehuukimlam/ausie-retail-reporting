# Data governance

How reporting data is kept **trustworthy** for this project.

Written for a business reader. Definitions of fields and metrics live in [data-understanding.md](./data-understanding.md) (sections 5–6). This page covers **rules**, **roles**, **freshness**, and **what happens when something fails**.

| Read next | What you get |
|-----------|----------------|
| [README](../README.md) | Business context, requirements, use cases |
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
| **AI is read-only on gold** | No writes; SELECT/`main_gold` only | Implemented | `text2sql/executor.py` |
| **Definition changes are recorded** | If Revenue or Category meaning changes, update glossary, dbt descriptions, AI context, and report labels together | Manual | Git + this docs set |

---

## 3. Freshness (“as of”)

There is **no** gold column for warehouse import time (`imported_at` / `loaded_at`).

Stakeholders should treat freshness as:

1. **Last successful refresh** — when `run_incremental.py` (or full pipeline) finished with **tests passed** and Parquet exported  
2. **Latest trading date in gold** — max trading date in `fact_sales` / Date dimension  

| Claim | OK? |
|-------|-----|
| “Pipeline finished green” | Process freshness |
| “Latest sale day in the model is D” | Data coverage in gold |
| “Every store has filed complete data for D” | **Not** proven by a green run alone |

**Manual practice:** note the refresh time (and timezone) when you demo; refresh Power BI after export; keep ask-your-data closed during a refresh and reopen only after a green run.

---

## 4. Data handling

- Data in this repo demo is **synthetic** (not live customer PII from a production retailer).  
- Secrets (`MYSQL_PASSWORD`, `GEMINI_API_KEY`) stay in local `.env` — never commit.  
- Ask-your-data sends the gold schema description and the user question to **Gemini** (external API) to draft SQL; results are computed locally in DuckDB.  
- Rebuild path: MySQL seed/generators → pipeline → gold → Parquet.

---

## 5. Failure handling

| Situation | What to do |
|-----------|------------|
| Gold **tests fail** | Do not treat export / dashboards as validated; investigate; fix; rerun |
| **Incremental** missed an expected row | Check MySQL `created_at` / watermark behaviour — see [transformation refresh section](./data-transformation.md#6-refresh-checks-failure-handling-and-incremental-limits) |
| Power BI and chat **disagree** | Compare data version (export vs live DuckDB), filters, dates, and which revenue field (inc vs ex GST) |
| Ambiguous question (“sales last month”) | Use glossary defaults or clarify — do not invent a silent definition |

---

## 6. Limitations (honest)

- Incremental fact load uses a **`created_at` cursor** — new inserts are covered; **in-place amendments** that keep an old `created_at` may not be picked up.  
- Stopping Parquet export after a failed test does **not** by itself freeze DuckDB that Streamlit reads — use the manual reopen practice above.  
- dbt tests check keys/relationships/allowed values — they do **not** prove every revenue total is economically correct.  
- Read-only AI does **not** guarantee a correct business answer.  
- Demo volume is a **smaller seed** plus synthetic trading days; architecture is sized for larger mid-size retail.

---

## 7. Change log (definitions)

| Date | Change | Assets to check |
|------|--------|-----------------|
| 2026-09-17 | Added glossary, gold dictionary, governance, refresh/incremental limits; aligned dbt + ask-your-data notes | `data-understanding`, this page, `data-transformation`, `schema.yml`, `text2sql/schema.py`, data-product / README links |
