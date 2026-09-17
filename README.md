# ausie-retail-reporting

End-to-end Aussie retail medallion pipeline with trusted gold, Power BI for owner/accountant, read-only ask-your-data, and incremental sync for new trading days — demonstrated on synthetic data.

Reporting data platform for a **synthetic mid-size Australian omnichannel specialty retailer**.

The project turns messy store and online sales extracts into a trusted reporting model that **owners** and **accountants** can use for revenue, margin, channel, product, and staff views — without replacing POS, ERP, or Shopify.

---

## Note for business readers

This README is written for a **business reader** first (owner, accountant, or stakeholder), not only for engineers.

You should be able to answer:

- Who is this for, and what problem does it solve?
- What does “good” reporting look like for this retailer?
- What did we require after studying that context?
- Which business use cases are delivered, and how do they meet those requirements?
- Where are the plain-language design documents?

Technical detail lives in the pipeline folders. Design guides are written in **business-friendly language** and link to each other. Suggested reading order:

1. This README (context → requirements → use cases)  
2. [docs/data-understanding.md](docs/data-understanding.md) — data shapes, glossary, gold dictionary  
3. [docs/data-architecture-stack.md](docs/data-architecture-stack.md) — how the stages fit  
4. [docs/data-transformation.md](docs/data-transformation.md) — cleaning, tests, refresh limits  
5. [docs/data-governance.md](docs/data-governance.md) — trust rules, freshness, failure handling  
6. [docs/data-product.md](docs/data-product.md) — what owners/accountants open (with screenshots)

| Design document | What a business reader gets |
|-----------------|-----------------------------|
| [docs/data-understanding.md](docs/data-understanding.md) | Raw shapes, gold ERD, **business glossary** and **gold data dictionary** |
| [docs/data-architecture-stack.md](docs/data-architecture-stack.md) | How the end-to-end solution is put together, in plain stages |
| [docs/data-transformation.md](docs/data-transformation.md) | Cleaning, gold tests, incremental refresh limits |
| [docs/data-governance.md](docs/data-governance.md) | How reporting stays trustworthy (rules, freshness, failure handling) |
| [docs/data-product.md](docs/data-product.md) | What stakeholders open (Power BI + ask-your-data), lined to use cases and requirements |

---

## Business context

Australian specialty retailers often sell both **in store** and **online**. They have many locations, thousands of products, staff on registers, discounts, and returns — but they rarely have a data engineer. Numbers live in POS, product master (ERP), and sometimes a customer/loyalty system, and they do not line up cleanly.

This project simulates **one mid-size Australian omnichannel specialty retailer** so a full data solution can be built and demonstrated without a live retailer feed.

### Who it is for

- One retailer, many locations
- Primary consumers of the data: **owner** and **accountant** (revenue, margin, store vs online, product, staff)
- Goal: a **credible synthetic dataset + trusted reporting model**, not a photo-upload app

### Retailer shape we simulate

**Design target** (architecture and requirements are sized for this):

- About **50 stores** across NSW, VIC, QLD, WA, SA
- Plus an **online** channel (Shopify-style)
- About **8,000 products (SKUs)**
- About **24 months** of sales history
- Australian retail calendar effects (summer peak Dec–Jan, Boxing Day, EOFY, Click Frenzy, Black Friday, back-to-school)

**What ships in the repo today:** a smaller MySQL seed (multi-store + online + products/staff/customers) plus optional **synthetic trading-day** inserts (e.g. 3-day spans) to practise **incremental sync**. Volume can grow without redesigning the pipeline.

### What “sales” means here

We model sales as **transactions** (line items), not only a daily total:

- Revenue
- Product cost
- Discount
- Product, staff, location (and related IDs)

Around that we keep **dimension**-style reference data that mirrors basic Aussie retail:

- **Staff** — name and related info (e.g. role)
- **Location** — store vs online, state, channel
- **Product** — SKU, category hierarchy, costs/prices
- **Date** and **customer / loyalty** where available (guest checkout allowed)

### Why the raw data is messy on purpose

Real retail feeds are dirty. Source-style data includes problems such as:

- Duplicate transactions when POS retries a send
- GST-inclusive POS prices vs ex-GST product master
- Different timezones (east coast vs Perth) with local times and no clear offset
- Some store files arriving late (days later)
- Guest checkout with no customer id; loyalty duplicates (same email, different casing)
- Returns as negative lines linked to an original sale (sometimes in another period)
- Product categories changing mid-year
- Inconsistent state names/codes and postcode mismatches

Cleaning and organising that mess is the point of the data solution.

### Why a data solution is required

- Multiple systems (POS, product master, CRM/online) do not share one clean truth
- Store + online must be comparable in one place
- History, returns, discounts, and product changes break simple spreadsheets
- Owners/accountants need trusted dimensions + transaction facts, not raw exports

---

## Requirements (from the business context)

After examining the business context above, the project is required to deliver the following.

| # | Requirement | Why it matters |
|---|-------------|----------------|
| R1 | Represent one Aussie omnichannel retailer (stores + online); architecture sized for ~50 stores / ~8k SKUs / ~24 months, demonstrated on a smaller seed + incremental trading days | Matches the mid-size specialty shape without claiming full volume in the demo seed |
| R2 | Keep a **raw** layer that preserves messy source-style data | Audit trail; mirrors how POS / ERP / CRM / online actually land |
| R3 | Provide a **cleaned** layer (dedupe, GST, timezones, late data, customer matching, returns, category history, location codes) | Spreadsheets fail on these; reporting cannot |
| R4 | Publish a **reporting model**: sales **fact** (revenue, cost, discount, qty, keys) + **dimensions** (staff, location, product, date; customer where known) | Owner/accountant views need facts and dims, not exports |
| R5 | Make store and online **comparable in one place** | Channel and location decisions need one truth |
| R6 | Run a **repeatable refresh** (ingest → transform → quality checks → export) | Trust requires a controlled daily-style process |
| R7 | Serve an **owner/accountant dashboard** on the reporting model | Stakeholders consume visuals, not SQL |
| R8 | Support **ad-hoc questions** on the same reporting numbers (read-only) | Analysts explore without breaking the dashboard truth |
| R9 | Document understanding, architecture, and transformation in **business-friendly** guides | Stakeholders can read the design without reading code |

### Out of scope (not requirements)

- Replacing POS, ERP, or Shopify
- Payroll, rostering, or inventory purchasing systems
- Forecasting as the main goal
- Multi-retailer SaaS productisation
- Hosted 24/7 public website (local tools run while the machine is on)

---

## Business use cases (how requirements are met)

These use cases are the stakeholder-facing outcomes of the requirements above.

| Use case | Who | What they do | Requirements met |
|----------|-----|--------------|------------------|
| **UC1 — Trusted daily refresh** | Data / ops | Run incremental sync when new shop data arrives: merge into DuckDB, rebuild gold, fail if checks fail, refresh Parquet | R2, R3, R4, R6 |
| **UC2 — Owner performance view** | Owner | Open Power BI on gold: revenue by store, channel, product, period; compare store vs online | R4, R5, R7 |
| **UC3 — Accountant / finance view** | Accountant | Same gold model: revenue, cost, discount, returns, GST-related fields, consistent dims | R3, R4, R7 |
| **UC4 — Ad-hoc ask-your-data** | Analyst (optional for owner) | Ask plain-English questions in the Streamlit app; answers come from **gold only**, same numbers as Power BI, read-only | R4, R8 |
| **UC5 — Readable design pack** | Business reader / reviewer | Read understanding (incl. glossary), architecture, transformation, governance, and data-product guides without needing SQL | R9 |

---

## Solution overview

| Stage | Technology | Business meaning |
|-------|------------|------------------|
| Shop systems (source) | **MySQL** | Synthetic POS, product, staff, store, CRM, online orders |
| Land data | **DLT** | Copy into the warehouse without changing meaning yet |
| Warehouse | **DuckDB** | One analytical store for raw → cleaned → reporting |
| Transform | **dbt** | Bronze (raw) → silver (cleaned) → gold (reporting star) |
| Orchestration | **Python** (`orchestration/run_pipeline.py`) | One run for ingest, rebuild, test, Power BI export |
| Dashboard | **Power BI** | Owner/accountant visuals on gold Parquet |
| Ask your data | **Text-to-SQL** (Gemini + Streamlit) | Natural-language questions on gold only |

```text
MySQL (shop systems)
    → DLT
    → DuckDB
        → bronze (raw)
        → silver (cleaned)
        → gold (dims + fact_sales)
            → Parquet → Power BI   (UC2, UC3)
            → Text-to-SQL           (UC4)
```

**Gold reporting model**

- **Fact:** `fact_sales` — revenue, cost, discount, quantities, channel, keys  
- **Dimensions:** location, product, staff, date, customer  

Power BI and text-to-SQL both read **gold**, so figures stay aligned.

---

## How to run (summary)

1. Configure local `.env` from `.env.example` (MySQL, DuckDB path, optional Gemini key for text-to-SQL).
2. Create and seed MySQL (`mysql/ddl.sql`, `mysql/seed.sql`).
3. Install Python deps (`requirements.txt`) and activate the project venv.
4. First-time full load (or rebuild):

   ```bat
   python orchestration\run_pipeline.py
   ```

5. When new trading data arrives — generate a short span (e.g. 3 days) then **incremental sync** only:

   ```bat
   python synthetic\generate_trading_days.py --days 3
   python orchestration\run_incremental.py
   ```

6. Open Power BI against `powerbi/export/*.parquet`.
7. Optional — ask gold questions in the browser:

   ```bat
   streamlit run text2sql\app.py
   ```

---

## Repository layout

| Path | Role |
|------|------|
| `mysql/` | Shop-system DDL and seed |
| `synthetic/` | Extra trading-day generators for incremental demos |
| `ingestion/` | DLT MySQL → DuckDB (replace or incremental) |
| `dbt_model/` | Bronze / silver / gold models and tests |
| `orchestration/` | Full and incremental pipeline runners |
| `powerbi/` | Parquet export for Power BI |
| `text2sql/` | Gold-only text-to-SQL (CLI + Streamlit) |
| `docs/` | Business-friendly understanding, architecture, transformation, governance, and data-product guides |
