-- 05_export.sql
-- Exports two clean tables for Power BI into powerbi/data/, so the dashboard
-- can be built without a database connection. Run from the project root:
--   psql -d olist -f sql/05_export.sql

SET search_path TO olist;

-- One row per delivered order (Jan 2017 – Aug 2018).
\copy (SELECT order_id, customer_unique_id, customer_state, purchased_at::date AS purchase_date, n_items, items_value, freight_value, order_value, ROUND(delivery_days::numeric, 2) AS delivery_days, is_late::int AS is_late, review_score FROM v_orders ORDER BY purchased_at) TO 'powerbi/data/fact_orders.csv' WITH (FORMAT csv, HEADER true)

-- One row per order item, with category and seller state.
\copy (SELECT oi.order_id, oi.order_item_id, p.category, s.seller_state, oi.price, oi.freight_value FROM order_items oi JOIN v_orders o USING (order_id) JOIN v_products p USING (product_id) JOIN sellers s USING (seller_id) ORDER BY oi.order_id, oi.order_item_id) TO 'powerbi/data/fact_order_items.csv' WITH (FORMAT csv, HEADER true)
