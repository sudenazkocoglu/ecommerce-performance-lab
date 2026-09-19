# Ödev 3.5 — DuckDB ile Dosya Analitiği ve Pandas Karşılaştırma Raporu

## 1. Yöntem ve Veri Seti
* **Veri Seti:** NYC Taxi and Limousine Commission (TLC) - Yellow Taxi Trip Records (Ocak 2023, Parquet formatı).
* **DuckDB Yaklaşımı:** Sütunsal (columnar) ve vektörize sorgulama motoru sayesinde Parquet dosyasını sunucuya veya tümüyle RAM'e ihtiyaç duymadan doğrudan tarar (Lazy Evaluation / Out-of-core).
* **Pandas Yaklaşımı:** Dosyayı `pd.read_parquet` ile tamamen RAM'e (`DataFrame`) yükleyerek in-memory (bellek içi) işlem yapar. Büyük dosyalarda ciddi performans darboğazlarına ve yüksek bellek tüketimine yol açar.

---

## 2. 10 Analitik Sorgu ve Karşılaştırma

### Soru 1: Saatlere göre toplam yolculuk sayısı ve ortalama ücretler nedir?
* **DuckDB:** `SELECT EXTRACT(HOUR FROM tpep_pickup_datetime), COUNT(*), AVG(fare_amount) FROM file GROUP BY 1`
* **Pandas:** `df.groupby(df['tpep_pickup_datetime'].dt.hour).agg(...)`

### Soru 2: Ödeme türlerine göre ortalama yolculuk mesafesi nedir?
* **DuckDB:** `SELECT payment_type, AVG(trip_distance) FROM file GROUP BY payment_type`
* **Pandas:** `df.groupby('payment_type')['trip_distance'].mean()`

### Soru 3: En çok yolcu alınan ilk 5 lokasyon (PULocationID) hangisidir?
* **DuckDB:** `SELECT PULocationID, COUNT(*) FROM file GROUP BY PULocationID ORDER BY 2 DESC LIMIT 5`
* **Pandas:** `df['PULocationID'].value_counts().head(5)`

### Soru 4: Oran kodlarına (RatecodeID) göre ortalama bahşiş (tip_amount) tutarı nedir?
* **DuckDB:** `SELECT RatecodeID, AVG(tip_amount) FROM file GROUP BY RatecodeID`
* **Pandas:** `df.groupby('RatecodeID')['tip_amount'].mean()`

### Soru 5: Yolculuklardaki maksimum ve minimum yolcu sayısı nedir?
* **DuckDB:** `SELECT MAX(passenger_count), MIN(passenger_count) FROM file`
* **Pandas:** `df['passenger_count'].max()`, `df['passenger_count'].min()`

### Soru 6: Toplam tutarı (total_amount) en yüksek olan ilk 5 yolculuk hangisidir?
* **DuckDB:** `SELECT * FROM file ORDER BY total_amount DESC LIMIT 5`
* **Pandas:** `df.nlargest(5, 'total_amount')`

### Soru 7: Köprü/otoyol geçiş ücreti (tolls_amount) sıfırdan büyük olan yolculukların ortalaması nedir?
* **DuckDB:** `SELECT AVG(tolls_amount) FROM file WHERE tolls_amount > 0`
* **Pandas:** `df[df['tolls_amount'] > 0]['tolls_amount'].mean()`

### Soru 8: Günlere göre toplam yolculuk dağılımı nasıldır?
* **DuckDB:** `SELECT EXTRACT(DOW FROM tpep_pickup_datetime), COUNT(*) FROM file GROUP BY 1`
* **Pandas:** `df.groupby(df['tpep_pickup_datetime'].dt.dayofweek)['tpep_pickup_datetime'].count()`

### Soru 9: Ortalama yolculuk süresi dakika cinsinden nasıl hesaplanır?
* **DuckDB:** `SELECT AVG(EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime))/60) FROM file`
* **Pandas:** `((df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']).dt.total_seconds() / 60).mean()`

### Soru 10: Mesafe ile toplam tutar arasındaki genel ortalama ilişkisi nedir?
* **DuckDB:** `SELECT AVG(trip_distance), AVG(total_amount) FROM file`
* **Pandas:** `df[['trip_distance', 'total_amount']].mean()`

---

### 📊 Bellek ve Performans Karşılaştırması (Gerçek OS-Level RSS Ölçümü)

*Not: Önceki ölçümlerde kullanılan `tracemalloc` aracı yalnızca saf Python objelerini takip edip C/C++ motorlarının tahsislerini kaçırdığı için, bu yeni testte işletim sistemi seviyesindeki gerçek RAM tüketimini ölçen `psutil.Process().memory_info().peak_wset` (Peak RSS) metodu kullanılmış ve her iki motor birbirini kirletmemesi adına izole süreçlerde (ayrı ayrı) çalıştırılmıştır.*

| Metrik | DuckDB (Out-of-Core) | Pandas (In-Memory) | Fark |
| :--- | :--- | :--- | :--- |
| **İşlem Süresi** | 20.14 saniye | 48.90 saniye | DuckDB ~2.4x daha hızlı |
| **Zirve Bellek (OS RSS)** | 149.84 MB | 1123.50 MB | DuckDB ~7.5x daha az RAM |

**Sonuç ve Analiz:**
İşletim sistemi düzeyindeki gerçek bellek ölçümleri, iki aracın mimari farkını net bir şekilde ortaya koymaktadır. Pandas, veriyi işleyebilmek için dosyanın tamamını ve oluşturduğu ara objeleri devasa bir blok olarak RAM'e yüklediği için bellek tüketimi 1.1 GB'ın üzerine çıkmıştır. Buna karşın DuckDB, veriyi disk üzerinden vektörel olarak ve bloklar halinde okuyan (out-of-core) optimize bir C++ motoruna sahip olduğundan, aynı işi sadece ~150 MB gerçek bellek harcayarak ve 2.4 kat daha hızlı tamamlamıştır.

## 4. Sonuç ve Değerlendirme
Büyük veri dosyalarında (Parquet, CSV vb.) sunucu kurmadan hızlı analitik sorgular çalıştırmak gerektiğinde **DuckDB**, sunduğu vektörize sorgulama ve düşük bellek ayak izi sayesinde geleneksel Pandas tabanlı in-memory yaklaşımlara kıyasla çok daha üstün performans ve ölçeklenebilirlik sunmaktadır.