-- Adım 3: Kanıtı görmek için müşteriyi sorguluyoruz
SELECT customer_id, first_name, city, is_current, valid_from, valid_to 
FROM dim_customer 
WHERE customer_id = 1;