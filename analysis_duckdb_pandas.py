import time
import tracemalloc
import duckdb
import pandas as pd

# NYC Taxi Parquet Dosyası (Örn: 2023 Ocak ayı Yellow Taxi verisi)
PARQUET_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet"

print("--- DUCKDB ANALİZİ BAŞLIYOR ---")
tracemalloc.start()
start_time = time.time()

# DuckDB ile doğrudan Parquet dosyası üzerinden sorgu (Veriyi belleğe tümüyle yüklemeden tarar)
duckdb_result = duckdb.sql(f"""
    SELECT 
        EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour,
        COUNT(*) AS trip_count,
        AVG(trip_distance) AS avg_distance,
        AVG(fare_amount) AS avg_fare
    FROM '{PARQUET_URL}'
    GROUP BY pickup_hour
    ORDER BY pickup_hour;
""").df()

duckdb_time = time.time() - start_time
duckdb_memory, duckdb_peak = tracemalloc.get_traced_memory()
tracemalloc.stop()

print(f"DuckDB Süre: {duckdb_time:.4f} saniye")
print(f"DuckDB Bellek Kullanımı: {duckdb_peak / 1024 / 1024:.2f} MB\n")


print("--- PANDAS ANALİZİ BAŞLIYOR ---")
tracemalloc.start()
start_time = time.time()

# Pandas ile dosyayı okuma ve gruplama (Tüm veri RAM'e yüklenir)
df = pd.read_parquet(PARQUET_URL)
df['pickup_hour'] = pd.to_datetime(df['tpep_pickup_datetime']).dt.hour
pandas_result = df.groupby('pickup_hour').agg(
    trip_count=('trip_distance', 'count'),
    avg_distance=('trip_distance', 'mean'),
    avg_fare=('fare_amount', 'mean')
).reset_index()

pandas_time = time.time() - start_time
pandas_memory, pandas_peak = tracemalloc.get_traced_memory()
tracemalloc.stop()

print(f"Pandas Süre: {pandas_time:.4f} saniye")
print(f"Pandas Bellek Kullanımı: {pandas_peak / 1024 / 1024:.2f} MB")