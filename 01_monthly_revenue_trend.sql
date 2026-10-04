-- Technique: window functions — LAG() for period-over-period growth,
-- a moving-window frame for a rolling average.
-- Excludes canceled/unavailable orders so the trend reflects real revenue.

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
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0),
        1
    ) AS mom_growth_pct,
    ROUND(
        AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    ) AS revenue_3mo_moving_avg
FROM monthly
ORDER BY month;
