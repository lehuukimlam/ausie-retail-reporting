# ausie-retail-reporting

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

Technical detail lives in the pipeline folders. The three design guides below are written in **business-friendly language** (same role as stakeholder Word packs; kept as Markdown in Git so they stay with the project on GitHub):

| Design document | What a business reader gets |
|-----------------|-----------------------------|
| [docs/data-understanding.md](docs/data-understanding.md) | What the raw retail data looks like, why it is messy, and the target reporting model (fact + dimensions) |
| [docs/data-architecture-stack.md](docs/data-architecture-stack.md) | How the end-to-end solution is put together, in plain stages |
| [docs/data-transformation.md](docs/data-transformation.md) | What we clean and why, how gold reporting is built, and how quality is checked |

---

## Business context

Australian specialty retailers often sell both **in store** and **online**. They have many locations, thousands of products, staff on registers, discounts, and returns — but they rarely have a data engineer. Numbers live in POS, product master (ERP), and sometimes a customer/loyalty system, and they do not line up cleanly.

This project simulates **one mid-size Australian omnichannel specialty retailer** so a full data solution can be built and demonstrated without a live retailer feed.

### Who it is for

- One retailer, many locations
- Primary consumers of the data: **owner** and **accountant** (revenue, margin, store vs online, product, staff)
- Goal: a **credible synthetic dataset + trusted reporting model**, not a photo-upload app

### Retailer shape we simulate

- About **50 stores** across NSW, VIC, QLD, WA, SA
- Plus an **online** channel (Shopify-style)
- About **8,000 products (SKUs)**
- About **24 months** of sales history
- Australian retail calendar effects (summer peak Dec–Jan, Boxing Day, EOFY, Click Frenzy, Black Friday, back-to-school)

The architecture is built for that scale. The repository ships a working MySQL seed and a full pipeline run so the model and reports can be used today; volume can be expanded without redesigning the solution.

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
| R1 | Represent one Aussie omnichannel retailer (stores + online), sized toward ~50 stores, ~8k SKUs, ~24 months | Matches the real mid-size specialty shape we simulate |
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
| **UC1 — Trusted daily refresh** | Data / ops | Run one pipeline that copies shop systems data, rebuilds cleaned + reporting tables, fails if gold checks fail, and refreshes export files | R2, R3, R4, R6 |
| **UC2 — Owner performance view** | Owner | Open Power BI on gold: revenue by store, channel, product, period; compare store vs online | R4, R5, R7 |
| **UC3 — Accountant / finance view** | Accountant | Same gold model: revenue, cost, discount, returns, GST-related fields, consistent dims | R3, R4, R7 |
| **UC4 — Ad-hoc ask-your-data** | Analyst (optional for owner) | Ask plain-English questions in the Streamlit app; answers come from **gold only**, same numbers as Power BI, read-only | R4, R8 |
| **UC5 — Readable design pack** | Business reader / reviewer | Read data understanding, architecture, and transformation guides without needing SQL | R9 |

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
4. Refresh the warehouse and Power BI files:

   ```bat
   python orchestration\run_pipeline.py
   ```

5. Open Power BI against `powerbi/export/*.parquet`.
6. Optional — ask gold questions in the browser:

   ```bat
   streamlit run text2sql\app.py
   ```

---

## Repository layout

| Path | Role |
|------|------|
| `mysql/` | Shop-system DDL and seed |
| `ingestion/` | DLT MySQL → DuckDB |
| `dbt_model/` | Bronze / silver / gold models and tests |
| `orchestration/` | End-to-end pipeline runner |
| `powerbi/` | Parquet export for Power BI |
| `text2sql/` | Gold-only text-to-SQL (CLI + Streamlit) |
| `docs/` | Business-friendly understanding, architecture, and transformation guides |
