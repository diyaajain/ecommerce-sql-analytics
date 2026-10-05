-- Technique: SUM() OVER used two different ways —
--   (a) WITH an ORDER BY: a running/cumulative total
--   (b) with NO ORDER BY: a grand-total window, used here to compute each
--       row's share of the whole (a "percent of total" pattern)
-- Both are SUM() OVER, but the presence/absence of ORDER BY changes the
-- window's frame entirely — worth being able to explain that distinction.

-- Part 1: cumulative revenue by month (running total over time)
WITH monthly AS (
    SELECT
        date_trunc('month', date_key)::date AS month,
        SUM(price + freight_value) AS revenue
    FROM warehouse.fact_order_items
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT
    month,
    revenue,
    SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total_revenue
FROM monthly
ORDER BY month;


-- Part 2: each category's share of total revenue (percent of total, no time dimension)
SELECT
    dp.category_english,
    SUM(f.price) AS category_revenue,
    ROUND(100.0 * SUM(f.price) / SUM(SUM(f.price)) OVER (), 2) AS pct_of_total_revenue
FROM warehouse.fact_order_items f
JOIN warehouse.dim_product dp
    ON dp.product_key = f.product_key
WHERE f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY dp.category_english
ORDER BY category_revenue DESC;
