# ausie-retail-reporting

Reporting data platform for a **synthetic mid-size Australian omnichannel specialty retailer**.

The project turns messy store and online sales extracts into a trusted reporting model that owners and accountants can use for revenue, margin, channel, product, and staff views — without replacing POS, ERP, or Shopify.

---

## Business context

Australian specialty retailers commonly sell **in store and online**. They operate many locations, thousands of products, register staff, discounts, and returns. They rarely have a dedicated data engineer. Numbers sit in POS, a product master (ERP), and sometimes a customer or loyalty system — and those systems do not line up cleanly.

This repository simulates **one retailer** so a complete data solution can be designed, built, and demonstrated without a live retailer feed.

### Audience

| Role | What they need from the data |
|------|------------------------------|
| **Owner** | Store vs online performance, product mix, staff contribution |
| **Accountant** | Reliable revenue, cost, discount, returns, and GST-ready figures |

### Retailer shape (design target)

| Attribute | Scale |
|-----------|--------|
| Stores | ~50 across NSW, VIC, QLD, WA, SA |
| Online | Shopify-style web channel |
| Catalogue | ~8,000 SKUs |
| History | ~24 months of sales |
| Calendar | Australian retail peaks (summer Dec–Jan, Boxing Day, EOFY, Click Frenzy, Black Friday, back-to-school) |

The pipeline is built for that shape. The repo includes a working MySQL seed and end-to-end run so the model and reports can be exercised today; seed volume can be expanded without changing the architecture.

### What “sales” means

Sales are modelled as **transaction line items**, not daily photo totals:

- Revenue (inc. and ex. GST where relevant)
- Product cost and discount
- Product, staff, location, date, and customer keys

Reference (dimension) data mirrors standard retail operations:

- **Location** — store vs online, state, channel
- **Product** — SKU, category hierarchy, cost and price
- **Staff** — identity, role, and related attributes over time
- **Date** — calendar for reporting periods
- **Customer** — loyalty where available (guest checkout allowed)

### Why the raw data is messy on purpose

Real retail feeds are dirty. Source-style data in this project includes problems such as:

- Duplicate transactions when POS retries a send
- GST-inclusive POS prices vs ex-GST product master
- Local timestamps across timezones (east coast vs Perth) without a clear offset
- Late-arriving store files
- Guest checkout (no customer id) and loyalty duplicates (same email, different casing)
- Returns as negative lines linked to an original sale (sometimes in another period)
- Product categories changing mid-year
- Inconsistent state names/codes and postcode mismatches

Cleaning and organising that mess is the purpose of the data solution.

### Why a data platform is required

- POS, product master, CRM, and online do not share one clean truth
- Store and online must be comparable in one place
- History, returns, discounts, and product changes break simple spreadsheets
- Owners and accountants need trusted dimensions and transaction facts, not raw exports

---

## Solution delivered

End-to-end path from operational-style tables to owner/accountant reporting:

| Stage | Technology | What it does |
|-------|------------|--------------|
| Operational source | **MySQL** | Transactional retail tables (POS sales, product, staff, store, CRM, online orders) |
| Ingestion | **DLT** | Copies MySQL into the DuckDB warehouse |
| Warehouse | **DuckDB** | Local analytical store for bronze, silver, and gold |
| Transform | **dbt** | Bronze (raw) → silver (cleaned) → gold (star schema) |
| Orchestration | **Python** (`orchestration/run_pipeline.py`) | Ingest → dbt run → gold tests → Parquet export |
| Dashboard | **Power BI** | Reads gold Parquet exports |
| Ad-hoc questions | **Text-to-SQL** (Gemini + Streamlit) | Natural-language questions against **gold only**, read-only |

```text
MySQL (OLTP)
    → DLT ingest
    → DuckDB warehouse
        → dbt bronze (raw as landed)
        → dbt silver (cleaned)
        → dbt gold (dims + fact_sales)
            → Parquet → Power BI
            → Text-to-SQL (Streamlit)
```

### Reporting model (gold)

- **Fact:** `fact_sales` — revenue, cost, discount, quantities, channel, foreign keys  
- **Dimensions:** location, product, staff, date, customer  

Quality checks on gold run as part of the pipeline (`dbt test`). Text-to-SQL and Power BI both read the same gold tables, so figures stay aligned.

---

## Scope

### In scope

1. Synthetic Aussie retail data for the scenario above (stores + online; architecture sized for ~50 stores, ~8k SKUs, ~24 months)
2. Raw (bronze) layer that preserves source-style mess
3. Cleaned (silver) layer for dedupe, GST, time, late data, customer matching, returns, category history, and location codes
4. Gold star schema suitable for owner/accountant reporting
5. Automated daily-style refresh (ingest, transform, test, export)
6. Power BI on exported gold Parquet
7. Read-only natural-language query on gold (local Streamlit app)

### Out of scope

- Replacing POS, ERP, or Shopify
- Payroll, rostering, or inventory purchasing systems
- Multi-retailer SaaS productisation
- Forecasting as a primary deliverable
- Hosted 24/7 public web deployment (text-to-SQL runs locally while the machine is on)

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

## Documentation

| Document | Contents |
|----------|----------|
| [docs/data-understanding.md](docs/data-understanding.md) | Source domains, schemas, transform intent, gold ERD |
| [docs/data-architecture-stack.md](docs/data-architecture-stack.md) | Stack components and responsibilities |
| [docs/data-transformation.md](docs/data-transformation.md) | Cleaning and gold model in business terms |

---

## Repository layout

| Path | Role |
|------|------|
| `mysql/` | OLTP DDL and seed |
| `ingestion/` | DLT MySQL → DuckDB |
| `dbt_model/` | Bronze / silver / gold models and tests |
| `orchestration/` | End-to-end pipeline runner |
| `powerbi/` | Parquet export for Power BI |
| `text2sql/` | Gold-only text-to-SQL (CLI + Streamlit) |
| `docs/` | Business and technical design notes |
