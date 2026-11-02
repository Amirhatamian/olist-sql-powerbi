-- 01_schema.sql
-- Tables for the Olist Brazilian e-commerce dataset (9 CSV files).
-- Run: psql -d olist -f sql/01_schema.sql

DROP SCHEMA IF EXISTS olist CASCADE;
CREATE SCHEMA olist;
SET search_path TO olist;

-- One row per customer per order. customer_unique_id identifies the real person.
CREATE TABLE customers (
    customer_id              CHAR(32) PRIMARY KEY,
    customer_unique_id       CHAR(32) NOT NULL,
    customer_zip_code_prefix CHAR(5)  NOT NULL,
    customer_city            TEXT     NOT NULL,
    customer_state           CHAR(2)  NOT NULL
);

CREATE TABLE sellers (
    seller_id              CHAR(32) PRIMARY KEY,
    seller_zip_code_prefix CHAR(5)  NOT NULL,
    seller_city            TEXT     NOT NULL,
    seller_state           CHAR(2)  NOT NULL
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT NOT NULL
);

-- Column names keep the original spelling ("lenght") so the CSV loads as is.
CREATE TABLE products (
    product_id                 CHAR(32) PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INT,
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);

CREATE TABLE orders (
    order_id                      CHAR(32)  PRIMARY KEY,
    customer_id                   CHAR(32)  NOT NULL REFERENCES customers,
    order_status                  TEXT      NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL
);

-- One row per item in an order (an order with 3 items has 3 rows).
CREATE TABLE order_items (
    order_id            CHAR(32)      NOT NULL REFERENCES orders,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL REFERENCES products,
    seller_id           CHAR(32)      NOT NULL REFERENCES sellers,
    shipping_limit_date TIMESTAMP     NOT NULL,
    price               NUMERIC(10,2) NOT NULL,
    freight_value       NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

-- An order can be paid in several parts (e.g. voucher + credit card).
CREATE TABLE order_payments (
    order_id             CHAR(32)      NOT NULL REFERENCES orders,
    payment_sequential   INT           NOT NULL,
    payment_type         TEXT          NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

-- 814 review_ids appear on more than one order, so the key is (review_id, order_id).
CREATE TABLE order_reviews (
    review_id               CHAR(32)  NOT NULL,
    order_id                CHAR(32)  NOT NULL REFERENCES orders,
    review_score            SMALLINT  NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    PRIMARY KEY (review_id, order_id)
);

-- Many rows per zip code prefix (one per address point), so no primary key.
CREATE TABLE geolocation (
    geolocation_zip_code_prefix CHAR(5)          NOT NULL,
    geolocation_lat             DOUBLE PRECISION NOT NULL,
    geolocation_lng             DOUBLE PRECISION NOT NULL,
    geolocation_city            TEXT             NOT NULL,
    geolocation_state           CHAR(2)          NOT NULL
);
