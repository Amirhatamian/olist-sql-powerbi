# Power BI build guide

Step-by-step plan for the dashboard. Total time: about 6–8 hours over a few days.
Save the finished file as `powerbi/olist_dashboard.pbix` and put screenshots in `powerbi/screenshots/`.

## 1. Load the data (Power Query)

1. **Get data → Text/CSV** → `powerbi/data/fact_orders.csv` → **Transform Data**.
2. Check the column types:
   - `purchase_date` → Date
   - `items_value`, `freight_value`, `order_value`, `delivery_days` → Decimal number
   - `n_items`, `is_late`, `review_score` → Whole number
   - everything else → Text
3. Repeat for `powerbi/data/fact_order_items.csv` (`price`, `freight_value` → Decimal number).
4. Optional: also load `results/q10_rfm_segments.csv` and `results/q6_cohort_return_90d.csv` for the Customers page.
5. **Close & Apply**.

## 2. Date table (Modeling → New table)

```DAX
Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2017, 1, 1 ), DATE ( 2018, 8, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month", FORMAT ( [Date], "mmm yyyy" ),
    "MonthStart", DATE ( YEAR ( [Date] ), MONTH ( [Date] ), 1 ),
    "MonthNumber", YEAR ( [Date] ) * 100 + MONTH ( [Date] )
)
```

- Select the table → **Mark as date table** → column `Date`.
- Select `Date[Month]` → **Sort by column** → `MonthNumber` (otherwise months sort alphabetically).

## 3. Relationships (Model view)

| From (many) | To (one) | Direction |
|---|---|---|
| `fact_orders[purchase_date]` | `Date[Date]` | Single |
| `fact_order_items[order_id]` | `fact_orders[order_id]` | Single (orders filter items) |

This is a star schema: the date filters orders, and orders filter their items.

## 4. Measures

Create an empty table called `_Measures` (Enter data → one blank column → Load) and put all measures there.

```DAX
Revenue = SUM ( fact_orders[order_value] )

Orders = COUNTROWS ( fact_orders )

Customers = DISTINCTCOUNT ( fact_orders[customer_unique_id] )

Avg Order Value = DIVIDE ( [Revenue], [Orders] )

Late % = AVERAGE ( fact_orders[is_late] )

Avg Delivery Days = AVERAGE ( fact_orders[delivery_days] )

Avg Review = AVERAGE ( fact_orders[review_score] )

Bad Review % =
DIVIDE (
    CALCULATE ( COUNTROWS ( fact_orders ), fact_orders[review_score] <= 2 ),
    CALCULATE ( COUNTROWS ( fact_orders ), NOT ISBLANK ( fact_orders[review_score] ) )
)

Revenue Prev Month = CALCULATE ( [Revenue], DATEADD ( 'Date'[Date], -1, MONTH ) )

Revenue MoM % = DIVIDE ( [Revenue] - [Revenue Prev Month], [Revenue Prev Month] )

Revenue Prev Year = CALCULATE ( [Revenue], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

Revenue YoY % = DIVIDE ( [Revenue] - [Revenue Prev Year], [Revenue Prev Year] )

Item Revenue = SUM ( fact_order_items[price] )

Category Share % =
DIVIDE (
    [Item Revenue],
    CALCULATE ( [Item Revenue], ALL ( fact_order_items[category] ) )
)

Repeat Customer % =
VAR PerCustomer =
    ADDCOLUMNS (
        VALUES ( fact_orders[customer_unique_id] ),
        "@orders", CALCULATE ( COUNTROWS ( fact_orders ) )
    )
RETURN
    DIVIDE ( COUNTROWS ( FILTER ( PerCustomer, [@orders] > 1 ) ), COUNTROWS ( PerCustomer ) )
```

Formats: Revenue and Avg Order Value → currency (R$, 0 decimals); all `%` measures → Percentage, 1 decimal; Avg Review → 2 decimals.

**Check your numbers** (whole period, no filters) against the SQL results:
Revenue ≈ R$15.37M · Orders 96,203 · Customers 93,096 · Avg Order Value ≈ R$159.78 · Late % ≈ 6.8% · Avg Review ≈ 4.16.

## 5. Pages

### Page 1 — Overview
- **Cards (top row):** Revenue, Orders, Avg Order Value, Customers, Avg Review, Late %.
- **Line chart:** `Date[Month]` on the X axis, Revenue on the Y axis. Add a text box pointing out Nov 2017 (Black Friday, +53% vs Oct).
- **Bar chart:** top 10 categories by Item Revenue (`fact_order_items[category]`, Top N filter = 10).
- **Slicers:** `Date[Month]` (between), `fact_orders[customer_state]`.

### Page 2 — Delivery & satisfaction
- **Clustered column:** `is_late` (rename values in a new column: 0 = "On time", 1 = "Late") vs Avg Review. The headline: late orders average 2.27 stars vs 4.29.
- **Bar chart:** Late % by `customer_state`, sorted descending.
- **Scatter chart:** one dot per state: Avg Delivery Days (X) vs Avg Review (Y), size = Orders.
- **Card:** Bad Review %.

### Page 3 — Customers
- **Card:** Repeat Customer % (about 3%).
- **Table or column chart:** `q6_cohort_return_90d` — return rate by cohort month.
- **Bar chart:** `q10_rfm_segments` — share of customers vs share of revenue per segment.

## 6. Design rules
- One accent colour for the main measure and greys for the rest.
- Every chart title states the finding, e.g. "Late orders get 2 stars less", not "Avg Review by is_late".
- Same position for slicers on every page; turn on **Sync slicers** for the date slicer.

## 7. Finish
1. Save `olist_dashboard.pbix` into `powerbi/`.
2. Take one screenshot per page (`overview.png`, `delivery.png`, `customers.png`) into `powerbi/screenshots/`.
3. In `README.md`, add this line under the main findings:
   `![Dashboard overview](powerbi/screenshots/overview.png)`
4. Push to GitHub.
