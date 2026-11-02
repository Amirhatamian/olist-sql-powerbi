-- 03_views.sql
-- Reusable views. Definitions used in the whole project:
--   * Revenue = item price + freight, for DELIVERED orders only.
--   * Late = delivered to the customer after the estimated delivery date.
--   * Analysis period = Jan 2017 – Aug 2018. The months before and after have
--     very few orders (the platform was starting, and the data export was cut off).

SET search_path TO olist;

-- English category names, with a fallback for products that have no category.
CREATE OR REPLACE VIEW v_products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown') AS category
FROM products p
LEFT JOIN category_translation t USING (product_category_name);

-- One row per delivered order, with its value, delivery times and review.
CREATE OR REPLACE VIEW v_orders AS
WITH items AS (
    SELECT order_id,
           COUNT(*)           AS n_items,
           SUM(price)         AS items_value,
           SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
),
reviews AS (
    -- A few orders have more than one review: keep the latest one.
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp                              AS purchased_at,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date   AS purchase_month,
    i.n_items,
    i.items_value,
    i.freight_value,
    i.items_value + i.freight_value                         AS order_value,
    EXTRACT(EPOCH FROM o.order_delivered_customer_date - o.order_purchase_timestamp) / 86400.0
                                                            AS delivery_days,
    (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
                                                            AS is_late,
    r.review_score
FROM orders o
JOIN customers c USING (customer_id)
JOIN items     i USING (order_id)
LEFT JOIN reviews r USING (order_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
