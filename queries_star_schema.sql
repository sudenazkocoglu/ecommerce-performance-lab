-- =====================================================================
-- ÖDEV 3.4 — ANALİTİK KATMAN (STAR SCHEMA) DDL VE GRAIN TANIMLARI
-- =====================================================================

-- 1. dim_date (Tarih Boyutu)
-- Grain: Her bir takvim günü (1 satır = 1 gün)
CREATE TABLE IF NOT EXISTS dim_date (
    date_key INT PRIMARY KEY, -- Örn: 20260601
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    day INT NOT NULL,
    day_of_week INT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

-- 2. dim_customer (Müşteri Boyutu - SCD Type 2)
-- Grain: Müşterinin her bir versiyonu / unvan veya adres değişiklik dönemi (1 satır = Müşteri versiyonu)
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key SERIAL PRIMARY KEY, -- Surrogate Key
    customer_id INT NOT NULL,        -- Natural / OLTP Key
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(150),
    city VARCHAR(100),
    -- SCD2 Alanları
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,
    is_current BOOLEAN NOT NULL
);

-- 3. dim_product (Ürün Boyutu)
-- Grain: Ürünün kendisi (1 satır = 1 benzersiz ürün)
CREATE TABLE IF NOT EXISTS dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    product_name VARCHAR(150),
    category VARCHAR(100),
    unit_price NUMERIC(10, 2)
);

-- 4. fct_orders (Siparişler Gerçeklik Tablosu)
-- Grain: Müşterinin verdiği her bir tekil sipariş (1 satır = 1 sipariş başlığı)
CREATE TABLE IF NOT EXISTS fct_orders (
    order_id INT PRIMARY KEY,
    customer_key INT REFERENCES dim_customer(customer_key),
    date_key INT REFERENCES dim_date(date_key),
    status VARCHAR(50),
    total_amount NUMERIC(12, 2)
);

-- 5. fct_order_items (Sipariş Kalemleri Gerçeklik Tablosu)
-- Grain: Sipariş içindeki her bir ürün kalemi (1 satır = Bir siparişteki bir ürün kalemi)
CREATE TABLE IF NOT EXISTS fct_order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES fct_orders(order_id),
    product_key INT REFERENCES dim_product(product_key),
    quantity INT NOT NULL,
    unit_price NUMERIC(10, 2),
    line_total NUMERIC(12, 2)
);

-- =====================================================================
-- IDEMPOTENT ETL YÜKLEME VE SCD TYPE 2 TESTLERİ
-- =====================================================================

-- 1. dim_date Yükleme (Idempotent: Tekrar çalıştırıldığında hata vermez/çakışmaz)
INSERT INTO dim_date (date_key, full_date, year, quarter, month, day, day_of_week, is_weekend)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    EXTRACT(DAY FROM d)::INT,
    EXTRACT(ISODOW FROM d)::INT,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE ELSE FALSE END
FROM GENERATE_SERIES('2025-01-01'::DATE, '2026-12-31'::DATE, INTERVAL '1 day') AS t(d)
ON CONFLICT (date_key) DO NOTHING;


-- =====================================================================
-- 2. dim_customer (Müşteriler) Idempotent Yükleme (City alanı NULL olarak ayarlandı)
-- =====================================================================
INSERT INTO dim_customer (customer_id, first_name, last_name, email, city, valid_from, valid_to, is_current)
SELECT 
    id, first_name, last_name, email, NULL, 
    created_at, NULL, TRUE
FROM users
WHERE NOT EXISTS (
    SELECT 1 FROM dim_customer dp WHERE dp.customer_id = users.id
);


-- =====================================================================
-- 3. dim_product (Ürünler) Idempotent Yükleme (Category alanı NULL olarak ayarlandı)
-- =====================================================================
INSERT INTO dim_product (product_id, product_name, category, unit_price)
SELECT id, name, NULL, price
FROM products
WHERE NOT EXISTS (
    SELECT 1 FROM dim_product dp WHERE dp.product_id = products.id
);

-- =====================================================================
-- 4. fct_orders (Siparişler) Idempotent Yükleme
-- =====================================================================
INSERT INTO fct_orders (order_id, customer_key, date_key, status, total_amount)
SELECT 
    o.id AS order_id,
    dc.customer_key,
    TO_CHAR(o.created_at, 'YYYYMMDD')::INT AS date_key,
    o.status,
    o.total_amount
FROM orders o
JOIN dim_customer dc ON o.user_id = dc.customer_id AND dc.is_current = TRUE
ON CONFLICT (order_id) DO NOTHING;

-- =====================================================================
-- 5. fct_order_items (Sipariş Kalemleri) Idempotent Yükleme
-- =====================================================================
INSERT INTO fct_order_items (order_id, product_key, quantity, unit_price, line_total)
SELECT 
    oi.order_id,
    dp.product_key,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS line_total
FROM order_items oi
JOIN dim_product dp ON oi.product_id = dp.product_id
WHERE NOT EXISTS (
    SELECT 1 FROM fct_order_items foi 
    WHERE foi.order_id = oi.order_id AND foi.product_key = dp.product_key
);