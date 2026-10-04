-- Technique: reading an execution plan and proving an index actually
-- helps, instead of just asserting it does.
--
-- How to use this file:
--   1. Run sql/00-04 (schema + ETL) but NOT sql/05_indexes.sql yet.
--   2. Run the EXPLAIN ANALYZE below and save the output ("BEFORE").
--   3. Now run sql/05_indexes.sql.
--   4. Run the same EXPLAIN ANALYZE again ("AFTER") and compare.
--
-- What to look for in the output: "Seq Scan" (reads the whole table) in
-- the BEFORE plan changing to "Index Scan" or "Bitmap Heap Scan" in the
-- AFTER plan, and a drop in the reported "actual time". On a table this
-- size (~110k fact rows) the absolute time difference may be small —
-- that's a legitimate, honest finding too: indexes matter more as data
-- grows, and it's worth noting in a write-up that you measured this
-- rather than assumed it.

EXPLAIN ANALYZE
SELECT
    dp.category_english,
    COUNT(*) AS items_sold,
    SUM(f.price) AS revenue
FROM warehouse.fact_order_items f
JOIN warehouse.dim_product dp
    ON dp.product_key = f.product_key
WHERE f.order_status = 'delivered'
GROUP BY dp.category_english
ORDER BY revenue DESC;
