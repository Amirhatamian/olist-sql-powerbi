# E-commerce Sales Analysis with SQL and Power BI

Analysis of about 100,000 orders from Olist, a Brazilian online marketplace (2016–2018). I loaded the raw data into PostgreSQL, answered ten business questions in SQL, and built a Power BI dashboard on top.

**Main findings (delivered orders, Jan 2017 – Aug 2018)**

- **Late deliveries drive bad reviews.** Late orders average **2.27 stars** vs **4.29** for on-time orders, and 62% of late orders get a 1–2 star review (9% when on time).
- **Almost nobody comes back.** **97%** of customers order only once; only about 2% of each month's new customers buy again within 90 days.
- **Revenue grew fast, then flattened.** Monthly revenue went from R$127k (Jan 2017) to about R$1.1M in early 2018 and stayed there. Black Friday (Nov 2017) was the peak month, +53% vs October.
- **The north-east waits longest.** Customers in Maranhão (MA) waited 21.5 days on average and 17.5% of orders arrived late, vs 8.7 days and 4.5% in São Paulo.
- **Ten categories make 62% of product revenue**, led by health & beauty, watches & gifts, and bed & bath.

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, CC BY-NC-SA 4.0): 9 tables, 99,441 orders, 112,650 order items, 99,224 reviews, 3,095 sellers.

```
customers ─┐
           orders ─┬─ order_items ─┬─ products ── category_translation
                   │               └─ sellers
                   ├─ order_payments
                   └─ order_reviews
```

**Definitions used everywhere**
- Revenue = item price + freight, delivered orders only.
- Late = delivered after the estimated delivery date.
- Period = Jan 2017 – Aug 2018 (the months before and after have very few orders).

**Data issues found and handled**
- 814 review IDs appear on more than one order → primary key is (review_id, order_id); when an order has several reviews, the latest one is used.
- 2 product categories had no English name → added by hand.
- The customer table has one ID per order; the real person is `customer_unique_id`, which is what the customer analysis uses.
- The geolocation table has many rows per zip code → no primary key; not needed for the questions below.

## Business questions

All queries are in [`sql/04_analysis.sql`](sql/04_analysis.sql); results are in [`results/`](results/).

| # | Question | SQL used | Answer |
|---|---|---|---|
| 1 | How do revenue and orders grow month by month? | `LAG` window function | R$127k → ~R$1.1M per month; peak Nov 2017 |
| 2 | Which categories bring the most revenue? | `JOIN`s, `SUM() OVER ()`, `RANK` | Top 10 = 62.5% of product revenue |
| 3 | Do late deliveries lead to worse reviews? | `CASE`, `FILTER` | 2.27 vs 4.29 stars |
| 4 | Which states wait longest? | `HAVING`, `PERCENTILE_CONT` | MA, CE, BA, RJ: 12–18% late |
| 5 | How many customers order again? | CTEs | 3.0% order more than once |
| 6 | What share of new customers return within 90 days? | `MIN() OVER (PARTITION BY)`, cohorts | 1.5–3.1% per monthly cohort |
| 7 | Who are the top 3 sellers in each big state? | `DENSE_RANK() OVER (PARTITION BY)` | In RJ the top seller has 14.8% of state revenue; in SP only 2.7% |
| 8 | How do customers pay? | joins across grains | Credit card 77% of orders, avg 3.5 instalments; boleto 20% |
| 9 | Which categories grew fastest, 2017 vs 2018? | conditional aggregation | Baby +269%, watches & gifts +242%, health & beauty +210% |
| 10 | Who are the best customers (RFM)? | `NTILE`, multiple CTEs | High spenders (23% of customers) bring 55% of revenue |

## What I would recommend

1. **Fix delivery estimates in the north-east first.** Late orders cost about 2 stars each; MA, CE, BA and RJ have 2–4× the late rate of São Paulo.
2. **Work on the second order.** With 97% one-time buyers, a follow-up offer after the first delivery has more upside than winning new customers.
3. **Plan stock and logistics for Black Friday**, the biggest month of the year.

## Dashboard

Built in Power BI from two clean tables exported by [`sql/05_export.sql`](sql/05_export.sql): a star schema with a date table, `fact_orders` and `fact_order_items`. Pages: Overview · Delivery & satisfaction · Customers. Build steps and all DAX measures: [`powerbi/POWERBI_GUIDE.md`](powerbi/POWERBI_GUIDE.md).

## How to run

Requires PostgreSQL 13+.

```bash
git clone https://github.com/Amirhatamian/olist-sql-powerbi.git
cd olist-sql-powerbi
# Download the 9 CSV files from Kaggle into data/
createdb olist
psql -d olist -f sql/01_schema.sql    # tables, keys, constraints
psql -d olist -f sql/02_load.sql      # load CSVs, row-count check
psql -d olist -f sql/03_views.sql     # clean order-level views
psql -d olist -f sql/04_analysis.sql  # the ten questions
psql -d olist -f sql/05_export.sql    # tables for Power BI
```

## Files

| Path | Content |
|---|---|
| `sql/01_schema.sql` | Tables with primary and foreign keys |
| `sql/02_load.sql` | CSV loading and row-count check |
| `sql/03_views.sql` | `v_orders` (one row per delivered order) and `v_products` |
| `sql/04_analysis.sql` | The ten business questions |
| `sql/05_export.sql` | Export of clean tables for Power BI |
| `results/` | Result of each question as CSV |
| `powerbi/` | Dashboard file, data for it, build guide, screenshots |

## Tools

PostgreSQL 16 · SQL (CTEs, window functions, joins, conditional aggregation) · Power BI (Power Query, DAX, data modelling)
