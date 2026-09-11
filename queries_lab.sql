-- ==========================================
-- SENARYO 5 (SONRASI): Sadece Sondan Joker Karakter (Prefix Arama)
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

EXPLAIN ANALYZE
SELECT id, status, total_amount
FROM orders
WHERE status LIKE 'pend%';