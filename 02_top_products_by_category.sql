-- Technique: DENSE_RANK() PARTITION BY — "top N per group," one of the
-- most common real-world window function use cases.

WITH product_revenue AS (
    SELECT
        dp.category_english,
        dp.product_id,
        SUM(f.price) AS total_revenue,
        COUNT(*) AS units_sold
    FROM warehouse.fact_order_items f
    JOIN warehouse.dim_product dp
        ON dp.product_key = f.product_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY dp.category_english, dp.product_id
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY category_english ORDER BY total_revenue DESC
        ) AS rank_in_category
    FROM product_revenue
)
SELECT category_english, product_id, total_revenue, units_sold, rank_in_category
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category_english, rank_in_category;
