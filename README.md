# ausie-retail-reporting

Synthetic Australian retail sales data project: build a realistic multi-store dataset, clean it, and model it for reporting (owner / accountant style views).

## Business context

Australian specialty retailers often sell both **in store** and **online**. They have many locations, thousands of products, staff on registers, discounts, and returns — but they rarely have a data engineer. Numbers live in POS, product master (ERP), and sometimes a customer/loyalty system, and they do not line up cleanly.

This project simulates **one mid-size Australian omnichannel specialty retailer** so we can practice a real data solution without needing a live retailer feed.

**Who it is for (demo / portfolio scenario)**

- One retailer, many locations
- Consumers of the data: **owner** and **accountant** (revenue, margin, store vs online, product, staff)
- Not a live photo-upload product anymore — first goal is a **credible synthetic dataset + data model**

**Business shape we simulate**

- About **50 stores** across NSW, VIC, QLD, WA, SA
- Plus an **online** channel (Shopify-style)
- About **8,000 products (SKUs)**
- About **24 months** of sales history
- Australian retail calendar effects (e.g. summer peak Dec–Jan, Boxing Day, EOFY, Click Frenzy, Black Friday, back-to-school)

**What “sales” means here**

We model sales as **transactions** (line items), not only a daily photo total:

- Revenue
- Product cost
- Discount
- Product, staff, location (and related IDs)

Around that we keep **dimension**-style reference data that mirrors basic Aussie retail:

- **Staff** — name and related info (e.g. role, rating)
- **Location** — store vs online, state, etc.
- **Product** — SKU, category hierarchy, costs/prices
- Other basics as needed (date, customer/loyalty later)

**Why the raw data is messy on purpose**

Real retail feeds are dirty. Our synthetic data should include problems such as:

- Duplicate transactions when POS retries a send
- GST-inclusive POS prices vs ex-GST product master
- Different timezones (east coast vs Perth) with local times and no clear offset
- Some store files arriving late (days later)
- Guest checkout with no customer id; loyalty duplicates (same email, different casing)
- Returns as negative lines linked to an original sale (sometimes in another period)
- Product categories changing mid-year
- Inconsistent state names/codes and postcode mismatches

Cleaning and organising that mess is the point of the data solution.

## Why a data solution is required

- Multiple systems (POS, product master, CRM/online) do not share one clean truth
- Store + online must be comparable in one place
- History, returns, discounts, and product changes break simple spreadsheets
- Owners/accountants need trusted dims + transaction facts, not raw exports

## Definition of done (current scope)

### Must have

1. Synthetic data for the retailer scenario above (stores + online, ~8k SKUs, ~24 months)
2. Raw layer that keeps the messy source-style data
3. Cleaned layer that fixes the deliberate problems (dedupe, GST, time, late data, customer matching, returns, category history, location codes)
4. Reporting model with:
   - a **fact** of sales transactions (revenue, cost, discount, quantities, foreign keys)
   - **dimensions** for staff, location, product (and date at minimum)
5. Enough structure that an owner/accountant style dashboard *could* sit on top later

### Nice later

- Live photo / EOD intake for store close
- Cash variance checks (e.g. flag over A$10)
- Full multi-retailer SaaS
- Week/month accountant packs as polished products

### Out of scope for now

- Replacing POS / ERP / Shopify
- Payroll, rostering, inventory purchasing systems
- Fancy forecasting as the main goal

### Done when

We can generate messy Aussie retail-like data, clean it into a clear transaction fact + retail dimensions, and explain how owner/accountant reporting would read from that model.

## Next

Detail the data architecture (raw → cleaned → reporting tables) once this business context stays stable.
