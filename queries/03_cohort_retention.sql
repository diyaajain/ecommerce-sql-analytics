-- Technique: multi-step CTEs building a cohort retention table — group
-- customers by the month of their FIRST purchase, then track what
-- fraction of each cohort is still active N months later.
--
-- Heads-up on what to expect: Olist's repeat-purchase rate is famously
-- very low (most customers buy exactly once), so you will see most
-- month_offset > 0 rows at or near 0%. That's a real, correct finding
-- about this dataset, not a bug in the query — it's worth a line in your
-- write-up ("a key finding is near-zero repeat purchase in this sample").

WITH first_purchase AS (
    SELECT
        dc.customer_unique_id,
        MIN(date_trunc('month', f.date_key)) AS cohort_month
    FROM warehouse.fact_order_items f
    JOIN warehouse.dim_customer dc
        ON dc.customer_key = f.customer_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY dc.customer_unique_id
),
activity AS (
    SELECT DISTINCT
        dc.customer_unique_id,
        date_trunc('month', f.date_key) AS activity_month
    FROM warehouse.fact_order_items f
    JOIN warehouse.dim_customer dc
        ON dc.customer_key = f.customer_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
),
cohort_activity AS (
    SELECT
        fp.cohort_month,
        a.activity_month,
        a.customer_unique_id,
        (
            (DATE_PART('year', a.activity_month) - DATE_PART('year', fp.cohort_month)) * 12
            + (DATE_PART('month', a.activity_month) - DATE_PART('month', fp.cohort_month))
        )::int AS month_offset
    FROM activity a
    JOIN first_purchase fp
        ON fp.customer_unique_id = a.customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_customers
    FROM cohort_activity
    WHERE month_offset = 0
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.month_offset,
    COUNT(DISTINCT ca.customer_unique_id) AS active_customers,
    cs.cohort_customers,
    ROUND(100.0 * COUNT(DISTINCT ca.customer_unique_id) / cs.cohort_customers, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs
    ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, ca.month_offset, cs.cohort_customers
ORDER BY ca.cohort_month, ca.month_offset;
