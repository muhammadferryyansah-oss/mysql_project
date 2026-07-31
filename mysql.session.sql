

-- Cek jumlah data
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM products;

-- Lihat 5 data pertama
SELECT * FROM customers LIMIT 5;
SELECT * FROM orders LIMIT 5;
SELECT * FROM products LIMIT 5;

SELECT 
    COUNT(*) AS total_data,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS null_customer_name,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS null_email,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) AS null_phone
FROM customers;



SELECT
   COUNT(*) AS total_data,
    SUM(CASE WHEN category_name IS NULL THEN 1 ELSE 0 END) AS null_category_name,
    SUM(CASE WHEN parent_category_id IS NULL THEN 1 ELSE 0 END) AS null_parent_category,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS null_created_at
FROM categories;

SELECT 
    category_id,
    category_name,
    COALESCE(parent_category_id, 0) AS parent_id_fix,
    CASE 
        WHEN parent_category_id IS NULL THEN 'Root Category'
        ELSE 'Sub Category'
    END AS category_level
FROM categories;

-- Tampilkan kategori dan induknya
SELECT 
    child.category_name AS sub_category,
    parent.category_name AS parent_category
FROM categories child
LEFT JOIN categories parent ON child.parent_category_id = parent.category_id
WHERE child.parent_category_id IS NOT NULL;

-- Tampilkan hierarki kategori (parent-child)
SELECT 
    c1.category_name AS level_1,
    c2.category_name AS level_2,
    c3.category_name AS level_3
FROM categories c1
LEFT JOIN categories c2 ON c1.category_id = c2.parent_category_id
LEFT JOIN categories c3 ON c2.category_id = c3.parent_category_id
WHERE c1.parent_category_id IS NULL  -- Root
ORDER BY c1.category_name, c2.category_name, c3.category_name;


-- Analisis Kategori dengan NULL handling
SELECT 
    cat.category_name,
    COALESCE(parent.category_name, 'ROOT') AS parent_category,
    COUNT(p.product_id) AS total_products,
    COALESCE(SUM(oi.quantity * oi.price_at_time), 0) AS total_revenue
FROM categories cat
LEFT JOIN categories parent ON cat.parent_category_id = parent.category_id
LEFT JOIN products p ON cat.category_id = p.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status = 'delivered'
GROUP BY cat.category_id
ORDER BY total_revenue DESC;


-- laporan lengkap penjualan bulan ini

-- ============================================================
-- LAPORAN PENJUALAN BULAN INI (LENGKAP)
-- ============================================================

WITH 
-- 1. Data penjualan bulan ini
sales_this_month AS (
    SELECT 
        o.order_id,
        o.total_amount,
        oi.product_id,
        oi.quantity,
        oi.price_at_time,
        oi.quantity * oi.price_at_time AS revenue_per_item
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'delivered'
      AND MONTH(o.order_date) = MONTH(CURRENT_DATE)
      AND YEAR(o.order_date) = YEAR(CURRENT_DATE)
),

-- 2. Summary penjualan bulan ini
summary AS (
    SELECT 
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value,
        SUM(quantity) AS total_items_sold
    FROM sales_this_month
),

-- 3. Top 5 produk terlaris bulan ini
top_products AS (
    SELECT 
        p.product_name,
        SUM(s.quantity) AS total_terjual,
        SUM(s.revenue_per_item) AS total_revenue_produk,
        RANK() OVER (ORDER BY SUM(s.revenue_per_item) DESC) AS rank_produk
    FROM sales_this_month s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.product_name
    ORDER BY total_revenue_produk DESC
    LIMIT 5
),

-- 4. Total penjualan bulan lalu (untuk perbandingan)
last_month_sales AS (
    SELECT 
        SUM(total_amount) AS total_revenue_last_month
    FROM orders
    WHERE status = 'delivered'
      AND MONTH(order_date) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH)
      AND YEAR(order_date) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH)
)

-- ============================================================
-- 5. GABUNGKAN SEMUA
-- ============================================================
SELECT 
    -- Summary
    (SELECT total_orders FROM summary) AS total_orders_bulan_ini,
    (SELECT total_revenue FROM summary) AS total_revenue_bulan_ini,
    (SELECT avg_order_value FROM summary) AS rata_rata_per_order,
    (SELECT total_items_sold FROM summary) AS total_barang_terjual,
    
    -- Growth (persentase perubahan dari bulan lalu)
    ROUND(
        ((SELECT total_revenue FROM summary) - 
         (SELECT total_revenue_last_month FROM last_month_sales)) / 
        NULLIF((SELECT total_revenue_last_month FROM last_month_sales), 0) * 100, 2
    ) AS growth_persen,
    
    -- Top 5 produk (di-concatenate jadi 1 kolom)
    (SELECT GROUP_CONCAT(
        CONCAT(rank_produk, '. ', product_name, ' (Rp', total_revenue_produk, ')') 
        SEPARATOR ' | '
    ) FROM top_products) AS top_5_produk_terlaris;