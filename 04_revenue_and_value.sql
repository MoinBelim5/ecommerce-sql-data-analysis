

-- SECTION 4 : REVENUE & VALUE MATRICS

-- OBJECTIVE: Measure order-level profitability and growth.

-- ===========================================================================================================================================

-- Problem 1: What is the average order value (AOV) for repeat customers vs one-time customers?
----------------------------------------------------------------------------------------------------------------------------------------------
USE Olist_Ecommerce;
WITH order_value AS (
    SELECT
        cu.customer_unique_id,
        o.order_id,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_customers_dataset cu
        ON o.customer_id = cu.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        cu.customer_unique_id,
        o.order_id
),

customer_segment AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN COUNT(order_id) > 1 THEN 'Repeat Customer'
            ELSE 'One-Time Customer'
        END AS customer_segment
    FROM order_value
    GROUP BY customer_unique_id
)

SELECT
    cs.customer_segment,
    ROUND(AVG(ov.order_total), 2) AS AOV
FROM order_value ov
JOIN customer_segment cs
    ON ov.customer_unique_id = cs.customer_unique_id
GROUP BY
    cs.customer_segment;

-- Insight:
-- One-time customers have a slightly higher AOV (160.73) compared to repeat customers (145.95).
-- this suggests repeat customers purchase more frequently but tend to spend slightly less per order.
-- revenue growth from repeat customers is therefore driven by frequency, not higher basket size.

-- ===========================================================================================================================================

-- Problem 2: Which sellers have the highest AOV from repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH order_value AS (
    SELECT
        o.order_id,
        cu.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_customers_dataset cu
        ON o.customer_id = cu.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        cu.customer_unique_id
),

repeat_customers AS (
    SELECT customer_unique_id
    FROM order_value
    GROUP BY customer_unique_id
    HAVING COUNT(order_id) > 1
)

SELECT
    oi.seller_id,
    ROUND(AVG(ov.order_total), 2) AS AOV_from_repeat_customers
FROM order_value ov
JOIN repeat_customers rc
    ON ov.customer_unique_id = rc.customer_unique_id
JOIN olist_order_items_dataset oi
    ON ov.order_id = oi.order_id
GROUP BY
    oi.seller_id
ORDER BY
    AOV_from_repeat_customers DESC;

-- Insight:
-- -- Insight:
-- A few sellers show extremely high AOV from repeat customers, indicating premium or bulk purchases.
-- However, most sellers have moderate AOV, suggesting repeat customers generally buy smaller baskets.
-- This highlights that high-value repeat behavior is concentrated among specific sellers, not evenly distributed.

-- ===========================================================================================================================================

-- Problem 3: Which product categories have the highest Average order value (AOV) from repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH order_value AS (
    SELECT
        o.order_id,
        cu.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_customers_dataset cu
        ON o.customer_id = cu.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        cu.customer_unique_id
),

order_category AS (
    SELECT DISTINCT
        o.order_id,
        pc.product_category_name_english AS product_category
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_products_dataset pr
        ON oi.product_id = pr.product_id
    JOIN product_category_name_translation pc
        ON pr.product_category_name = pc.product_category_name
),

repeat_customers AS (
    SELECT
        customer_unique_id
    FROM order_value
    GROUP BY customer_unique_id
    HAVING COUNT(order_id) > 1
)

SELECT
    oc.product_category,
    ROUND(AVG(ov.order_total), 2) AS AOV_from_repeat_customers
FROM order_value ov
JOIN repeat_customers rc
    ON ov.customer_unique_id = rc.customer_unique_id
JOIN order_category oc
    ON ov.order_id = oc.order_id
GROUP BY
    oc.product_category
ORDER BY
    AOV_from_repeat_customers DESC;

-- Insight:
-- Categories like Computers and Small Appliances have the highest AOV from repeat customers.
-- This suggests repeat buyers spend more per order in high-value and durable product categories.
-- Lower AOV categories (like books or small household items) indicate more frequent but smaller purchases.

-- ===========================================================================================================================================

-- Problem 4: Running revenue over time(Cumulative revenue)
----------------------------------------------------------------------------------------------------------------------------------------------
WITH daily_revenue AS (
    SELECT
        CAST(o.order_purchase_timestamp AS DATE) AS order_date,
        ROUND(SUM(oi.price + oi.freight_value),2) AS revenue
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE 
        o.order_status = 'delivered'
    GROUP BY
        CAST(o.order_purchase_timestamp AS DATE)
)
SELECT
    order_date,
    revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS cumulative_revenue
FROM daily_revenue
ORDER BY
    order_date;

-- Insight:
-- Revenue shows a steady upward cumulative trend over time, indicating consistent business growth.
-- There are visible spikes on certain days, suggesting seasonal demand or promotional impact.
-- Overall, the platform demonstrates strong revenue accumulation with no major long-term decline.

-- ===========================================================================================================================================

-- Problem 5: Which payment methods generate the most revenue?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH payment_summary AS (
    SELECT
        op.payment_type,
        SUM(op.payment_value) AS total_revenue,
        COUNT(DISTINCT op.order_id) AS total_orders
    FROM olist_orders_dataset o
    JOIN olist_order_payments_dataset op
        ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY op.payment_type
)

SELECT
    payment_type,
    ROUND(total_revenue, 2) AS total_revenue,
    total_orders,

    ROUND(
        total_revenue * 100.0 
        / SUM(total_revenue) OVER (),
        2
    ) AS revenue_share_percent

FROM payment_summary
ORDER BY total_revenue DESC;

-- Insight:
-- Credit cards dominate revenue, contributing ~78.5% of total revenue (₹12M+ from 74K orders), making it the primary payment driver.
-- Boleto is the second most used method, generating ~18% of revenue, showing relevance among price-sensitive customers.
-- Vouchers and debit cards together contribute less than 4%, indicating minimal impact on overall revenue.
-- Overall, the business is heavily dependent on credit card payments, suggesting any friction in this method could significantly impact sales.

-- ===========================================================================================================================================

-- Problem 6: Which days of the week generate the highest revenue?
----------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    DATENAME(WEEKDAY, o.order_purchase_timestamp) AS day_of_week,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue
   
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    DATENAME(WEEKDAY, o.order_purchase_timestamp)
ORDER BY
    total_revenue DESC;

-- Insight:
-- Credit cards dominate revenue, contributing ~78.5% of total revenue (₹12M+ from 74K orders), making it the primary payment driver.
-- Boleto is the second most used method, generating ~18% of revenue, showing relevance among price-sensitive customers.
-- Vouchers and debit cards together contribute less than 4%, indicating minimal impact on overall revenue.
-- Revenue is highest on weekdays (monday peak 2.5M+) and lowest on weekends(saturday 1.7M).
-- Overall, the business is heavily dependent on credit card payments, suggesting any friction in this method could significantly impact sales.

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 4 - REVENUE & CUSTOMER VALUE (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- One-time customers have a higher AOV (₹160.73) than repeat customers (₹145.95),
-- indicating that first purchases are often higher-value, while repeat behavior is driven more by frequency than basket size.
-- A small set of sellers generate exceptionally high AOV from repeat customers, 
-- with top sellers crossing ₹3,700+ AOV, showing that premium sellers successfully retain high-spending customers.
-- Product categories differ strongly in repeat-customer value:
-- Categories like Computers (~₹1127 AOV) and Small Appliances (~₹793 AOV) lead in repeat-purchase value, 
-- while lifestyle and low-ticket categories show much lower repeat AOV.
-- Revenue grows steadily over time, reaching ~₹15.4 million in cumulative revenue, 
-- with noticeable acceleration in later periods—indicating marketplace scale-up and increasing transaction volume.
-- Credit cards contribute ~78.5% of total revenue, making them the primary revenue driver, while boleto contributes ~18%,
-- and other methods have minimal impact.

