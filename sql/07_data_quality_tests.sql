-- Data quality / ETL correctness checks for the warehouse schema.
-- Run any time after sql/04_load_fact.sql (does not depend on 05 or 06).
--
-- Pattern: every block below is a "negative" check — it is written to
-- return ZERO rows when everything is correct. Any row that DOES appear
-- names a real problem and how many rows it affects.
--   Empty result set = every check passed.
--
-- Why check row-count parity specifically (the first block): most of
-- fact_order_items's ETL (sql/04_load_fact.sql) uses INNER JOINs to
-- dim_customer, dim_product, and dim_seller. An inner join SILENTLY
-- DROPS a row when its foreign key has no match in the dimension —
-- there's no error, just a smaller fact table than expected, which is
-- exactly the kind of bug that's easy to miss without a check like this.

SELECT
    'row count mismatch: raw.order_items vs fact_order_items' AS check_name,
    ABS(
        (SELECT COUNT(*) FROM raw.order_items)
        - (SELECT COUNT(*) FROM warehouse.fact_order_items)
    ) AS affected_count
WHERE (SELECT COUNT(*) FROM raw.order_items)
    <> (SELECT COUNT(*) FROM warehouse.fact_order_items)

UNION ALL

SELECT
    'duplicate (order_id, order_item_id) in fact_order_items',
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
FROM warehouse.fact_order_items
HAVING COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) > 0

UNION ALL

SELECT
    'fact rows with NULL price or freight_value',
    COUNT(*)
FROM warehouse.fact_order_items
WHERE price IS NULL OR freight_value IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT
    'fact rows with negative price or freight_value',
    COUNT(*)
FROM warehouse.fact_order_items
WHERE price < 0 OR freight_value < 0
HAVING COUNT(*) > 0

UNION ALL

SELECT
    'dim_product rows with NULL category_english (the COALESCE fallback should prevent this)',
    COUNT(*)
FROM warehouse.dim_product
WHERE category_english IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT
    'dim_customer: duplicate customer_id',
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM warehouse.dim_customer
HAVING COUNT(*) - COUNT(DISTINCT customer_id) > 0

UNION ALL

SELECT
    'fact rows with review_score outside the valid 1-5 range',
    COUNT(*)
FROM warehouse.fact_order_items
WHERE review_score IS NOT NULL
    AND review_score NOT BETWEEN 1 AND 5
HAVING COUNT(*) > 0

UNION ALL

SELECT
    'is_late flag disagrees with the dates it should be derived from',
    COUNT(*)
FROM warehouse.fact_order_items
WHERE (is_late = TRUE  AND delivered_date <= estimated_delivery_date)
   OR (is_late = FALSE AND delivered_date >  estimated_delivery_date)
HAVING COUNT(*) > 0

ORDER BY 1;
