

-- SECTION 3 : REPEAT CUSTOMER DEEP DIVE

-- OBJECTIVE: Understand repeat customer contribution and seller dependency

-- ===========================================================================================================================================

-- Problem 1: Which product categories are mostly bought by repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
USE Olist_Ecommerce;
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY cu.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
)

SELECT
    pc.product_category_name_english AS product_category,
    COUNT(oi.order_id) AS items_bought_by_repeat_customers
FROM repeat_customers rc
JOIN olist_customers_dataset cu
    ON rc.customer_unique_id = cu.customer_unique_id
JOIN olist_orders_dataset o
    ON cu.customer_id = o.customer_id
JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
JOIN olist_products_dataset pr
    ON oi.product_id = pr.product_id
JOIN product_category_name_translation pc
    ON pr.product_category_name = pc.product_category_name
WHERE
    o.order_status = 'delivered'
GROUP BY
    pc.product_category_name_english
ORDER BY 
    items_bought_by_repeat_customers DESC;

-- Insight:
-- Repeat customers most frequently purchase from the,
-- bed_bath_table category, followed by furniture_decor and sports_leisure.
-- This shows that home-related and lifestyle products drive stronger repeat purchasing behavior.

-- ===========================================================================================================================================

-- Problem 2: Which sellers are preferred by repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
       ON cu.customer_id = o.customer_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        cu.customer_unique_id
        HAVING 
        COUNT(DISTINCT o.order_id) > 1
)
SELECT
    s.seller_id AS repeated_seller,
    COUNT(DISTINCT oi.order_id) AS orders_by_repeat_customers
FROM repeat_customers rc
JOIN olist_customers_dataset cu
    ON rc.customer_unique_id = cu.customer_unique_id
JOIN olist_orders_dataset o
    ON cu.customer_id = o.customer_id
JOIN olist_order_items_dataset oi
    ON o.order_id = oi.order_id
JOIN olist_sellers_dataset s
    ON oi.seller_id = s.seller_id
WHERE
    o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY orders_by_repeat_customers DESC;

-- Insight:
-- A small group of sellers receive a significantly higher number of repeat customer orders.
-- This suggests that certain sellers have stronger customer,
-- trust and retention compared to others.

-- ===========================================================================================================================================

-- Problem 3: Which states have the highest number of repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers_with_states AS (
SELECT 

    cu.customer_unique_id
FROM olist_customers_dataset cu
JOIN olist_orders_dataset o
    ON cu.customer_id = o.customer_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    cu.customer_unique_id
HAVING
    COUNT(DISTINCT o.order_id) > 1
)

    SELECT
        cu.customer_state,
        COUNT(DISTINCT rcs.customer_unique_id) AS repeat_customers_count
    FROM repeat_customers_with_states rcs
    JOIN olist_customers_dataset cu
        ON rcs.customer_unique_id = cu.customer_unique_id
    GROUP BY
        cu.customer_state
    ORDER BY
        repeat_customers_count DESC;

-- Insight:
-- SP has the highest number of repeat customers.
-- other states contribute significantly less in comparison.
-- AP & RR has only 1-1 repeat customers.

-- ===========================================================================================================================================

-- Problem 4: Which states have the highest percentage of repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
 WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY cu.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
)

SELECT
    cu.customer_state,
    COUNT(DISTINCT cu.customer_unique_id) AS total_customers,
    COUNT(DISTINCT rcp.customer_unique_id) AS repeat_customers,
    100.0 * COUNT(DISTINCT rcp.customer_unique_id)
    / COUNT(DISTINCT cu.customer_unique_id)
    AS repeat_customer_percentage
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
        AND o.order_status = 'delivered'
LEFT JOIN repeat_customers rcp
    ON cu.customer_unique_id = rcp.customer_unique_id
GROUP BY cu.customer_state
ORDER BY repeat_customer_percentage DESC;

-- Insight:
-- Smaller states like AC and RO show a higher repeat customer percentage,
-- indicating relatively better retention compared to larger states.
-- in absolute numbers, bigger states still dominate total repeat customers.

-- ===========================================================================================================================================

-- Problem 5: Which product categories have the highest repeat customer percentage?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
       AND o.order_status = 'delivered'
    GROUP BY cu.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
),

customer_category AS (
    SELECT DISTINCT
        cu.customer_unique_id,
        pc.product_category_name_english
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
       AND o.order_status = 'delivered'
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_products_dataset pr
        ON oi.product_id = pr.product_id
    JOIN product_category_name_translation pc
        ON pr.product_category_name = pc.product_category_name
)

SELECT
    cc.product_category_name_english,

    COUNT(DISTINCT cc.customer_unique_id) AS total_customers,
    COUNT(DISTINCT rc.customer_unique_id) AS repeat_customers,

    ROUND(
        100.0 * COUNT(DISTINCT rc.customer_unique_id)
        / COUNT(DISTINCT cc.customer_unique_id),
        2
    ) AS repeat_customer_by_category_percentage

FROM customer_category cc
LEFT JOIN repeat_customers rc
    ON cc.customer_unique_id = rc.customer_unique_id

GROUP BY cc.product_category_name_english
ORDER BY repeat_customer_by_category_percentage DESC;

-- Insight:
-- Categories like la cuisine and arts & craftsmanship show the highest repeat customer percentage.
-- this suggests niche categories tend to build stronger customer loyalty.
-- however, overall customer volume in these categories is relatively small.

-- ===========================================================================================================================================

-- Problem 6: Which product categories generate the highest revenue from repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset AS cu
    JOIN olist_orders_dataset AS o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        cu.customer_unique_id
    HAVING COUNT(o.order_id) > 1
)

SELECT
    pc.product_category_name_english AS product_category,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS revenue_from_repeat_customers
FROM olist_orders_dataset AS o
JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
JOIN olist_products_dataset AS pr
    ON oi.product_id = pr.product_id
JOIN product_category_name_translation AS pc
    ON pr.product_category_name = pc.product_category_name
JOIN olist_customers_dataset AS cu
    ON o.customer_id = cu.customer_id
JOIN repeat_customers AS rc
    ON cu.customer_unique_id = rc.customer_unique_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    pc.product_category_name_english
ORDER BY
    revenue_from_repeat_customers DESC;

-- Insight:
-- Bed, Bath & Table generates the highest revenue from repeat customers.
-- This indicates strong repeat purchase behavior in home-related categories.
-- Core lifestyle categories appear to drive sustained customer value.


-- ===========================================================================================================================================

-- Problem 7: Which sellers generate the highest revenue from repeat customers?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset AS cu
    JOIN olist_orders_dataset AS o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        cu.customer_unique_id
    HAVING COUNT(o.order_id) > 1
)

SELECT
    oi.seller_id,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS revenue_from_repeat_customers
FROM olist_orders_dataset AS o
JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
JOIN olist_customers_dataset AS cu
    ON o.customer_id = cu.customer_id
JOIN repeat_customers AS rc
    ON cu.customer_unique_id = rc.customer_unique_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    oi.seller_id
ORDER BY
    revenue_from_repeat_customers DESC;

-- Insight:
-- A small group of sellers generate the majority of revenue from repeat customers.
-- This suggests strong seller-level loyalty and trust built with returning buyers.
-- Repeat revenue appears concentrated among top-performing sellers.

-- ===========================================================================================================================================

-- Problem 8: Which product categories are most preferred by repeat customers by number of orders.
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY cu.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
)

SELECT
    pc.product_category_name_english AS product_category,
    COUNT(DISTINCT oi.order_id) AS orders_by_repeat_customers
FROM olist_orders_dataset AS o
JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
JOIN olist_products_dataset AS pr
    ON oi.product_id = pr.product_id
JOIN product_category_name_translation AS pc
    ON pr.product_category_name = pc.product_category_name
JOIN olist_customers_dataset AS cu
    ON o.customer_id = cu.customer_id
JOIN repeat_customers AS rc
    ON cu.customer_unique_id = rc.customer_unique_id
WHERE
    o.order_status = 'delivered'
GROUP BY
    pc.product_category_name_english
ORDER BY 
    orders_by_repeat_customers DESC;

-- Insight:
-- Repeat customers place the highest number of orders in Bed, Bath & Table,
-- followed by Sports & Leisure and Furniture & Decor.
-- This shows that home and lifestyle categories drive frequent repeat purchases.
-- party supplies, small appliances has only 1-1 repeat customers

-- ===========================================================================================================================================

-- Problem 9: Which sellers are most dependent on repeat customers for their revenue?
----------------------------------------------------------------------------------------------------------------------------------------------
WITH repeat_customers AS (
    SELECT
        cu.customer_unique_id
    FROM olist_customers_dataset cu
    JOIN olist_orders_dataset o
        ON cu.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY cu.customer_unique_id
    HAVING COUNT(o.order_id) > 1
),

seller_total_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price + oi.freight_value),2) AS total_revenue
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),

seller_repeat_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price + oi.freight_value),2) AS repeat_revenue
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_customers_dataset cu
        ON o.customer_id = cu.customer_id
    JOIN repeat_customers rc
        ON cu.customer_unique_id = rc.customer_unique_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)

SELECT
    tr.seller_id,
    tr.total_revenue,
    ISNULL(rr.repeat_revenue, 0) AS repeat_revenue,
    ROUND(
        ISNULL(rr.repeat_revenue, 0) * 100.0 / tr.total_revenue,
        2
    ) AS repeat_revenue_percent
FROM seller_total_revenue tr
LEFT JOIN seller_repeat_revenue rr
    ON tr.seller_id = rr.seller_id
ORDER BY repeat_revenue_percent DESC;

-- Insight:
-- Some sellers generate 100% of their revenue from repeat customers,
-- showing very high dependency on loyal buyers.
-- However, many sellers have 0% repeat revenue, meaning they rely entirely on one-time customers.
-- This highlights a clear divide between loyalty-driven sellers and acquisition-driven sellers.

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 3 - REPEAT CUSTOMER DEEP DIVE (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- Repeat customer activity is concentrated in specific categories and sellers. 
-- Bed Bath Table and Furniture Decor receive the highest repeat orders, 
-- while a small group of sellers generate most repeat revenue. 
-- Some sellers depend on repeat customers for 100% of their revenue, 
-- while many have 0% repeat contribution, highlighting uneven loyalty distribution.
