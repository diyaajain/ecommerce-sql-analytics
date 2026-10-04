-- Technique: NTILE() for quartile scoring — the standard way to build an
-- RFM (Recency, Frequency, Monetary) customer segmentation entirely in SQL.
--
-- Caveat worth knowing: because most Olist customers purchase exactly
-- once, `frequency` is heavily tied at 1. NTILE still splits tied values
-- across buckets as evenly as it can, so frequency_score ends up fairly
-- arbitrary for that majority group — recency_score and monetary_score
-- are the more meaningful two here. Worth saying so in a write-up rather
-- than presenting frequency_score as more informative than it is.

WITH dataset_bounds AS (
    SELECT MAX(date_key) AS max_date
    FROM warehouse.fact_order_items
),
rfm_base AS (
    SELECT
        dc.customer_unique_id,
        MAX(f.date_key) AS last_purchase_date,
        COUNT(DISTINCT f.order_id) AS frequency,
        SUM(f.price) AS monetary
    FROM warehouse.fact_order_items f
    JOIN warehouse.dim_customer dc
        ON dc.customer_key = f.customer_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY dc.customer_unique_id
),
rfm_recency AS (
    SELECT
        rb.*,
        (db.max_date - rb.last_purchase_date) AS recency_days
    FROM rfm_base rb
    CROSS JOIN dataset_bounds db
),
rfm_scored AS (
    SELECT
        *,
        -- Most recent (smallest recency_days) -> highest score (4)
        NTILE(4) OVER (ORDER BY recency_days DESC) AS recency_score,
        -- Most frequent -> highest score (4)
        NTILE(4) OVER (ORDER BY frequency ASC) AS frequency_score,
        -- Highest spend -> highest score (4)
        NTILE(4) OVER (ORDER BY monetary ASC) AS monetary_score
    FROM rfm_recency
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS rfm_total
FROM rfm_scored
ORDER BY rfm_total DESC;
