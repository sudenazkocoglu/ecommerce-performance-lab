# Ödev 3.4 — Analitik Katman ve Star Schema Raporu

## 1. Star Schema Mimarisi ve Grain (Taneler) Tanımları
* **dim_date**: Her bir takvim günü (1 satır = 1 gün).
* **dim_customer**: Müşteri versiyonları (SCD Type 2 destekli, 1 satır = Müşterinin bir adres/bilgi dönemi).
* **dim_product**: Ürün bilgileri (1 satır = 1 benzersiz ürün).
* **fct_orders**: Sipariş üst bilgileri (1 satır = 1 tekil sipariş).
* **fct_order_items**: Sipariş detay kalemleri (1 satır = Siparişteki bir ürün kalemi).

## 2. Idempotent ETL ve SCD Type 2 Mekanizması
Veriler ve boyut tabloları idempotent (tekrar çalıştırıldığında veri bozulmasına yol açmayan) yapıyla yüklenmiştir. `dim_customer` tablosunda SCD Type 2 (`valid_from`, `valid_to`, `is_current`) kullanılarak müşteri değişiklikleri versiyonlanmıştır.

## 3. 10 İş Sorusu: OLTP vs. Star Schema Karşılaştırması

### Soru 1: Belirli bir müşterinin toplam harcama tutarı nedir?
* **OLTP Yaklaşımı (Normalize Tablolar):** Çoklu join maliyeti yüksektir.
* **Star Schema Yaklaşımı:** Boyut tablosundan doğrudan filtreleme ile optimize edilmiştir.

OLTP
```sql
SELECT c.first_name, c.last_name, SUM(o.total_amount) 
FROM customers c JOIN orders o ON c.id = o.user_id 
WHERE c.id = 1 GROUP BY c.first_name, c.last_name;
```

Star Schema:
```sql
SELECT dc.first_name, dc.last_name, SUM(fo.total_amount) 
FROM dim_customer dc JOIN fct_orders fo ON dc.customer_key = fo.customer_key 
WHERE dc.customer_id = 1 AND dc.is_current = TRUE GROUP BY dc.first_name, dc.last_name;
```

### Soru 2: Yıl bazında aylık toplam ciro ve sipariş adetleri nelerdir?

* **OLTP Yaklaşımı:** Tarih filtreleri ve fonksiyonlar (EXTRACT) ham tablo üzerinde maliyetlidir.
* **Star Schema Yaklaşımı:** Önceden türetilmiş `dim_date` boyutu ile gruplama işlemleri çok daha hızlıdır.

OLTP:
```sql
SELECT EXTRACT(YEAR FROM created_at) AS yil, EXTRACT(MONTH FROM created_at) AS ay, COUNT(id) AS siparis_sayisi, SUM(total_amount) AS toplam_ciro 
FROM orders GROUP BY 1, 2 ORDER BY 1, 2;
```

Star Schema:
```sql
SELECT dd.year, dd.month, COUNT(fo.order_id) AS siparis_sayisi, SUM(fo.total_amount) AS toplam_ciro 
FROM fct_orders fo JOIN dim_date dd ON fo.date_key = dd.date_key 
GROUP BY dd.year, dd.month ORDER BY dd.year, dd.month;
```

### Soru 3: En çok satan ilk 5 ürün hangisidir?

**OLTP Yaklaşımı:** Çoklu tablo join'leri (products ve order_items) büyük tablolarda yavaştır.
**Star Schema Yaklaşımı:** Optimize edilmiş dim_product ve fct_order_items üzerinden hızlı sıralama yapılır.

OLTP:
```sql
SELECT p.product_name, SUM(oi.quantity) AS toplam_adet 
FROM products p JOIN order_items oi ON p.id = oi.product_id 
GROUP BY p.product_name ORDER BY toplam_adet DESC LIMIT 5;
```

Star Schema:
```sql
SELECT dp.product_name, SUM(foi.quantity) AS toplam_adet 
FROM dim_product dp JOIN fct_order_items foi ON dp.product_key = foi.product_key 
GROUP BY dp.product_name ORDER BY toplam_adet DESC LIMIT 5;
```

### Soru 4: Hafta içi ve hafta sonu verilen siparişlerin toplam tutarı nedir?

**OLTP Yaklaşımı:** Her satır için anlık tarih hesabı (ISO day) yapılması gerektirir.
**Star Schema Yaklaşımı:** dim_date içindeki hazır is_weekend kolonu kullanılarak sorgu maliyeti sıfıra indirilir.

OLTP:
```sql
SELECT CASE WHEN EXTRACT(ISODOW FROM created_at) IN (6,7) THEN 'Hafta Sonu' ELSE 'Hafta İçi' END AS gun_tipi, SUM(total_amount) 
FROM orders GROUP BY 1;
```

Star Schema:
```sql
SELECT dd.is_weekend, SUM(fo.total_amount) 
FROM fct_orders fo JOIN dim_date dd ON fo.date_key = dd.date_key 
GROUP BY dd.is_weekend;
```

### Soru 5: Müşterilerin şehirlerine göre toplam satış cirosu nedir?

**OLTP Yaklaşımı:** Müşteri ve sipariş tablosu join edilir.
**Star Schema Yaklaşımı:** SCD2 uyumlu aktif müşteri boyutu (is_current = TRUE) üzerinden güvenli analiz yapılır.

OLTP:
```sql
SELECT c.city, SUM(o.total_amount) 
FROM customers c JOIN orders o ON c.id = o.user_id 
GROUP BY c.city;
```

Star Schema:
```sql
SELECT dc.city, SUM(fo.total_amount) 
FROM dim_customer dc JOIN fct_orders fo ON dc.customer_key = fo.customer_key 
WHERE dc.is_current = TRUE GROUP BY dc.city;
```

### Soru 6: Sipariş durumlarına göre ortalama sepet tutarı (AOV) nedir?

**OLTP Yaklaşımı:** Ham orders tablosu üzerinde GROUP BY ile doğrudan hesaplanır.
**Star Schema Yaklaşımı:** fct_orders tablosunda status ve total_amount doğrudan yer aldığı için ekstra join maliyeti yoktur.

OLTP:
```sql
SELECT status, AVG(total_amount) AS ortalama_sepet 
FROM orders 
GROUP BY status;
```

Star Schema:
```sql
SELECT status, AVG(total_amount) AS ortalama_sepet FROM fct_orders GROUP BY status;
```

### Soru 7: Ürün kategorilerine göre toplam satılan ürün adedi nedir?

**OLTP Yaklaşımı:** products ve order_items tablolarının birleştirilmesi gerekir.
**Star Schema Yaklaşımı:** dim_product kategorisi ile fct_order_items birleştirilerek kategorisel analiz tek sorguda çözülür.

OLTP:
```sql
SELECT p.category, SUM(oi.quantity) AS toplam_adet 
FROM products p 
JOIN order_items oi ON p.id = oi.product_id 
GROUP BY p.category;
```

Star Schema:
```sql
SELECT dp.category, SUM(foi.quantity) AS toplam_adet 
FROM dim_product dp JOIN fct_order_items foi ON dp.product_key = foi.product_key 
GROUP BY dp.category;
```

### Soru 8: İptal edilen (cancelled) siparişlerin toplam tutarı nedir?

**Star Schema Yaklaşımı:** Gerçeklik tablosundaki durum filtresi ile anında hesaplanır.
**OLTP Yaklaşımı:** Ham sipariş tablosunda durum filtresi ile toplanır.

OLTP:
```sql
SELECT SUM(total_amount) AS iptal_ciro 
FROM orders 
WHERE status = 'cancelled';
```

Star Schema:
```sql
SELECT SUM(total_amount) AS iptal_ciro FROM fct_orders WHERE status = 'cancelled';
```

### Soru 9: En yüksek tutarlı ilk 3 siparişin müşteri bilgileri nelerdir?

**OLTP Yaklaşımı:** customers ve orders tablolarının join edilip tutara göre sıralanmasını gerektirir.
**Star Schema Yaklaşımı:** Sipariş tablosu ile güncel müşteri boyut tablosu birleştirilerek sıralanır.

OLTP:
```sql
SELECT c.first_name, c.last_name, o.total_amount 
FROM customers c 
JOIN orders o ON c.id = o.user_id 
ORDER BY o.total_amount DESC 
LIMIT 3;
```

Star Schema:
```sql
SELECT dc.first_name, dc.last_name, fo.total_amount 
FROM fct_orders fo JOIN dim_customer dc ON fo.customer_key = dc.customer_key 
ORDER BY fo.total_amount DESC LIMIT 3;
```

### Soru 10: Günlük ortalama sipariş tutarı eğilimi nedir?

**Star Schema Yaklaşımı:** Tarih boyutu ile gerçeklik tablosu birleştirilerek günlük trendler raporlanır.
**OLTP Yaklaşımı:** created_at timestamp alanı üzerinden tarih dönüşümü (DATE()) yapılarak gruplama yapılır.

OLTP:
```sql
SELECT DATE(created_at) AS siparis_tarihi, AVG(total_amount) AS gunluk_ortalama 
FROM orders 
GROUP BY DATE(created_at) 
ORDER BY siparis_tarihi;
```

Star Schema:
```sql
SELECT dd.full_date, AVG(fo.total_amount) AS gunluk_ortalama 
FROM fct_orders fo JOIN dim_date dd ON fo.date_key = dd.date_key 
GROUP BY dd.full_date ORDER BY dd.full_date;
```

## 4. Performans ve Okunabilirlik Karşılaştırma Özeti

* **Okunabilirlik (Maintainability):** Star Schema yapısında dimension tabloları (örneğin `dim_date`, `dim_customer`) önceden filtrelendiği için sorgu karmaşıklığı (`JOIN` sayısı) azalmış ve kod okunabilirliği büyük ölçüde artmıştır. Özellikle tarih filtrelemelerinde OLTP'deki `EXTRACT` fonksiyonları yerine doğrudan `dim_date` anahtarlarının kullanılması sorguları sadeleştirmiştir.
* **Sorgu Süresi (Execution Time):** Çok büyük e-ticaret verilerinde OLTP şemaları üzerindeki normalleştirilmiş join'ler satır maliyetini artırırken, Star Schema tasarımları fact tablosundaki surrogate key index'leri ve optimize edilmiş dimension boyutları sayesinde sorgu sürelerini önemli ölçüde (özellikle 3. ve 10. sorulardaki agregasyonlarda) optimize etmektedir.