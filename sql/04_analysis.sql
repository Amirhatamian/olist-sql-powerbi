-- 04_analysis.sql
-- Ten business questions for an online marketplace.
-- Uses the views from 03_views.sql (delivered orders, Jan 2017 – Aug 2018).
-- Run: psql -d olist -f sql/04_analysis.sql

SET search_path TO olist;

-- ---------------------------------------------------------------------------
-- Q1. How do revenue and orders grow month by month?
-- Skills: GROUP BY on a date, window function LAG for month-over-month growth.
-- ---------------------------------------------------------------------------
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)         AS orders,
           SUM(order_value) AS revenue
    FROM v_orders
    GROUP BY purchase_month
)
SELECT purchase_month,
       orders,
       ROUND(revenue, 0) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
                   / LAG(revenue) OVER (ORDER BY purchase_month), 1) AS revenue_growth_pct
FROM monthly
ORDER BY purchase_month;

-- ---------------------------------------------------------------------------
-- Q2. Which 10 product categories bring the most revenue, and what share of the total?
-- Skills: JOIN items → orders → products, SUM() OVER () for share of total, RANK.
-- Revenue here is item price only (freight is per order, not per category).
-- ---------------------------------------------------------------------------
WITH cat AS (
    SELECT p.category,
           COUNT(DISTINCT oi.order_id) AS orders,
           SUM(oi.price)               AS revenue
    FROM order_items oi
    JOIN v_orders   o USING (order_id)
    JOIN v_products p USING (product_id)
    GROUP BY p.category
)
SELECT RANK() OVER (ORDER BY revenue DESC)                 AS rank,
       category,
       orders,
       ROUND(revenue, 0)                                   AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)    AS share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
                   / SUM(revenue) OVER (), 1)              AS cumulative_share_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- Q3. Do late deliveries lead to worse reviews?
-- Skills: CASE, conditional aggregation (FILTER).
-- ---------------------------------------------------------------------------
SELECT CASE WHEN is_late THEN 'late' ELSE 'on time' END            AS delivery,
       COUNT(*)                                                    AS orders,
       ROUND(AVG(review_score), 2)                                 AS avg_review,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
                   / COUNT(review_score), 1)                       AS pct_bad_reviews_1_2
FROM v_orders
GROUP BY is_late
ORDER BY delivery;

-- ---------------------------------------------------------------------------
-- Q4. Which customer states wait longest and get the most late orders?
-- Skills: GROUP BY with HAVING, percentile (PERCENTILE_CONT).
-- ---------------------------------------------------------------------------
SELECT customer_state,
       COUNT(*)                                                         AS orders,
       ROUND(AVG(delivery_days)::numeric, 1)                            AS avg_delivery_days,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days))::numeric, 1)
                                                                        AS median_delivery_days,
       ROUND(100.0 * AVG(is_late::int), 1)                              AS pct_late,
       ROUND(100.0 * SUM(freight_value) / SUM(items_value), 1)          AS freight_pct_of_price
FROM v_orders
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;

-- ---------------------------------------------------------------------------
-- Q5. How many customers come back for a second order?
-- Skills: CTE in two steps, counting per customer, then a distribution.
-- ---------------------------------------------------------------------------
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS n_orders
    FROM v_orders
    GROUP BY customer_unique_id
)
SELECT CASE WHEN n_orders >= 3 THEN '3+' ELSE n_orders::text END AS orders_per_customer,
       COUNT(*)                                                  AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)        AS pct_customers
FROM per_customer
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------------
-- Q6. Monthly cohorts: of the customers who first bought in a month, what share
--     bought again within 3 months?
-- Skills: MIN() OVER (PARTITION BY) to find the first order, date arithmetic.
-- ---------------------------------------------------------------------------
WITH firsts AS (
    SELECT customer_unique_id,
           purchased_at,
           MIN(purchased_at) OVER (PARTITION BY customer_unique_id) AS first_purchase
    FROM v_orders
),
cohort AS (
    SELECT customer_unique_id,
           DATE_TRUNC('month', MIN(first_purchase))::date AS cohort_month,
           BOOL_OR(purchased_at >  first_purchase
               AND purchased_at <= first_purchase + INTERVAL '90 days') AS returned_90d
    FROM firsts
    GROUP BY customer_unique_id
)
SELECT cohort_month,
       COUNT(*)                                        AS new_customers,
       COUNT(*) FILTER (WHERE returned_90d)            AS returned_within_90d,
       ROUND(100.0 * AVG(returned_90d::int), 2)        AS return_rate_pct
FROM cohort
WHERE cohort_month <= '2018-05-01'   -- later cohorts have less than 90 days of data
GROUP BY cohort_month
ORDER BY cohort_month;

-- ---------------------------------------------------------------------------
-- Q7. Who are the top 3 sellers by revenue in each of the 5 biggest seller states?
-- Skills: DENSE_RANK() OVER (PARTITION BY ...), filtering on a window result.
-- ---------------------------------------------------------------------------
WITH seller_rev AS (
    SELECT s.seller_state,
           s.seller_id,
           COUNT(DISTINCT oi.order_id) AS orders,
           SUM(oi.price)               AS revenue
    FROM order_items oi
    JOIN v_orders o USING (order_id)
    JOIN sellers  s USING (seller_id)
    GROUP BY s.seller_state, s.seller_id
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY seller_state ORDER BY revenue DESC) AS rank_in_state,
           SUM(revenue) OVER (PARTITION BY seller_state)                       AS state_revenue
    FROM seller_rev
),
top_states AS (
    SELECT seller_state
    FROM seller_rev
    GROUP BY seller_state
    ORDER BY SUM(revenue) DESC
    LIMIT 5
)
SELECT r.seller_state,
       r.rank_in_state,
       LEFT(r.seller_id, 8)                              AS seller,
       r.orders,
       ROUND(r.revenue, 0)                               AS revenue,
       ROUND(100.0 * r.revenue / r.state_revenue, 1)     AS share_of_state_pct
FROM ranked r
JOIN top_states USING (seller_state)
WHERE r.rank_in_state <= 3
ORDER BY r.state_revenue DESC, r.rank_in_state;

-- ---------------------------------------------------------------------------
-- Q8. How do customers pay, and do instalments go with bigger orders?
-- Skills: aggregation on a different grain (payments), JOIN to the order view.
-- ---------------------------------------------------------------------------
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id)                                     AS orders,
       ROUND(100.0 * COUNT(DISTINCT p.order_id)
                   / (SELECT COUNT(*) FROM v_orders), 1)              AS pct_of_orders,
       ROUND(SUM(p.payment_value), 0)                                 AS amount_paid,
       ROUND(AVG(p.payment_value), 2)                                 AS avg_payment,
       ROUND(AVG(p.payment_installments), 1)                          AS avg_installments
FROM order_payments p
JOIN v_orders o USING (order_id)
WHERE p.payment_type <> 'not_defined'
GROUP BY p.payment_type
ORDER BY orders DESC;

-- ---------------------------------------------------------------------------
-- Q9. Which categories grew fastest from Jan–Aug 2017 to Jan–Aug 2018?
-- Skills: conditional aggregation to pivot two periods into columns.
-- ---------------------------------------------------------------------------
WITH by_year AS (
    SELECT p.category,
           SUM(oi.price) FILTER (WHERE o.purchased_at <  '2017-09-01') AS rev_2017,
           SUM(oi.price) FILTER (WHERE o.purchased_at >= '2018-01-01') AS rev_2018
    FROM order_items oi
    JOIN v_orders   o USING (order_id)
    JOIN v_products p USING (product_id)
    GROUP BY p.category
)
SELECT category,
       ROUND(rev_2017, 0)                                  AS revenue_jan_aug_2017,
       ROUND(rev_2018, 0)                                  AS revenue_jan_aug_2018,
       ROUND(100.0 * (rev_2018 - rev_2017) / rev_2017, 1)  AS growth_pct
FROM by_year
WHERE rev_2017 >= 50000           -- only categories with real volume in both years
ORDER BY growth_pct DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- Q10. Customer segments (RFM): who are the best customers?
-- Skills: NTILE for scoring, multiple CTEs, CASE to name segments.
-- Recency is measured from the last day of the data (2018-08-31).
-- ---------------------------------------------------------------------------
WITH rfm AS (
    SELECT customer_unique_id,
           DATE '2018-08-31' - MAX(purchased_at)::date AS recency_days,
           COUNT(*)                                     AS frequency,
           SUM(order_value)                             AS monetary
    FROM v_orders
    GROUP BY customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,   -- 4 = most recent
           NTILE(4) OVER (ORDER BY monetary)          AS m_score    -- 4 = spends most
    FROM rfm
),
segments AS (
    SELECT *,
           CASE
               WHEN frequency > 1 AND r_score >= 3 THEN '1. Loyal (repeat, recent)'
               WHEN frequency > 1                  THEN '2. Repeat, inactive'
               WHEN r_score >= 3 AND m_score = 4   THEN '3. New high spenders'
               WHEN r_score >= 3                   THEN '4. New, lower spend'
               WHEN m_score = 4                    THEN '5. Lapsed high spenders'
               ELSE                                     '6. Lapsed, lower spend'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                             AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_customers,
       ROUND(AVG(recency_days), 0)                          AS avg_recency_days,
       ROUND(AVG(monetary), 2)                              AS avg_spend,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue
FROM segments
GROUP BY segment
ORDER BY segment;
