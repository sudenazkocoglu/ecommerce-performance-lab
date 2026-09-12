# E-Commerce Performance Lab & Data Engineering Portfolio (Ödev 3.3 — 3.7)

Bu depo, e-ticaret senaryoları üzerinden **PostgreSQL tabanlı performans optimizasyonu, Star Schema analitik modelleme, DuckDB/Pandas dosya analitiği kıyaslamaları, SCD Type 2 mimarileri ve gelişmiş veri mühendisliği kontrol sorularını** içeren kapsamlı bir laboratuvar çalışmasını barındırır.

---

## 📂 Proje Dosya Yapısı ve İçerikler

| Dosya Adı | İlgili Modül / Ödev | Açıklama |
| :--- | :--- | :--- |
| `queries_lab.sql` | **Ödev 3.3** | Kasten yörüngeden saptırılmış 5 yavaş sorgu, `EXPLAIN ANALYZE` çıktıları ve index optimizasyonları. |
| `ODEV_3_3_RAPORU.md` | **Ödev 3.3** | Performans lab öncesi/sonrası süre tabloları ve index'in işe yaramadığı senaryo analizleri. |
| `queries_star_schema.sql` | **Ödev 3.4** | Star Schema DDL (`fct_orders`, `fct_order_items`, `dim_customer`, `dim_product`, `dim_date`), SCD Type 2 ve Idempotent ETL kodları. |
| `ODEV_3_4_RAPORU.md` | **Ödev 3.4** | Grain tanımları ve 10 iş sorusunun OLTP vs Star Schema mimarilerindeki okunabilirlik/süre karşılaştırmaları. |
| `analysis_duckdb_pandas.py` | **Ödev 3.5** | NYC Taxi Parquet verisi üzerinde çalışan DuckDB ve Pandas kıyaslama betiği. |
| `ODEV_3_5_RAPORU.md` | **Ödev 3.5** | Bellek (RAM) ve süre karşılaştırma matrisi ile 10 analitik sorgu dökümü. |
| `ODEV_3_6_RAPORU.md` | **Ödev 3.6** | OLTP vs OLAP (satır/kolon bazlı depolama) ve SCD Type 2 ile ML veri sızıntısı (data leakage) araştırma raporları. |
| `ODEV_3_7_RAPORU.md` | **Ödev 3.7** | Kritik SQL ve veritabanı mimarisi kontrol sorularının teknik çözümleri. |

---

## 🚀 Modül Özetleri

### 1. Performans Laboratuvarı ve İndexleme (Ödev 3.3)
* İlişkisel tablolarda kasten verimsiz yazılmış 5 sorgu `EXPLAIN ANALYZE` ile incelenmiştir.
* Doğru index stratejileriyle sorgu sürelerinin saniyelerden milisaniyelere düşüşü raporlanmıştır.
* Düşük seçicilik (low selectivity), fonksiyon uygulanmış kolonlar ve tip uyuşmazlığı gibi index'in işe yaramadığı durumlar pratik örneklerle açıklanmıştır.

### 2. Analitik Katman ve Star Schema (Ödev 3.4)
* OLTP şemadan hareketle optimize edilmiş bir **Star Schema** (`dim_date`, `dim_customer`, `dim_product`, `fct_orders`, `fct_order_items`) tasarlanmıştır.
* Müşteri adres ve unvan değişikliklerini tarihsel olarak izlemek için **SCD Type 2** (`valid_from`, `valid_to`, `is_current`) mekanizması kurulmuştur.
* Tekrar çalıştırıldığında veriyi bozmayan **Idempotent ETL** yükleme sorguları yazılmıştır.

### 3. DuckDB ile Dosya Analitiği ve Kıyaslama (Ödev 3.5)
* ~3 GB boyutundaki NYC Taxi Parquet veri seti üzerinden sunucu kurmadan doğrudan dosya analitiği gerçekleştirilmiştir.
* **DuckDB** (sütunsal / out-of-core) ile **Pandas** (bellek içi / in-memory) aynı sorgularla karşılaştırılmış; DuckDB'nin çok daha az bellek tüketerek kat kat daha hızlı çalıştığı kanıtlanmıştır.

### 4. Akademik Araştırma Ödevleri (Ödev 3.6)
* **OLTP vs OLAP:** Satır ve kolon bazlı depolama mimarilerinin fiziksel disk yapıları, sıkıştırma avantajları ve laboratuvar ölçümleri incelenmiştir.
* **SCD Type 2 ve ML Data Leakage:** Geçmiş tarihli özellik mühendisliği (feature engineering) yapılırken SCD Type 2 kullanılmamasının gelecekteki bilgiyi geçmişe sızdırarak model başarısını nasıl düşürdüğü akademik bir dille ele alınmıştır.

### 5. Teknik Kontrol Soruları (Ödev 3.7)
* `LEFT JOIN` sonrası `IS NOT NULL` kullanımı, `NOT IN` sorgularında `NULL` tehlikesi, `COUNT(*)` vs `COUNT(column)`, Satır Patlaması (Row Explosion) analizi, Window Functions vs `GROUP BY` farkları ve Index eklemenin disk/yazma maliyetleri detaylandırılmıştır.

---

## 🛠️ Kullanılan Teknolojiler
* **Veritabanı / SQL:** PostgreSQL, DuckDB
* **Programlama & Analiz:** Python, Pandas, PyArrow
* **Sürüm Kontrolü:** Git & GitHub