import sys
import time
import os
import psutil
import duckdb
import pandas as pd

# NYC Taxi Parquet Dosyası (Örn: 2023 Ocak ayı Yellow Taxi verisi)
PARQUET_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet"

def get_peak_memory():
    """
    İşletim sistemi seviyesinde gerçek RAM (Peak Working Set / RSS) tüketimini ölçer.
    tracemalloc gibi sadece Python'ı değil, arkadaki C/C++ işlemlerini de kapsar.
    """
    process = psutil.Process(os.getpid())
    # Bayt değerini Megabayt'a (MB) çeviriyoruz
    return process.memory_info().peak_wset / (1024 * 1024)

def run_duckdb():
    print("--- DUCKDB ANALİZİ BAŞLIYOR ---")
    start_time = time.time()

    # DuckDB ile doğrudan Parquet dosyası üzerinden sorgu
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
    peak_mb = get_peak_memory()

    print(f"DuckDB Süre: {duckdb_time:.4f} saniye")
    print(f"DuckDB Zirve İşletim Sistemi Belleği (RSS): {peak_mb:.2f} MB\n")

def run_pandas():
    print("--- PANDAS ANALİZİ BAŞLIYOR ---")
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
    peak_mb = get_peak_memory()

    print(f"Pandas Süre: {pandas_time:.4f} saniye")
    print(f"Pandas Zirve İşletim Sistemi Belleği (RSS): {peak_mb:.2f} MB\n")

if __name__ == "__main__":
    # Terminalden gelen argümana göre (pandas veya duckdb) ilgili fonksiyonu çalıştırır.
    # Bu sayede birinin bellek zirvesi diğerini KİRLETMEZ.
    if len(sys.argv) < 2:
        print("KULLANIM HATASI! Lütfen bir motor seçin.")
        print("Komut 1: python analysis_duckdb_pandas.py duckdb")
        print("Komut 2: python analysis_duckdb_pandas.py pandas")
        sys.exit(1)
        
    motor = sys.argv[1].lower()
    if motor == "duckdb":
        run_duckdb()
    elif motor == "pandas":
        run_pandas()
    else:
        print("Geçersiz argüman. Sadece 'duckdb' veya 'pandas' yazın.")