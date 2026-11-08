-- Section 50: Monthly Revenue Growth Analysis

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
revenue_comparison AS (
    SELECT
        order_month,
        total_revenue,
        LAG(total_revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    order_month,
    ROUND(total_revenue, 2) AS current_month_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        total_revenue - previous_month_revenue, 2
    ) AS revenue_difference,
    ROUND(
        (total_revenue - previous_month_revenue)
        * 100.0 / NULLIF(previous_month_revenue, 0), 2
    ) AS revenue_growth_percentage
FROM revenue_comparison
ORDER BY order_month;


-- Section 51: Cumulative Monthly Revenue

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
        SUM(oi.price) AS monthly_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    order_month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY order_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY order_month;


-- Section 52: Product Category Revenue Contribution

WITH category_revenue AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
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
)
SELECT
    product_category,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0), 2
    ) AS revenue_contribution_percentage,
    DENSE_RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank
FROM category_revenue
ORDER BY revenue_rank;


-- Section 53: Customer RFM-Based Segmentation

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spending,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        MAX(MAX(o.order_purchase_timestamp)) OVER () AS dataset_reference_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_rfm AS (
    SELECT
        customer_unique_id,
        total_orders,
        total_spending,
        EXTRACT(
            DAY FROM (dataset_reference_date - last_purchase_date)
        ) AS recency_days
    FROM customer_metrics
)
SELECT
    customer_unique_id,
    total_orders,
    ROUND(total_spending, 2) AS total_spending,
    recency_days,
    CASE
        WHEN recency_days <= 90 AND total_orders >= 2
            THEN 'Active Repeat Customer'
        WHEN recency_days <= 90 AND total_orders = 1
            THEN 'Recent One-Time Customer'
        WHEN recency_days > 180 AND total_orders >= 2
            THEN 'Inactive Repeat Customer'
        WHEN recency_days > 180
            THEN 'Inactive One-Time Customer'
        ELSE 'Other Customers'
    END AS customer_segment
FROM customer_rfm
ORDER BY total_spending DESC;


-- Section 54: Monthly Top 3 Product Categories

WITH monthly_category_sales AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        DATE_TRUNC('month', o.order_purchase_timestamp),
        product_category
),
category_ranking AS (
    SELECT
        order_month,
        product_category,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY order_month
            ORDER BY total_revenue DESC
        ) AS category_rank
    FROM monthly_category_sales
)
SELECT
    order_month,
    product_category,
    ROUND(total_revenue, 2) AS total_revenue,
    category_rank
FROM category_ranking
WHERE category_rank <= 3
ORDER BY order_month, category_rank;


-- Section 55: Seller Ranking Within Each State

WITH seller_revenue AS (
    SELECT
        s.seller_id,
        s.seller_state,
        s.seller_city,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.price) AS total_revenue
    FROM sellers s
    JOIN order_items oi
        ON s.seller_id = oi.seller_id
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        s.seller_id,
        s.seller_state,
        s.seller_city
)
SELECT
    seller_state,
    seller_id,
    seller_city,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    DENSE_RANK() OVER (
        PARTITION BY seller_state
        ORDER BY total_revenue DESC
    ) AS seller_state_rank
FROM seller_revenue
ORDER BY seller_state, seller_state_rank;


-- Section 56: Delivery Delay Category Analysis

WITH delivery_data AS (
    SELECT
        order_id,
        EXTRACT(
            DAY FROM (
                order_delivered_customer_date
                - order_estimated_delivery_date
            )
        ) AS delivery_delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE
        WHEN delivery_delay_days < 0
            THEN 'Early Delivery'
        WHEN delivery_delay_days = 0
            THEN 'On-Time Delivery'
        WHEN delivery_delay_days BETWEEN 1 AND 3
            THEN 'Late by 1-3 Days'
        WHEN delivery_delay_days BETWEEN 4 AND 7
            THEN 'Late by 4-7 Days'
        ELSE 'Late by More Than 7 Days'
    END AS delivery_delay_category,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_delay_days), 2) AS average_delay_days
FROM delivery_data
GROUP BY delivery_delay_category
ORDER BY total_orders DESC;


-- Section 57: Payment Method Revenue Contribution

WITH payment_summary AS (
    SELECT
        payment_type,
        SUM(payment_value) AS total_payment_value,
        COUNT(DISTINCT order_id) AS total_orders
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
    ) AS payment_contribution_percentage,
    DENSE_RANK() OVER (
        ORDER BY total_payment_value DESC
    ) AS payment_method_rank
FROM payment_summary
ORDER BY payment_method_rank;