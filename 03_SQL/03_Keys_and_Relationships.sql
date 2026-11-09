--- Checking Duplicates values for primary keys
SELECT 'customers.customer_id' AS key_column,
       COUNT(*) AS duplicate_groups
FROM (
    SELECT customer_id
    FROM customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'orders.order_id', COUNT(*)
FROM (
    SELECT order_id FROM orders
    GROUP BY order_id HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'order_items composite key', COUNT(*)
FROM (
    SELECT order_id, order_item_id FROM order_items
    GROUP BY order_id, order_item_id
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'payments composite key', COUNT(*)
FROM (
    SELECT order_id, payment_sequential FROM payments
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'reviews.review_id', COUNT(*)
FROM (
    SELECT review_id FROM reviews
    GROUP BY review_id HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'products.product_id', COUNT(*)
FROM (
    SELECT product_id FROM products
    GROUP BY product_id HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'sellers.seller_id', COUNT(*)
FROM (
    SELECT seller_id FROM sellers
    GROUP BY seller_id HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'category_translation.product_category_name', COUNT(*)
FROM (
    SELECT product_category_name
    FROM category_translation
    GROUP BY product_category_name
    HAVING COUNT(*) > 1
) d;

-- Checking Missing values
SELECT 'customers.customer_id' AS key_column,
       COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_values
FROM customers

UNION ALL
SELECT 'orders.order_id',
       COUNT(*) FILTER (WHERE order_id IS NULL)
FROM orders

UNION ALL
SELECT 'order_items composite key',
       COUNT(*) FILTER (
           WHERE order_id IS NULL OR order_item_id IS NULL
       )
FROM order_items

UNION ALL
SELECT 'payments composite key',
       COUNT(*) FILTER (
           WHERE order_id IS NULL OR payment_sequential IS NULL
       )
FROM payments

UNION ALL
SELECT 'reviews.review_id',
       COUNT(*) FILTER (WHERE review_id IS NULL)
FROM reviews

UNION ALL
SELECT 'products.product_id',
       COUNT(*) FILTER (WHERE product_id IS NULL)
FROM products

UNION ALL
SELECT 'sellers.seller_id',
       COUNT(*) FILTER (WHERE seller_id IS NULL)
FROM sellers

UNION ALL
SELECT 'category_translation.product_category_name',
       COUNT(*) FILTER (WHERE product_category_name IS NULL)
FROM category_translation;

-- Foreignkey relationships
SELECT 'orders -> customers' AS relationship,
       COUNT(*) AS orphan_records
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 'order_items -> orders', COUNT(*)
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT 'order_items -> products', COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT 'order_items -> sellers', COUNT(*)
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL

SELECT 'payments -> orders', COUNT(*)
FROM payments p
LEFT JOIN orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT 'reviews -> orders', COUNT(*)
FROM reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- PRIMARY KEYS

ALTER TABLE customers
ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);

ALTER TABLE orders
ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);

ALTER TABLE order_items
ADD CONSTRAINT pk_order_items
PRIMARY KEY (order_id, order_item_id);

ALTER TABLE payments
ADD CONSTRAINT pk_payments
PRIMARY KEY (order_id, payment_sequential);

ALTER TABLE reviews
ADD CONSTRAINT pk_reviews
PRIMARY KEY (review_id, order_id);

ALTER TABLE products
ADD CONSTRAINT pk_products PRIMARY KEY (product_id);

ALTER TABLE sellers
ADD CONSTRAINT pk_sellers PRIMARY KEY (seller_id);

ALTER TABLE category_translation
ADD CONSTRAINT pk_category_translation
PRIMARY KEY (product_category_name);


-- FOREIGN KEYS

ALTER TABLE orders
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id)
REFERENCES products(product_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_sellers
FOREIGN KEY (seller_id)
REFERENCES sellers(seller_id);

ALTER TABLE payments
ADD CONSTRAINT fk_payments_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);

ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);


-- Verify  the constraints
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    contype AS constraint_type
FROM pg_constraint
WHERE contype IN ('p', 'f')
AND connamespace = 'public'::regnamespace
ORDER BY table_name, constraint_type;

