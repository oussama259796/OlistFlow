from google.cloud import bigquery
import pandas as pd
import os
import logging
from dotenv import load_dotenv

load_dotenv()
os.makedirs("logs", exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    filename="logs/app.log",
    format="%(asctime)s - %(levelname)s - %(message)s",
    encoding='utf-8'
)
logger = logging.getLogger(__name__)

PROJECT = os.getenv("GCP_PROJECT")
DATASET = "bronze"
DATA_DIR = 'data/'

TABLES = {
    "olist_orders":               "olist_orders_dataset.csv",
    "olist_order_items":          "olist_order_items_dataset.csv",
    "olist_order_payments":       "olist_order_payments_dataset.csv",
    "olist_order_reviews":        "olist_order_reviews_dataset.csv",
    "olist_customers":            "olist_customers_dataset.csv",
    "olist_sellers":              "olist_sellers_dataset.csv",
    "olist_products":             "olist_products_dataset.csv",
    "olist_geolocation":          "olist_geolocation_dataset.csv",
    "product_category_name":      "product_category_name_translation.csv",
}


def get_client():
    return bigquery.Client()

def create_dataset(client):
    dataset = bigquery.Dataset(f'{PROJECT}.{DATASET}')
    dataset.location = "US"
    client.create_dataset(dataset, exists_ok=True)
    logger.info(f"✅ Dataset {DATASET} ready")

def load_csv_to_bigquery(client, table_name, file_name):
    file_path = os.path.join(DATA_DIR, file_name)

    if not os.path.exists(file_path):
        logger.warning(f"⚠️ File not found: {file_path}")
        return
    
    table_id = f'{PROJECT}.{DATASET}.{table_name}'

    job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.CSV,
    skip_leading_rows=1,
    autodetect=True,
    write_disposition="WRITE_TRUNCATE",
    allow_quoted_newlines=True,  # ← يسمح بـ newlines داخل quotes
    allow_jagged_rows=True,      # ← يسمح بصفوف ناقصة
    max_bad_records=1         # ← يتجاوز الصفوف السيئة
    )

    with open(file_path, "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=job_config)
    # بعد job.result()
    
    job.result()
    logger.info(f"✅ Loaded {job.output_rows} rows → {table_name}")


def ingest():
    try:
        logger.info("🚀 Starting Olist ingestion pipeline")
        client = get_client()
        create_dataset(client)
        
        for table_name, file_name in TABLES.items():
            load_csv_to_bigquery(client, table_name, file_name)
        
        logger.info("✅ All tables loaded successfully!")
    except Exception as e:
        logger.error(f"❌ Pipeline failed: {e}")
        raise

if __name__ == "__main__":
    ingest()