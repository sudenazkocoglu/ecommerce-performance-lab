-- Soru 10 OLTP
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE(created_at) AS siparis_tarihi, AVG(total_amount) AS gunluk_ortalama 
FROM orders GROUP BY DATE(created_at) ORDER BY siparis_tarihi;

-- Soru 10 STAR
EXPLAIN (ANALYZE, BUFFERS)
SELECT dd.full_date, AVG(fo.total_amount) AS gunluk_ortalama 
FROM fct_orders fo JOIN dim_date dd ON fo.date_key = dd.date_key 
GROUP BY dd.full_date ORDER BY dd.full_date;