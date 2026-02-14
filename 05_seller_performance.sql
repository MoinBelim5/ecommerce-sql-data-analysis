

-- SECTION 5 : SELLER PERFORMANCE

-- OBJECTIVE: Identify reliable and high performing sellers.

-- ===========================================================================================================================================

-- Problem 1: Which seller generate the highest revenue?
----------------------------------------------------------------------------------------------------------------------------------------------
USE Olist_Ecommerce;
SELECT 
    TOP 1
    s.seller_id,
    ROUND(SUM(oi.price),2) AS highest_revenue
FROM olist_sellers_dataset s
JOIN olist_order_items_dataset oi
    ON s.seller_id = oi.seller_id
JOIN olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'

GROUP BY 
    s.seller_id
ORDER BY
    highest_revenue DESC;

-- Insight:
-- Seller 4869f7a5dfa277a7dca6462dcf3b52b2 is the top revenue generator, contributing the highest total sales,
-- on the platform.

-- ===========================================================================================================================================

-- Problem 2: Which sellers have the longest active selling span on the platform?
----------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    TOP 1
    oi.seller_id,

    MIN(o.order_delivered_customer_date) AS first_sale_date,
    MAX(o.order_delivered_customer_date) AS last_sale_date,

    DATEDIFF(
        DAY,
        MIN(o.order_delivered_customer_date),
        MAX(o.order_delivered_customer_date)
    ) AS active_selling_days

FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id

WHERE
    o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL

GROUP BY
    oi.seller_id

ORDER BY
    active_selling_days DESC;

-- Insight:
-- Seller cab85505710c7cb9b720bceb52b01cee has the longest active selling span of 705 days.
-- indicating strong long-term presence on the platform.

-- ===========================================================================================================================================

-- Problem 3: Which sellers sell consistently every month vs sellers who have only one-time spikes?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH seller_monthly_orders AS (
    SELECT
        oi.seller_id,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                      MONTH(o.order_purchase_timestamp), 1) AS order_month,
        COUNT(DISTINCT o.order_id) AS orders_in_month
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        oi.seller_id,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                      MONTH(o.order_purchase_timestamp), 1)
),

seller_span AS (
    SELECT
        seller_id,
        MIN(order_month) AS first_month,
        MAX(order_month) AS last_month,
        COUNT(order_month) AS active_months,
        SUM(orders_in_month) AS total_orders,
        ROUND(AVG(orders_in_month * 1.0), 2) AS avg_orders_per_active_month
    FROM seller_monthly_orders
    GROUP BY seller_id
)

SELECT
    seller_id,
    active_months,

    DATEDIFF(MONTH, first_month, last_month) + 1 AS total_span_months,

    ROUND(
        active_months * 100.0 /
        (DATEDIFF(MONTH, first_month, last_month) + 1),
        2
    ) AS consistency_percent,

    total_orders,
    avg_orders_per_active_month

FROM seller_span
ORDER BY
    consistency_percent DESC,
    active_months DESC;

-- Insight:
-- Some sellers show 100% consistency, meaning they generated orders 
-- in every month of their active span.
-- These sellers are stable and reliable performers, not just seasonal spikes.
-- Sellers with low consistency_percent (10–20%) appear to have 
-- occasional or one-time spikes rather than steady monthly sales.

-- ===========================================================================================================================================

-- Problem 4: Which sellers maintain high customer satisfaction?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        o.order_id
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

seller_reviews AS (
    SELECT
        so.seller_id,
        so.order_id,
        orv.review_score
    FROM seller_orders so
    JOIN olist_order_reviews_dataset orv
        ON so.order_id = orv.order_id
)

SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS total_orders,
    CAST(AVG(review_score * 1.0) AS DECIMAL(4,2)) AS avg_review_score
FROM seller_reviews
GROUP BY 
    seller_id
HAVING 
    COUNT(DISTINCT order_id) >= 10   
ORDER BY 
    --avg_review_score DESC,
    total_orders DESC;

-- Insight:
-- Some sellers (48efc9d94a9834137efd9ea76b065a38 and 2addf05f476d0637864454e93ba673d5) maintain an average review score close to 5.0,
-- even with a decent number of total orders.
-- This indicates strong service quality and consistent customer satisfaction.
-- Sellers with average ratings below 3.0 show clear satisfaction issues,
-- especially those with high order counts.
-- These sellers may require quality improvement or monitoring.

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 5 - SELLER PERFORMANCE (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- This section evaluates sellers based on revenue generation, selling consistency, 
-- active duration on the platform, and customer satisfaction.
-- The analysis shows that while a few sellers generate the highest total revenue, 
-- long-term success on the platform is not just about revenue volume. 
-- Some sellers demonstrate strong consistency by selling actively every month, 
-- indicating stable performance rather than short-term spikes.
-- Additionally, sellers with the longest active selling span (700+ days) reflect strong platform retention and operational stability. 
-- However, revenue alone does not define performance — customer satisfaction scores highlight that,
-- only certain sellers maintain high ratings while handling a significant number of orders.

