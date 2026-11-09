-- 1. Check total customers
SELECT COUNT(*) AS total_customers
FROM customers;

-- 2. Check total orders
SELECT COUNT(*) AS total_orders
FROM orders;

-- 3. Check total order items
SELECT COUNT(*) AS total_order_items
FROM order_items;

-- 4. Check total payment records
SELECT COUNT(*) AS total_payment_records
FROM payments;

-- 5. Check total reviews
SELECT COUNT(*) AS total_reviews
FROM reviews;

-- 6. Check total products
SELECT COUNT(*) AS total_products
FROM products;

-- 7. Check total sellers
SELECT COUNT(*) AS total_sellers
FROM sellers;

-- 8. Check total geolocation records
SELECT COUNT(*) AS total_geolocation_records
FROM geolocation;

-- 9. Check total product category translations
SELECT COUNT(*) AS total_categories
FROM category_translation;



--   status of our orders
SELECT
    order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- period does our dataset cover?

SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS latest_order_date,
    COUNT(*) AS total_orders
FROM orders;


--  payment methods 
SELECT
    payment_type,
    COUNT(*) AS payment_transactions,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


--- CUSTOMER LOCATIONS
SELECT
    customer_state,
    COUNT(*) AS customer_records,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers
GROUP BY customer_state
ORDER BY unique_customers DESC;


-- PRODUCT CATEGORY

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(*) AS total_products
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    )
ORDER BY total_products DESC;


-- REVIEW ANALYSIS

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_reviews
FROM reviews
GROUP BY review_score
ORDER BY review_score DESC;
