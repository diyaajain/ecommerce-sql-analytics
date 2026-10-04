-- dim_customer: one row per Olist customer_id (per-order id). The
-- separate customer_unique_id column is what you GROUP BY when you want
-- real distinct people — see the README note on this split.
INSERT INTO warehouse.dim_customer (customer_id, customer_unique_id, city, state)
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state
FROM raw.customers;

-- dim_product: joins in the English category name so queries don't have
-- to repeat that join every time. Falls back to the original Portuguese
-- name, then to 'unknown', so a missing translation never turns into a
-- silent NULL in every downstream query.
INSERT INTO warehouse.dim_product (product_id, category_english, weight_g, length_cm, height_cm, width_cm)
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown'),
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM raw.products p
LEFT JOIN raw.category_translation t
    ON t.product_category_name = p.product_category_name;

-- dim_seller
INSERT INTO warehouse.dim_seller (seller_id, city, state)
SELECT DISTINCT
    seller_id,
    seller_city,
    seller_state
FROM raw.sellers;
