-- Populates fact_order_items at the order-item grain. Payments are
-- summed per order first (a derived subquery, since raw.order_payments
-- can have multiple installment rows per order) and then attached to
-- every item in that order — see the grain note in 01_star_schema.sql
-- for what this means for SUM(order_payment_total) queries.

INSERT INTO warehouse.fact_order_items (
    order_id, order_item_id, date_key, customer_key, product_key, seller_key,
    order_status, price, freight_value, order_payment_total, review_score,
    delivered_date, estimated_delivery_date, is_late
)
SELECT
    oi.order_id,
    oi.order_item_id,
    o.order_purchase_timestamp::date,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    o.order_status,
    oi.price,
    oi.freight_value,
    pay.order_payment_total,
    r.review_score,
    o.order_delivered_customer_date::date,
    o.order_estimated_delivery_date::date,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL  -- not delivered yet (or never was)
        ELSE o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
    END
FROM raw.order_items oi
JOIN raw.orders o
    ON o.order_id = oi.order_id
JOIN raw.customers c
    ON c.customer_id = o.customer_id
JOIN warehouse.dim_customer dc
    ON dc.customer_id = c.customer_id
JOIN warehouse.dim_product dp
    ON dp.product_id = oi.product_id
JOIN warehouse.dim_seller ds
    ON ds.seller_id = oi.seller_id
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS order_payment_total
    FROM raw.order_payments
    GROUP BY order_id
) pay
    ON pay.order_id = o.order_id
LEFT JOIN (
    -- An order can have more than one review row in the raw data; take
    -- the most recent one rather than silently fan out the join.
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM raw.order_reviews
    ORDER BY order_id, review_creation_date DESC
) r
    ON r.order_id = o.order_id;