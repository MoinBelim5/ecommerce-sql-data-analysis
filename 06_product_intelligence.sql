

-- SECTION 6 : PRODUCT INTELLIGENCE

-- OBJECTIVE: Understanding product boundling and category leaders.

-- ===========================================================================================================================================

-- Problem 1: Which products are most frequently bought together in the same order?
----------------------------------------------------------------------------------------------------------------------------------------------
USE Olist_Ecommerce;
SELECT
    oi1.product_id AS product_1,
    oi2.product_id AS product_2,
    COUNT(*) AS times_bought_together
FROM olist_order_items_dataset oi1
JOIN olist_order_items_dataset oi2
    ON oi1.order_id = oi2.order_id
    AND oi1.product_id < oi2.product_id   
GROUP BY
    oi1.product_id,
    oi2.product_id
ORDER BY
    times_bought_together DESC;

-- Insight:
-- Certain product pairs (05b515fdc76e888aada3c6d66c201dff and 270516a3f41dc035aa87d220228f844c) are repeatedly purchased together(100 times).
-- it shows clear cross-sell oppertunities.
-- there combinations can be bundled or recommended together to increase average order value and drive smart promotions.

-- ===========================================================================================================================================

-- Problem 2: Which product categories generate the highest total revenue?
----------------------------------------------------------------------------------------------------------------------------------------------
SELECT TOP 1
    pc.product_category_name_english AS product_category,
    ROUND(SUM(oi.price + oi.freight_value),2) AS highest_total_revenue
FROM product_category_name_translation pc
JOIN olist_products_dataset pr
    ON pc.product_category_name = pr.product_category_name
JOIN olist_order_items_dataset oi
    ON pr.product_id = oi.product_id
JOIN olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE   
    o.order_status = 'delivered' -- AND
   -- pr.product_category_name IS NOT NULL
GROUP BY 
    pc.product_category_name_english
ORDER BY
    highest_total_revenue DESC;

-- Insight:
-- The Health & Beauty category generates the highest total revenue on the platform, 
-- making it the strongest revenue-driving segment. 
-- This indicates high customer demand and suggests that,
-- investing more in this category (inventory, promotions, ads) could further boost overall sales.

-- ===========================================================================================================================================

-- Problem 3: For each product category, identify the single product that contributes the highest total revenue.
----------------------------------------------------------------------------------------------------------------------------------------------
WITH product_revenue AS (
    SELECT
        pc.product_category_name_english AS category,
        pr.product_id,
        ROUND(SUM(oi.price),2) AS revenue
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    JOIN olist_products_dataset pr
        ON oi.product_id = pr.product_id
    JOIN product_category_name_translation pc
        ON pr.product_category_name = pc.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        pc.product_category_name_english,
        pr.product_id
)
SELECT
    product_id,
    category,
    revenue
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY category
               ORDER BY revenue DESC
           ) AS rn
    FROM product_revenue
) t
WHERE rn = 1
ORDER BY revenue DESC;

-- Insight:
-- Health & Beauty (63K) and Computers (45K+) categories have strong revenue-driving products, 
-- indicating high customer demand and strong category performance.
-- These should be prioritized for inventory planning and promotional campaigns.
-- Categories like Security & Services (183) and Fashion Children’s Clothes (180) show very low product-level revenue contribution.
-- These may require pricing review, better visibility, or strategic reconsideration.

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 6 - PRODUCT INTELLIGENCE (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- Revenue within categories is highly concentrated, 
-- with a single top product often driving the majority of category revenue. 
-- Categories like Health & Beauty (~₹63K) and Computers (~₹45K) lead in top-product revenue. 
-- Frequently bought-together product pairs reveal strong bundling opportunities,
-- that can increase AOV through cross-sell strategies.

