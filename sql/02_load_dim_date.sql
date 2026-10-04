-- Generates one row per calendar day using generate_series() instead of
-- deriving dates from the data — a standard, reusable pattern for a date
-- dimension (every possible date exists, even ones with no orders).
-- Olist's data runs roughly Sept 2016-Oct 2018; the range below has
-- margin on both ends.

INSERT INTO warehouse.dim_date (
    date_key, year, quarter, month, month_name, day, day_of_week, day_name, is_weekend
)
SELECT
    d::date,
    EXTRACT(YEAR FROM d)::int,
    EXTRACT(QUARTER FROM d)::int,
    EXTRACT(MONTH FROM d)::int,
    TRIM(TO_CHAR(d, 'Month')),
    EXTRACT(DAY FROM d)::int,
    EXTRACT(ISODOW FROM d)::int,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series('2016-01-01'::date, '2018-12-31'::date, interval '1 day') AS d;
