"""Load the Olist CSVs into the raw.* staging tables as-is.

This file deliberately does almost nothing — no cleaning, no joins, no
business logic. That's intentional: in this project, all of the real
work (typing, cleaning, modeling, aggregating) happens in the SQL scripts
under sql/, where it's visible, reviewable, and the actual point of the
project. This script's only job is "get the CSVs into Postgres."

Usage:
    python3 load_raw.py
"""
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

DATA_DIR = Path(__file__).with_name("data")

# CSV filename (as downloaded from Kaggle) -> (raw table name, columns to parse as dates)
FILES = {
    "olist_customers_dataset.csv": ("customers", []),
    "olist_orders_dataset.csv": ("orders", [
        "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]),
    "olist_order_items_dataset.csv": ("order_items", ["shipping_limit_date"]),
    "olist_products_dataset.csv": ("products", []),
    "olist_sellers_dataset.csv": ("sellers", []),
    "olist_order_payments_dataset.csv": ("order_payments", []),
    "olist_order_reviews_dataset.csv": ("order_reviews", [
        "review_creation_date", "review_answer_timestamp",
    ]),
    "product_category_name_translation.csv": ("category_translation", []),
}


def get_engine():
    user = os.environ.get("PGUSER", "warehouse")
    pwd = os.environ.get("PGPASSWORD", "warehouse")
    host = os.environ.get("PGHOST", "localhost")
    port = os.environ.get("PGPORT", "5432")
    db = os.environ.get("PGDATABASE", "ecommerce")
    return create_engine(f"postgresql+psycopg2://{user}:{pwd}@{host}:{port}/{db}")


def main() -> None:
    engine = get_engine()
    missing = [f for f in FILES if not (DATA_DIR / f).exists()]
    if missing:
        print("Missing CSVs in data/:")
        for f in missing:
            print(f"  - {f}")
        print("\nDownload the Olist dataset from Kaggle and place the CSVs in data/. "
              "See README.md for the exact steps.")
        raise SystemExit(1)

    for filename, (table, date_cols) in FILES.items():
        path = DATA_DIR / filename
        print(f"Loading {filename} -> raw.{table} ...", end=" ", flush=True)
        df = pd.read_csv(path, parse_dates=date_cols)
        df.to_sql(table, engine, schema="raw", if_exists="append", index=False, method="multi", chunksize=5000)
        print(f"{len(df):,} rows")

    print("\nDone. Next: run the SQL scripts in sql/ in order (see README.md).")


if __name__ == "__main__":
    main()
