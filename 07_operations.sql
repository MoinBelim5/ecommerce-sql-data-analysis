

-- SECTION 7 : OPERATIONS & LOGISTICS IMPACT

-- OBJECTIVE: Measure operational efficiency and customer satisfaction impact.

-- ===========================================================================================================================================

-- Problem 1: Which customer states face the highest average delivery delay?
----------------------------------------------------------------------------------------------------------------------------------------------
 USE Olist_Ecommerce;
 SELECT
    cu.customer_state,
    AVG(
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date)
        END
    ) AS average_delay
FROM olist_orders_dataset o
JOIN olist_customers_dataset cu
    ON o.customer_id = cu.customer_id
WHERE
    o.order_estimated_delivery_date IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY
    cu.customer_state
ORDER BY
    average_delay DESC;

-- Insight:
-- AP and RR showing extreme delays (36–48 days), 
-- while states like SP and DF maintain efficient fulfillment (5–6 days).
-- indicating regional logistics inefficiencies that may impact customer satisfaction.

-- ===========================================================================================================================================

-- Problem 2: What is the average delivery time (in days) for each state?
----------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    c.customer_state,
    AVG(DATEDIFF(DAY,o.order_approved_at, o.order_delivered_customer_date)) AS difference_in_days
FROM olist_orders_dataset o
JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE
    o.order_status = 'delivered'
    AND
o.order_delivered_customer_date 
IS NOT NULL 
    AND o.order_approved_at 
IS NOT NULL
GROUP BY
    c.customer_state
ORDER BY
   difference_in_days DESC;

-- Insight:
-- Delivery time varies significantly by region, with northern states like RR and AP taking 25–28 days on average, 
-- while SP completes deliveries in just 8 days, highlighting regional logistics performance gaps.

-- ===========================================================================================================================================

-- Problem 3: Impact of Delivery Delay on Customer Satisfaction
----------------------------------------------------------------------------------------------------------------------------------------------
WITH delivery_base AS (
    SELECT DISTINCT
        o.order_id,
        DATEDIFF(
            DAY,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) AS delivery_delay_days,
        orv.review_score
    FROM olist_orders_dataset o
    JOIN olist_order_reviews_dataset orv
        ON o.order_id = orv.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

delay_bucket AS (
    SELECT
        order_id,
        review_score,

        CASE
            WHEN delivery_delay_days <= 0 THEN 'On Time / Early'
            WHEN delivery_delay_days BETWEEN 1 AND 3 THEN '1–3 Days Late'
            WHEN delivery_delay_days BETWEEN 4 AND 7 THEN '4–7 Days Late'
            ELSE 'More Than 7 Days Late'
        END AS delay_category,

        CASE
            WHEN delivery_delay_days <= 0 THEN 1
            WHEN delivery_delay_days BETWEEN 1 AND 3 THEN 2
            WHEN delivery_delay_days BETWEEN 4 AND 7 THEN 3
            ELSE 4
        END AS sort_key
    FROM delivery_base
)

SELECT
    delay_category,
    COUNT(DISTINCT order_id) AS total_orders,

   CAST( 
        ROUND(
            COUNT(DISTINCT order_id) * 
   100.0
            / SUM(COUNT(DISTINCT order_id)) OVER (),
        2 
        ) AS DECIMAL(5,2)
    ) AS order_share_percent,

    CAST(
        ROUND(AVG(review_score * 1.0), 
        2
        ) AS DECIMAL(5,2)
     ) AS avg_review_score,

    CAST(
        ROUND(
            SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 
    100.0
            / COUNT(DISTINCT order_id),
        2
        ) AS DECIMAL(5,2)
    ) AS low_rating_percent

FROM delay_bucket
GROUP BY
    delay_category,
    sort_key
ORDER BY
    sort_key;

-- Insight:
-- Customer satisfaction drops sharply as delivery delays increase. 
-- Orders delayed by more than 7 days have an average rating of just 1.7 and nearly 80% low ratings, 
-- showing that delivery performance directly impacts customer experience.

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 7 - OPERATIONS & LOGISTICS IMPACT (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- Delivery performance varies sharply by region, 
-- with states like AP and RR facing average delays of 30–48 days, 
-- compared to 5–8 days in SP and DF. 
-- Delivery delays have a direct impact on satisfaction: 
-- on-time orders average 4.29 ratings, 
-- while orders delayed >7 days drop to 1.70, with ~80% low ratings, 
-- making logistics a key customer experience driver.

