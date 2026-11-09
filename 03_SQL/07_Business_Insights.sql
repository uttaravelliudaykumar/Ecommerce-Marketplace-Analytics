-- Section 58: Executive Business Performance Summary

WITH sales_metrics AS (
    SELECT
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.price) AS total_revenue,
        COUNT(*) AS total_items_sold
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),
customer_metrics AS (
    SELECT
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
review_metrics AS (
    SELECT
        ROUND(AVG(review_score), 2) AS average_review_score
    FROM reviews
),
delivery_metrics AS (
    SELECT
        ROUND(
            AVG(EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_purchase_timestamp
            )) / 86400)::NUMERIC, 2
        ) AS average_delivery_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT
    sm.delivered_orders,
    sm.total_items_sold,
    cm.unique_customers,
    ROUND(sm.total_revenue, 2) AS total_revenue,
    ROUND(
        sm.total_revenue / NULLIF(sm.delivered_orders, 0), 2
    ) AS average_order_value,
    rm.average_review_score,
    dm.average_delivery_days
FROM sales_metrics sm
CROSS JOIN customer_metrics cm
CROSS JOIN review_metrics rm
CROSS JOIN delivery_metrics dm;


-- Section 59: Revenue Contribution by Customer Type

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spending
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customers'
            ELSE 'Repeat Customers'
        END AS customer_type,
        COUNT(*) AS total_customers,
        SUM(total_orders) AS total_orders,
        SUM(total_spending) AS total_revenue
    FROM customer_orders
    GROUP BY
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customers'
            ELSE 'Repeat Customers'
        END
)
SELECT
    customer_type,
    total_customers,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0), 2
    ) AS revenue_contribution_percentage
FROM customer_segments
ORDER BY total_revenue DESC;


-- Section 60: Delivery Performance and Customer Satisfaction

WITH delivery_reviews AS (
    SELECT
        r.review_score,
        CASE
            WHEN o.order_delivered_customer_date
                 < o.order_estimated_delivery_date
                THEN 'Early Delivery'
            WHEN o.order_delivered_customer_date
                 = o.order_estimated_delivery_date
                THEN 'On-Time Delivery'
            ELSE 'Late Delivery'
        END AS delivery_status
    FROM reviews r
    JOIN orders o
        ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    delivery_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS low_score_reviews,
    ROUND(
        COUNT(*) FILTER (WHERE review_score <= 2) * 100.0
        / NULLIF(COUNT(*), 0), 2
    ) AS low_score_percentage
FROM delivery_reviews
GROUP BY delivery_status
ORDER BY average_review_score DESC;


-- Section 61: Product Category Business Performance

WITH category_performance AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        COUNT(DISTINCT oi.product_id) AS unique_products,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS total_revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
),
category_reviews AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        AVG(r.review_score) AS average_review_score
    FROM reviews r
    JOIN orders o
        ON r.order_id = o.order_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
)
SELECT
    cp.product_category,
    cp.unique_products,
    cp.items_sold,
    ROUND(cp.total_revenue, 2) AS total_revenue,
    ROUND(cr.average_review_score, 2) AS average_review_score
FROM category_performance cp
LEFT JOIN category_reviews cr
    ON cp.product_category = cr.product_category
ORDER BY cp.total_revenue DESC;


-- Section 62: Top 10 Sellers' Revenue Contribution

WITH seller_revenue AS (
    SELECT
        s.seller_id,
        s.seller_state,
        SUM(oi.price) AS total_revenue
    FROM sellers s
    JOIN order_items oi
        ON s.seller_id = oi.seller_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id, s.seller_state
),
ranked_sellers AS (
    SELECT
        seller_id,
        seller_state,
        total_revenue,
        DENSE_RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS seller_rank
    FROM seller_revenue
)
SELECT
    seller_id,
    seller_state,
    seller_rank,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0), 2
    ) AS revenue_contribution_percentage
FROM ranked_sellers
WHERE seller_rank <= 10
ORDER BY seller_rank;


-- Section 63: Customer State Business Performance

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS average_order_value
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- Section 64: Payment Method Business Contribution

WITH payment_summary AS (
    SELECT
        payment_type,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(payment_value) AS total_payment_value
    FROM payments
    GROUP BY payment_type
)
SELECT
    payment_type,
    total_orders,
    ROUND(total_payment_value, 2) AS total_payment_value,
    ROUND(
        total_payment_value * 100.0
        / NULLIF(SUM(total_payment_value) OVER (), 0), 2
    ) AS payment_value_contribution_percentage,
    ROUND(
        total_orders * 100.0
        / NULLIF(SUM(total_orders) OVER (), 0), 2
    ) AS order_contribution_percentage
FROM payment_summary
ORDER BY total_payment_value DESC;