-- A materialized view is a query whose RESULT is physically stored, not
-- just its definition (that's a plain view). Reading from it is as fast
-- as reading a table — because it IS a table, under the hood — but its
-- data is a SNAPSHOT: it does NOT update automatically when the
-- underlying fact/dimension tables change. It has to be refreshed
-- explicitly (see the comment at the bottom), which is the real
-- trade-off to understand and be able to explain: faster reads, in
-- exchange for data that can go stale until refreshed.
--
-- This one precomputes monthly revenue by category — a moderately
-- expensive aggregate (two joins, a GROUP BY) that's a natural
-- candidate for a dashboard that gets hit repeatedly.

CREATE MATERIALIZED VIEW warehouse.mv_monthly_category_revenue AS
SELECT
    date_trunc('month', f.date_key)::date AS month,
    dp.category_english,
    SUM(f.price) AS revenue,
    COUNT(*) AS items_sold
FROM warehouse.fact_order_items f
JOIN warehouse.dim_product dp
    ON dp.product_key = f.product_key
WHERE f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1, 2
WITH DATA;

-- A unique index on a materialized view is what allows
-- `REFRESH MATERIALIZED VIEW CONCURRENTLY` later (refreshing without
-- blocking reads from the view while it updates) — a plain REFRESH
-- locks the view for the duration of the refresh.
CREATE UNIQUE INDEX idx_mv_month_category
    ON warehouse.mv_monthly_category_revenue (month, category_english);

-- To refresh after new data is loaded into fact_order_items:
--   REFRESH MATERIALIZED VIEW warehouse.mv_monthly_category_revenue;
-- or, without blocking concurrent reads (needs the unique index above):
--   REFRESH MATERIALIZED VIEW CONCURRENTLY warehouse.mv_monthly_category_revenue;
