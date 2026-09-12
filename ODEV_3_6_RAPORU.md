# Ödev 3.6 — Araştırma Ödevleri Raporu

## 1. OLTP ve OLAP Mimarileri: Satır Bazlı ve Kolon Bazlı Depolama Karşılaştırma Analizi

Modern veri mimarilerinde verinin diske fiziksel olarak depolanma biçimi, sorgu performansını, kaynak tüketimini ve sistemin genel ölçeklenebilirliğini doğrudan belirleyen en kritik bileşendir. Veritabanı ve veri ambarı sistemleri, temel iş yükü hedeflerine göre iki ana kategoriye ayrılır: Günlük operasyonel işlemleri optimize eden **OLTP (Online Transaction Processing)** sistemleri ve büyük hacimli veriler üzerinde karmaşık analitik sorguları ve toplulaştırma (aggregation) işlemlerini hedefleyen **OLAP (Online Analytical Processing)** sistemleri. Bu iki paradigmanın arasındaki derin performans farkının temel sebebi, verinin diske yazılış mimarisi yani **Satır bazlı (Row-oriented)** ve **Kolon bazlı (Column-oriented)** depolama yaklaşımlarıdır.

### Satır Bazlı Depolama (Row-Oriented Storage) ve OLTP Mimarisi

PostgreSQL, MySQL ve Oracle gibi geleneksel ilişkisel veritabanları (RDBMS), verileri satır bazlı bir yapıda depolar. Bu mimaride, bir tablodaki tek bir kayda (record) ait tüm sütun değerleri diskin üzerinde ardışık (contiguous) bellek blokları halinde bulunur. Örneğin, bir e-ticaret veritabanındaki `orders` tablosunda sipariş ID, müşteri ID, sipariş tarihi, toplam tutar ve sipariş durumu gibi farklı veri tiplerindeki tüm sütunlar, fiziksel disk sayfasında yan yana yazılır.

Satır bazlı depolama mimarisi, **Point Lookups** (tekil nokta sorguları) ve **Write/Update/Delete** (yazma, güncelleme ve silme) işlemleri için kusursuz bir performans sunar. Sistemi kullanan bir son kullanıcının anlık olarak sepetine ürün eklemesi, şifresini güncellemesi veya tek bir siparişin detayını sorgulaması, ilgili satırın bulunduğu tek bir disk bloğuna erişilerek çok hızlı bir şekilde gerçekleştirilebilir. Disk okuma/yazma (I/O) birimi olan sayfalar tüm satırı bir bütün olarak barındırdığı için, tek bir işlemle tüm kayda eksiksiz ulaşılır. 

Ancak bu yapı, büyük veri analitiği söz konusu olduğunda ciddi bir darboğaz (bottleneck) yaratır. Milyonlarca satırdan oluşan bir e-ticaret tablosundan yalnızca iki sütunun (`total_amount` ve `order_id`) ortalamasını veya toplamını almak istediğimizde bile, diskten okunan her bir veri sayfası içinde analitik olarak tamamen gereksiz olan diğer tüm sütun verileri (açıklamalar, adres metinleri, uzun metinsel alanlar vb.) de belleğe taşınmak zorundadır. Bu durum, disk bant genişliğinin ve RAM kaynaklarının büyük bir kısmının gereksiz yere boşa harcanmasına yol açar. Ayrıca, satır tabanlı sistemlerde veriler disk üzerinde heterojen veri tipleriyle yan yana tutulduğu için modern CPU önbellek (cache) optimizasyonlarından ve sıkıştırma (compression) oranlarından yeterince yararlanılamaz.

### Kolon Bazlı Depolama (Column-Oriented Storage) ve OLAP Mimarisi

DuckDB, ClickHouse, Apache Parquet ve Snowflake gibi modern analitik sistemler ise verileri kolon bazlı saklar. Bu yaklaşımda, tablodaki satırlar yerine her bir sütuna ait veriler disk üzerinde ayrı ve bağımsız ardışık bloklar halinde tutulur. Aynı sütunun verileri yan yana bulunduğundan, sıkıştırma (compression) oranları satır tabanlı sistemlere kıyasla kat kat daha yüksektir. Benzer veri tipleri (örneğin aynı şehir isimleri, ardışık tarihler veya tekrar eden kategori kodları) bir arada saklandığında, Run-Length Encoding (RLE), Dictionary Coding ve Bitpacking gibi gelişmiş sıkıştırma algoritmaları maksimum verimle çalışır; bu da veri boyutunu disk üzerinde %70 ila %90 oranında küçültür.

OLAP iş yüklerinde analistler genellikle tüm tabloyu değil, belirli birkaç sütunu hedef alır (`SELECT AVG(total_amount), COUNT(order_id)`). Kolon bazlı depolama sayesinde sorgu motoru, yalnızca sorguda geçen sütunların dosyalarını diskten okur. İşlemle ilgisi olmayan diğer tüm sütunlar diskte okunmadan doğrudan atlanır. Bu durum, disk G/Ç (I/O) maliyetini minimuma indirir. Buna ek olarak, modern CPU mimarilerine uygun olarak geliştirilen **Vectorized Execution** (vektörize yürütme) ve SIMD (Single Instruction, Multiple Data) teknikleri sayesinde tek bir CPU döngüsünde birden fazla veri işlenerek işlemci performansı en üst düzeye çıkarılır.

### Laboratuvar Ölçümleri ve Performans Karşılaştırması

Laboratuvar ortamında gerçekleştirilen ~3 GB boyutundaki NYC Taxi Parquet veri seti analizi, bu iki mimari arasındaki uçurumu net bir şekilde kanıtlamıştır. PostgreSQL tabanlı OLTP ortamında milyonlarca satırlık tablolarda yapılan karmaşık join ve gruplama işlemleri saniyeler süren maliyetler üretirken, DuckDB'nin kolon bazlı Parquet tarama motoru aynı analitik sorguyu hiçbir ön sunucu kurulumu gerektirmeden **11.81 saniyede** ve **0.31 MB** gibi son derece düşük bir bellek ayak iziyle tamamlamıştır. Buna karşın, veriyi tümüyle RAM'e `DataFrame` olarak yükleyen Pandas tabanlı in-memory yaklaşım hem **22.34 saniye** süre harcamış hem de **95.11 MB** bellek tüketmiştir. Sonuç olarak, operasyonel işlemler ve anlık veri güncellemeleri için satır bazlı OLTP sistemleri vazgeçilmezken, büyük veri analitiği, geçmişe dönük raporlama ve veri bilimi modelleri için kolon bazlı OLAP / Parquet / DuckDB ekosistemleri hız, maliyet ve kaynak verimliliği açısından mutlak bir üstünlük sağlamaktadır.

---

## 2. SCD Type 2 Nedir ve Neden ML Özelliği Üretirken Kritiktir?

Veri ambarı mimarilerinde ve makine öğrenmesi (ML) boru hatlarında (pipelines) veri kalitesini, tutarlılığını ve model güvenilirliğini korumak hayati önem taşır. Müşteri adresleri, unvanları, meslekleri, gelir düzeyleri veya sadakat segment bilgileri zaman içinde değişebilir. Bu değişimlerin veritabanında nasıl saklanacağı **SCD (Slowly Changing Dimensions - Yavaş Değişen Boyutlar)** stratejileri ile yönetilir. Özellikle **SCD Type 2**, geçmişteki verileri kaybetmeden her değişikliği yeni bir versiyon olarak saklayan endüstri standardı yaklaşımdır. Bu mekanizmanın makine öğrenmesi özelliği (feature engineering) üretirken ihmal edilmesi ise **Data Leakage (Veri Sızıntısı)** adı verilen ve modelin geleceği önceden bilmesine yol açarak başarısız olmasına neden olan kritik bir hataya yol açar.

### SCD Type 2 Mekanizmasının Temelleri ve Versiyonlama Mantığı

SCD Type 2, bir boyuttaki değişiklikleri izlemek için satır düzeyinde versiyonlama uygular. Tabloda birincil anahtarın (`customer_id`) yanı sıra `valid_from` (geçerlilik başlangıç tarihi), `valid_to` (geçerlilik bitiş tarihi) ve `is_current` (aktif kayıt bayrağı) kolonları yer alır. Örneğin, Ankara'da yaşayan bir müşteri 2024 yılının Haziran ayında İstanbul'a taşındığında, mevcut kayıt silinmez veya güncellenmez; aksine eski kaydın `is_current` değeri `FALSE` yapılarak `valid_to` kolonuna taşınma tarihi yazılır. Müşteri için aynı `customer_id` ile yeni bir satır oluşturulur, bu satırın şehri `İstanbul`, `valid_from` değeri ise taşınma tarihi olarak atanır ve `is_current` değeri `TRUE` yapılır. Bu sayede sistem, müşterinin hangi tarihte nerede yaşadığının ve hangi özelliklere sahip olduğunun tam tarihsel haritasını eksiksiz tutar.

### Makine Öğrenmesinde Özellik Üretimi ve Veri Sızıntısı Tehlikesi

Makine öğrenmesi modelleri (örneğin müşteri churn tahmini, kredi risk analizi, dolandırıcılık tespiti veya müşteri yaşam boyu değeri - LTV hesaplamaları), geçmişteki davranışları ve o anki durumsal özellikleri ilişkilendirerek geleceği tahmin etmeyi amaçlar. Model için eğitim veri seti (training dataset) hazırlanırken, geçmiş bir tarihte (örneğin 1 Ocak 2024) gerçekleşmiş bir olaya ait özellikler üretilirken bugünün veritabanı durumunu baz almak **Data Leakage** kusurudur.

Eğer 2024 yılının Ocak ayındaki bir müşterinin davranışını tahmin etmek için hazırlanan özellik matrisine, müşterinin 2026 yılındaki güncel müşteri segmentini, güncel gelir grubunu veya güncel şehir bilgisini (`is_current = TRUE` olan kaydı) doğrudan yansıtırsak, gelecekteki bilgiyi geçmişe sızdırmış oluruz. Müşteri 2024'te düşük gelirli veya standart segmentte iken, 2026'da "VIP/Gold" segmente yükselmiş olabilir. Eğer model 2024 verilerini eğitirken müşterinin 2026'daki VIP durumunu görürse, model henüz o tarihte gerçekleşmemiş bir bilgiyi öğrenmiş olur. Bu durum, modelin eğitim esnasında yapay olarak çok yüksek doğruluk (accuracy) skorları üretmesine yol açar; ancak model canlıya (production) alındığında geleceği göremeyeceği için gerçek dünyada büyük bir başarısızlıkla sonuçlanır. Modern Feature Store (Özellik Mağazası) mimarilerinde bu sorun, geçmişe dönük anlık özellik çekme (Point-in-Time Feature Retrieval) mekanizmalarıyla çözülmektedir.

### Noktasal Doğruluk (Point-in-Time Correctness) ve Çözüm

Bu veri sızıntısını engellemenin tek yolu **Point-in-Time Correctness** (Noktasal Zaman Doğruluğu) prensibini uygulamaktır. Özellik mühendisliği aşamasında işlemler yapılırken, işlem (transaction) veya olay tarihi (`event_timestamp`), SCD Type 2 boyut tablosunun geçerlilik aralığı ile eşleştirilmelidir. 

Doğru bir özellik üretme sorgusunda join işlemi şu zamansal koşula dayanmalıdır:
```sql
SELECT t.order_id, t.order_date, dc.city, dc.segment
FROM transactions t
JOIN dim_customer_scd2 dc 
  ON t.customer_id = dc.customer_id
  AND t.order_date >= dc.valid_from 
  AND (t.order_date < dc.valid_to OR dc.valid_to IS NULL)
```
Bu sayede model, her bir işlem anında müşterinin o tarihteki gerçek durumunu (örneğin Ankara'daki halini ve o döneme ait segmentini) özellik olarak alır; gelecekteki değişen segmentini veya yeni şehrini geçmiş işlemlere yamamaz. SCD Type 2 versiyonlama mantığı ve zaman damgası eşleştirmesi olmadan kurulan ML boru hatları metodolojik olarak hatalıdır ve veri sızıntısının önüne geçilemez.
