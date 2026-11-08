-- Overall Sales Performance

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_order_items,
    ROUND(SUM(price), 2) AS product_revenue,
    ROUND(SUM(freight_value), 2) AS total_freight,
    ROUND(SUM(price + freight_value), 2) AS total_sales_value,
    ROUND(AVG(price), 2) AS average_item_price
FROM order_items;

-- Delivered Sales Performance

SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(*) AS delivered_order_items,
    ROUND(SUM(oi.price), 2) AS delivered_product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS delivered_freight,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS delivered_sales_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- Monthly Revenue Trend

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS monthly_revenue,
    ROUND(SUM(oi.freight_value), 2) AS monthly_freight
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY sales_month;

-- Average Order Value

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price), 2) AS total_product_revenue,
    ROUND(
        SUM(price) / COUNT(DISTINCT order_id),
        2
    ) AS average_order_value
FROM order_items
WHERE order_id IN (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
);


-- Revenue by Product Category

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS category_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    )
ORDER BY category_revenue DESC
LIMIT 10;


-- Top 10 Products by Revenue

SELECT
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    p.product_category_name,
    ct.product_category_name_english
ORDER BY product_revenue DESC
LIMIT 10;


-- Top 10 Sellers by Revenue

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS seller_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY seller_revenue DESC
LIMIT 10;


-- Overall Customer Performance

SELECT
    COUNT(*) AS total_customer_records,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(DISTINCT customer_city) AS customer_cities,
    COUNT(DISTINCT customer_state) AS customer_states
FROM customers;


-- One-Time vs Repeat Customers

SELECT
    CASE
        WHEN customer_order_count = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,
    COUNT(*) AS total_customers
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS customer_order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) customer_orders
GROUP BY
    CASE
        WHEN customer_order_count = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END
ORDER BY total_customers DESC;

-- Customer Repeat Purchase Rate

SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE customer_order_count > 1
    ) AS repeat_customers,
    ROUND(
        COUNT(*) FILTER (
            WHERE customer_order_count > 1
        ) * 100.0 / COUNT(*),
        2
    ) AS repeat_purchase_rate_percentage
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS customer_order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) customer_orders;

-- Average Orders Per Customer

SELECT
    COUNT(*) AS total_customers,
    ROUND(AVG(customer_order_count), 2) AS average_orders_per_customer,
    MAX(customer_order_count) AS maximum_orders_by_customer
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS customer_order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) customer_orders;

-- Customer Distribution by State

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY unique_customers DESC;


-- Top 10 Customers by Spending

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_product_spending
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_product_spending DESC
LIMIT 10;

-- Average Customer Spending

SELECT
    COUNT(*) AS customers_with_delivered_orders,
    ROUND(AVG(customer_spending), 2) AS average_customer_spending
FROM (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS customer_spending
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) customer_revenue;

-- Monthly Customer Acquisition

SELECT
    DATE_TRUNC('month', first_order_date)::DATE AS acquisition_month,
    COUNT(*) AS new_customers
FROM (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) first_purchases
GROUP BY DATE_TRUNC('month', first_order_date)
ORDER BY acquisition_month;


-- Overall Product Performance

SELECT
    COUNT(DISTINCT oi.product_id) AS total_products,
    COUNT(*) AS total_items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS average_product_price
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Product Category Performance

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(DISTINCT oi.product_id) AS unique_products,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS category_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    )
ORDER BY category_revenue DESC;

-- Top 10 Categories by Quantity Sold

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(*) AS total_items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    )
ORDER BY total_items_sold DESC
LIMIT 10;

-- Top 10 Products by Quantity Sold

SELECT
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(*) AS quantity_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    p.product_category_name,
    ct.product_category_name_english
ORDER BY quantity_sold DESC
LIMIT 10;


-- Top 10 Products by Revenue

SELECT
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category,
    COUNT(*) AS quantity_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS average_selling_price
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    p.product_category_name,
    ct.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

-- Product Price Range Analysis

SELECT
    CASE
        WHEN price < 50 THEN 'Below R$50'
        WHEN price < 100 THEN 'R$50 - R$99'
        WHEN price < 250 THEN 'R$100 - R$249'
        WHEN price < 500 THEN 'R$250 - R$499'
        ELSE 'R$500 and Above'
    END AS price_range,
    COUNT(*) AS items_sold,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(AVG(price), 2) AS average_price
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    CASE
        WHEN price < 50 THEN 'Below R$50'
        WHEN price < 100 THEN 'R$50 - R$99'
        WHEN price < 250 THEN 'R$100 - R$249'
        WHEN price < 500 THEN 'R$250 - R$499'
        ELSE 'R$500 and Above'
    END
ORDER BY MIN(price);

-- Products Never Sold

SELECT
    p.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name
    ) AS product_category
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
LEFT JOIN order_items oi
    ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL
ORDER BY product_category;
-- Section 23: Overall Seller Performance

SELECT
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN s.seller_id END) AS sellers_with_delivered_sales,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN oi.order_id END) AS total_delivered_orders,
    COUNT(CASE WHEN o.order_status = 'delivered' THEN 1 END) AS total_items_sold,
    ROUND(SUM(CASE WHEN o.order_status = 'delivered' THEN oi.price ELSE 0 END), 2) AS total_revenue
FROM sellers s
LEFT JOIN order_items oi
    ON s.seller_id = oi.seller_id
LEFT JOIN orders o
    ON oi.order_id = o.order_id;


-- Section 24: Seller Revenue by State

SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY total_revenue DESC;


-- Section 25: Top 10 Sellers by Items Sold

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(*) AS total_items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_items_sold DESC
LIMIT 10;


-- Section 26: Seller Average Item Price

SELECT
    s.seller_id,
    s.seller_city,
    COUNT(*) AS total_items_sold,
    ROUND(AVG(oi.price), 2) AS average_item_price,
    ROUND(MIN(oi.price), 2) AS minimum_item_price,
    ROUND(MAX(oi.price), 2) AS maximum_item_price
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city
ORDER BY average_item_price DESC;


-- Section 27: Seller Product Diversity

SELECT
    s.seller_id,
    s.seller_city,
    COUNT(DISTINCT oi.product_id) AS unique_products_sold,
    COUNT(DISTINCT p.product_category_name) AS unique_categories_sold,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city
ORDER BY unique_products_sold DESC;


-- Section 28: Sellers Without Delivered Sales

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state
FROM sellers s
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE oi.seller_id = s.seller_id
      AND o.order_status = 'delivered'
)
ORDER BY s.seller_state, s.seller_city;
-- Section 29: Overall Delivery Performance

SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,
    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
    ) AS canceled_orders,
    ROUND(
        COUNT(*) FILTER (WHERE order_status = 'delivered') * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) AS delivery_success_percentage
FROM orders;


-- Section 30: Average Delivery Time

SELECT
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_purchase_timestamp
        )) / 86400)::NUMERIC, 2
    ) AS average_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- Section 31: Estimated vs Actual Delivery Time

SELECT
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            order_estimated_delivery_date - order_purchase_timestamp
        )) / 86400)::NUMERIC, 2
    ) AS average_estimated_delivery_days,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_purchase_timestamp
        )) / 86400)::NUMERIC, 2
    ) AS average_actual_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- Section 32: Early, On-Time and Late Deliveries

SELECT
    CASE
        WHEN order_delivered_customer_date < order_estimated_delivery_date
            THEN 'Early Delivery'
        WHEN order_delivered_customer_date = order_estimated_delivery_date
            THEN 'On-Time Delivery'
        ELSE 'Late Delivery'
    END AS delivery_status,
    COUNT(*) AS total_orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS percentage
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY total_orders DESC;


-- Section 33: Average Delivery Time by Customer State

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400)::NUMERIC, 2
    ) AS average_delivery_days
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY average_delivery_days DESC;


-- Section 34: Average Delivery Time by Seller State

SELECT
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400)::NUMERIC, 2
    ) AS average_delivery_days
FROM order_items oi
JOIN sellers s
    ON oi.seller_id = s.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_state
ORDER BY average_delivery_days DESC;


-- Section 35: Average Carrier Handover Time

SELECT
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 86400)::NUMERIC, 2
    ) AS average_carrier_handover_days
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL;
  
-- Section 36: Overall Payment Performance

SELECT
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT payment_type) AS payment_methods,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments;


-- Section 37: Payment Method Performance

SELECT
    payment_type,
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- Section 38: Payment Installment Analysis

SELECT
    payment_installments,
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
GROUP BY payment_installments
ORDER BY payment_installments;


-- Section 39: Monthly Payment Trend

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
    COUNT(DISTINCT p.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value,
    ROUND(AVG(p.payment_value), 2) AS average_payment_record_value
FROM payments p
JOIN orders o
    ON p.order_id = o.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY order_month;


-- Section 40: Payment Method by Order Status

SELECT
    o.order_status,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value
FROM payments p
JOIN orders o
    ON p.order_id = o.order_id
GROUP BY o.order_status, p.payment_type
ORDER BY o.order_status, total_payment_value DESC;


-- Section 41: Orders Using Multiple Payment Records

SELECT
    order_id,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT payment_type) AS different_payment_methods,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_records DESC, total_payment_value DESC
LIMIT 20;


-- Section 42: Payment Value Distribution

SELECT
    CASE
        WHEN payment_value < 50 THEN 'Below R$50'
        WHEN payment_value < 100 THEN 'R$50 - R$99'
        WHEN payment_value < 250 THEN 'R$100 - R$249'
        WHEN payment_value < 500 THEN 'R$250 - R$499'
        ELSE 'R$500 and Above'
    END AS payment_value_range,
    COUNT(*) AS total_payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
GROUP BY
    CASE
        WHEN payment_value < 50 THEN 'Below R$50'
        WHEN payment_value < 100 THEN 'R$50 - R$99'
        WHEN payment_value < 250 THEN 'R$100 - R$249'
        WHEN payment_value < 500 THEN 'R$250 - R$499'
        ELSE 'R$500 and Above'
    END
ORDER BY MIN(payment_value);

-- Section 43: Overall Customer Review Performance

SELECT
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score,
    COUNT(*) FILTER (WHERE review_score = 5) AS five_star_reviews,
    COUNT(*) FILTER (WHERE review_score = 1) AS one_star_reviews,
    ROUND(
        COUNT(*) FILTER (WHERE review_score >= 4) * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) AS positive_review_percentage
FROM reviews;


-- Section 44: Review Score Distribution

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS review_percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score DESC;


-- Section 45: Monthly Review Trend

SELECT
    DATE_TRUNC('month', review_creation_date)::DATE AS review_month,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM reviews
WHERE review_creation_date IS NOT NULL
GROUP BY DATE_TRUNC('month', review_creation_date)
ORDER BY review_month;


-- Section 46: Review Response Time Analysis

SELECT
    COUNT(*) AS reviews_with_response,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (
            review_answer_timestamp - review_creation_date
        )) / 86400)::NUMERIC, 2
    ) AS average_response_days,
    ROUND(
        MIN(EXTRACT(EPOCH FROM (
            review_answer_timestamp - review_creation_date
        )) / 86400)::NUMERIC, 2
    ) AS minimum_response_days,
    ROUND(
        MAX(EXTRACT(EPOCH FROM (
            review_answer_timestamp - review_creation_date
        )) / 86400)::NUMERIC, 2
    ) AS maximum_response_days
FROM reviews
WHERE review_creation_date IS NOT NULL
  AND review_answer_timestamp IS NOT NULL;


-- Section 47: Reviews With and Without Comments

SELECT
    CASE
        WHEN review_comment_message IS NOT NULL
             AND TRIM(review_comment_message) <> ''
            THEN 'With Comment'
        ELSE 'Without Comment'
    END AS comment_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM reviews
GROUP BY comment_status
ORDER BY total_reviews DESC;


-- Section 48: Review Scores by Delivery Performance

SELECT
    CASE
        WHEN o.order_delivered_customer_date < o.order_estimated_delivery_date
            THEN 'Early Delivery'
        WHEN o.order_delivered_customer_date = o.order_estimated_delivery_date
            THEN 'On-Time Delivery'
        ELSE 'Late Delivery'
    END AS delivery_performance,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM reviews r
JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- Section 49: Review Scores by Product Category

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(DISTINCT r.order_id) AS reviewed_orders,
    COUNT(*) AS review_item_category_records,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM reviews r
JOIN order_items oi
    ON r.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
GROUP BY product_category
ORDER BY average_review_score DESC;