-- Star schema: dim_date / dim_customer / dim_product / dim_seller around
-- one fact table, fact_order_items.
--
-- Grain decision (worth stating explicitly, since this is the kind of
-- judgment call real data modeling involves): fact_order_items is at the
-- ORDER ITEM level — one row per product within an order. Payment and
-- review data in the source are at the ORDER level instead (one review,
-- and possibly several payment installments, per order, not per item).
-- To fit them into an item-grain fact table, payments are summed per
-- order and attached to every item in that order, and the order's single
-- review score is likewise repeated across its items. This means
-- summing `payment_value` across fact_order_items double-counts orders
-- with more than one item — see the README for which queries that
-- affects and how they work around it.

DROP SCHEMA IF EXISTS warehouse CASCADE;
CREATE SCHEMA warehouse;

CREATE TABLE warehouse.dim_date (
    date_key     DATE PRIMARY KEY,
    year         INT NOT NULL,
    quarter      INT NOT NULL,
    month        INT NOT NULL,
    month_name   TEXT NOT NULL,
    day          INT NOT NULL,
    day_of_week  INT NOT NULL,   -- ISO: 1=Monday .. 7=Sunday
    day_name     TEXT NOT NULL,
    is_weekend   BOOLEAN NOT NULL
);

CREATE TABLE warehouse.dim_customer (
    customer_key        SERIAL PRIMARY KEY,
    customer_id         TEXT UNIQUE NOT NULL,  -- Olist's per-ORDER id
    customer_unique_id  TEXT NOT NULL,         -- Olist's per-PERSON id — use this to count real distinct customers
    city                TEXT,
    state               TEXT
);

CREATE TABLE warehouse.dim_product (
    product_key       SERIAL PRIMARY KEY,
    product_id        TEXT UNIQUE NOT NULL,
    category_english  TEXT,
    weight_g          NUMERIC,
    length_cm         NUMERIC,
    height_cm         NUMERIC,
    width_cm          NUMERIC
);

CREATE TABLE warehouse.dim_seller (
    seller_key  SERIAL PRIMARY KEY,
    seller_id   TEXT UNIQUE NOT NULL,
    city        TEXT,
    state       TEXT
);

CREATE TABLE warehouse.fact_order_items (
    fact_key       SERIAL PRIMARY KEY,
    order_id       TEXT NOT NULL,
    order_item_id  INT NOT NULL,
    date_key       DATE REFERENCES warehouse.dim_date(date_key),       -- order purchase date
    customer_key   INT REFERENCES warehouse.dim_customer(customer_key),
    product_key    INT REFERENCES warehouse.dim_product(product_key),
    seller_key     INT REFERENCES warehouse.dim_seller(seller_key),
    order_status   TEXT,
    price          NUMERIC(10, 2),   -- this item's price (safe to SUM directly)
    freight_value  NUMERIC(10, 2),   -- this item's freight (safe to SUM directly)
    order_payment_total NUMERIC(10, 2),  -- the WHOLE ORDER's payment total, repeated per item — see grain note above
    review_score   INT,                   -- the order's review score, repeated per item
    delivered_date           DATE,        -- order-level, repeated per item (same grain caveat as above)
    estimated_delivery_date  DATE,        -- order-level, repeated per item
    is_late                  BOOLEAN,     -- TRUE/FALSE once delivered; NULL if not yet delivered
    UNIQUE (order_id, order_item_id)
);