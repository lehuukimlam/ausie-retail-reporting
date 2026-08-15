# ausie-retail-reporting

Automation of end-of-day sales reporting for Australian retailers.

## Business context

Many Australian retailers run multiple stores but do not have a data engineer. End-of-day reporting is still mostly manual: closing staff take a photo of the till/POS close report, and owners or accountants later copy numbers into spreadsheets and check cash variance by hand.

**Who it is for**

- One retailer with multiple stores (first use case: about 5 stores)
- Primary consumers: **owner** and **accountant**
- Submitters: **closing staff** send the end-of-day photo

**What an end-of-day report covers**

Typical Australian retail close-out fields:

- Sales / revenue
- Cash (POS expected vs actual counted)
- Categories
- Staff
- Refunds

Input is normally a **photo**. Report layout is expected to be the **same across stores**.

**Cash variance**

- Compare POS expected cash with actual cash
- Flag as a problem when the difference is **over A$10**
- Goal: immediate cross-check so inefficiency or errors are visible the same day

**Time scope (v1)**

- Same-day view across stores (week/month rollups later)

## Why a data solution is required

- Inputs are photos, not structured data
- The same process repeats every day across multiple stores
- Manual copy/paste and cash checks do not scale and are easy to get wrong
- Owners and accountants need one trusted view, not a pile of store photos

This product turns multi-store end-of-day photos into trusted same-day numbers and variance flags — without hiring a data team.

## Definition of done (v1 requirements)

### Must have

1. Closing staff can submit an EOD **photo** tagged to a **store**
2. Core fields are captured: **sales, cash (expected + actual), categories, staff, refunds**
3. About **5 stores** appear in one **same-day** view for owner/accountant
4. **Cash variance** is calculated; differences **over A$10** are clearly flagged
5. Owner/accountant can see same-day **sales/revenue by store** and by **category** (SKU/product-level later)
6. A human can spot-check that dashboard numbers match the photo closely enough to trust

### Nice later (not v1)

- Product/SKU-level revenue
- Week/month accountant packs
- Multi-retailer / SaaS for many brands
- Full automation with zero human review

### Out of scope for now

- Replacing the POS
- Payroll, rostering, inventory purchasing
- Forecasting or AI insights beyond extraction + variance

### Done when

For one trading day with ~5 stores: photos in → same-day dashboard out → variances over A$10 visible → owner/accountant does not need to retype the reports.

## Next

Data architecture (intake → extract → store → dashboard) will be defined after this context and DoD stay stable.
