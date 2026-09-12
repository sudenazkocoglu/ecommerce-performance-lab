# Ödev 3.7 — Kontrol Soruları Raporu

## 1. LEFT JOIN Sonrası WHERE b.col IS NOT NULL Yazmak Ne Yapar, INNER JOIN'den Farkı Nedir?
LEFT JOIN, sol tablodaki tüm kayıtları getirir; sağ tabloda eşleşen kayıt varsa onları ekler, eşleşme yoksa sağ tablo kolonlarına NULL basar. Bu işlemin ardından WHERE b.col IS NOT NULL koşulunu eklemek, sağ tablodan eşleşme gelmeyen (yani sağ tarafı NULL olan) tüm sol tablo satırlarını filtreden geçirerek eler.

Davranışsal Farkı: Sonuç kümesindeki satırlar açısından bakıldığında, eşleşmeyen kayıtlar elendiği için bu sorgu mantıksal olarak bir INNER JOIN gibi çalışır.

Mimarî ve Plan Farkı: Bazı veri tabanı sorgu optimizatörleri (query optimizer), LEFT JOIN yazıp arkasından IS NOT NULL filtresi konulduğunda execution plan'ı (çalışma planını) otomatik olarak INNER JOIN planına dönüştürebilir. Ancak yazım mantığı ve okunabilirlik açısından, sağ tablonun mutlaka eşleşmesi bekleniyorsa doğrudan INNER JOIN kullanmak en doğru yaklaşımdır.

## 2. NOT IN Bir Alt Sorguda NULL Varsa Ne Olur? Neden?
Alt sorgunun döndürdüğü sonuç kümesinde tek bir tane bile NULL değeri varsa, ana sorgu geriye hiçbir satır döndürmez (0 satır döner).

Neden?: SQL üçlü mantık (three-valued logic) sistemine dayanır (TRUE, FALSE, UNKNOWN). NOT IN operatörü aslında arka planda AND bağlacıyla birbirine bağlanmış eşit değildir (!=) kontrollerine dönüşür:
WHERE col NOT IN (1, 2, NULL) ifadesi şu mantığa açılır:
WHERE (col != 1) AND (col != 2) AND (col != NULL)
SQL'de herhangi bir değerin NULL ile karşılaştırması (col != NULL) her zaman UNKNOWN (bilinmeyen) sonuç verir. AND zincirinde bir tane bile UNKNOWN olduğunda ve diğer şartlar sağlansa bile mantıksal sonuç UNKNOWN olur. WHERE filtresi yalnızca TRUE olan satırları kabul ettiği için hiçbir satır geçemez. Bu tehlikeyi önlemek için NOT EXISTS veya LEFT JOIN ... WHERE ... IS NULL kalıpları tercih edilmelidir.

## 3. COUNT(*) ile COUNT(column) Farkı Hangi Durumda Tehlikeli Sonuç Verir?
COUNT(*): Tablodaki toplam satır sayısını (hiçbir kolona bakmaksızın) sayar. Satırın içinde NULL değerler olması sayımı etkilemez.

COUNT(column): Belirtilen sütunda NULL olmayan satır sayısını sayar. Sütun içerisindeki NULL değerleri tamamen yok sayar.

Tehlikeli Olduğu Durum: Tabloda NULL (boş bırakılabilir) olabilen bir sütun üzerinden toplam kayıt veya varlık sayısı hesaplanmaya çalışıldığında tehlikelidir. Örneğin, bir sipariş tablosunda iptal edilen veya kargo firması henüz atanmamış siparişlerin shipping_company_id kolonu NULL olabilir. SELECT COUNT(shipping_company_id) FROM orders sorgusunu çalıştırdığınızda, sistem size toplam sipariş sayısını değil, yalnızca kargo firması atanmış sipariş sayısını verir. Boş değerler atlandığı için eksik ve yanlış analitik metrikler üretilir, finansal veya operasyonel raporlar hatalı çıkar.

## 4. Bir Join Sonucunda Satır Sayım Beklenenden 3 Kat Fazla — Hangi 3 Şeyi Kontrol Ederim?
Bir birleştirme (join) işleminde veri miktarının katlanarak artması "Row Explosion" (Satır Patlaması) olarak adlandırılır. Bu durumda sırasıyla şu 3 temel nokta kontrol edilmelidir:

Çoğul-Çoğul (Many-to-Many) İlişki ve Duplicate (Mükerrer) Anahtarlar: Join yapılan sütunların her iki tabloda da tekil (unique / primary key) olup olmadığı kontrol edilir. Örneğin, müşteri tablosunda veya ürün tablosunda aynı ID'ye sahip birden fazla mükerrer satır varsa, tablolar birleştiğinde kombinasyon oluşturarak satır sayısını katlar.

Eksik veya Hatalı Join Koşulları (Cartesian Product Riski): ON koşulunun eksik yazılması, unutulması ya da yanlış anahtar kolonların (id yerine yanlış bir alanın) birbiriyle eşleştirilmesi sonucu tabloların birbirleriyle çapraz (cross join) çarpılıp çarpılmadığı incelenir.

SCD Type 2 Versiyon Çakışmaları ve Tarih Aralıkları: Eğer sorguda versiyonlu bir boyut tablosu (dim_customer vb.) kullanılıyorsa, is_current = TRUE filtresinin unutulması veya tarih aralığı koşullarının (valid_from / valid_to) dar tutulmaması nedeniyle aynı müşterinin birden fazla geçmiş versiyonunun işlemlerle eşleşip eşleşmediği kontrol edilir.

## 5. Window Function ile GROUP BY Arasındaki Temel Fark Nedir?
GROUP BY (Gruplama): Birden fazla satırı gruplayarak tek bir özet satıra indirger. Sonuç kümesindeki toplam satır sayısını azaltır (her grup için 1 satır döner). Gruplanan satırların detaylarına (orijinal satır kimliklerine) GROUP BY sonrasında doğrudan erişilemez.

Window Functions (OVER()): Satırlar üzerinde kümülatif toplam, sıralama (ROW_NUMBER, RANK) veya hareketli ortalama gibi hesaplamalar yapar; ancak tablo yapısını ve satır bütünlüğünü bozmaz/azaltmaz. Sonuç kümesindeki toplam satır sayısı korunur; her orijinal satır kendi kimliğini korurken yanına hesaplanan analitik metrik sütun olarak eklenir.

## 6. Bir Tabloya Index Eklemenin Maliyeti Nedir? (Sadece Faydasını Sayma)
Index'ler sorgu okuma hızını artırırken sisteme şu üç temel maliyeti yükler:

Yazma Performans Düşüşü (Write / Modification Overhead): Tabloya her INSERT, UPDATE veya DELETE işlemi yapıldığında, verinin yanı sıra index yapısının da (genellikle B-Tree ağacının) güncellenmesi gerekir. Bu durum yazma işlemlerini yavaşlatır (Write Amplification).

Disk Alanı Maliyeti (Storage Overhead): Index'ler verinin fiziksel kopyaları veya türetilmiş sıralı yapıları olduğundan disk üzerinde ek yer kaplar. Büyük tablolarda index'lerin toplam boyutu tablonun kendi boyutuna yaklaşabilir veya onu geçebilir.

Bakım ve Optimizasyon Yükü: Zamanla veri değiştikçe index'lerde parçalanma (fragmentation) oluşur. Bu durum, index'lerin düzenli olarak yeniden oluşturulmasını (REBUILD / REORGANIZE) gerektirir. Ayrıca sorgu planlayıcısı (optimizer) her sorgu için en iyi index'i hesaplarken ek CPU maliyeti harcar.