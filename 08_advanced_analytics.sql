

-- SECTION 8 : ADVANCED ANALYTICS

-- OBJECTIVE: Long-term customer value modeling.

-- ===========================================================================================================================================

-- Problem 1: RFM(recency, frequency, monetary) customer segmentation
----------------------------------------------------------------------------------------------------------------------------------------------
USE Olist_Ecommerce;
WITH order_value AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp
),

rfm_base AS (
    SELECT
        cu.customer_unique_id,

        MAX(ov.order_purchase_timestamp) AS last_purchase_date,

        COUNT(ov.order_id) AS frequency,

        ROUND(SUM(ov.order_total),2) AS monetary
    FROM order_value ov
    JOIN olist_customers_dataset cu
        ON ov.customer_id = cu.customer_id
    GROUP BY
        cu.customer_unique_id
),

rfm_calculated AS (
    SELECT *,
        DATEDIFF(DAY, last_purchase_date,
            (SELECT MAX(order_purchase_timestamp) FROM order_value)
        ) AS recency
    FROM rfm_base
),

rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency DESC)   AS R_score,
        NTILE(5) OVER (ORDER BY frequency) AS F_score,
        NTILE(5) OVER (ORDER BY monetary) AS M_score
        /*CASE    
            WHEN frequency = 1 THEN 1
            WHEN frequency BETWEEN 2 AND 3
        THEN 3
            WHEN frequency >= 4 THEN 5
        END AS F_score,
         CASE    
            WHEN monetary <= 100 THEN 1
            WHEN monetary BETWEEN 100 AND 500
        THEN 3
            WHEN monetary > 500 THEN 5
        END AS M_score */
    FROM rfm_calculated
)

SELECT
    customer_unique_id,
    recency,
    frequency,
    monetary,
    R_score,
    F_score,
    M_score,

    CASE
        WHEN R_score >=4 AND F_score >=4 AND M_score >=4 THEN 'Champions'
        WHEN R_score >=3 AND F_score >=3 AND M_score >=3 THEN 'Loyal Customers'
        WHEN R_score >=4 AND F_score <=2 THEN 'Recent Customers'
        WHEN R_score <=2 AND F_score >=4 THEN 'At Risk'
        WHEN R_score <=2 AND F_score <=2 THEN 'Lost Customers'
        ELSE 'Potential Customers'
    END AS customer_segment

FROM rfm_scores
ORDER BY recency DESC;


-- Insight:
-- The RFM results show a clear split between high-value customers (Champions & Loyal Customers with high R, F, M scores),
-- and a large group of Lost Customers with low engagement. 
-- This indicates strong revenue concentration among a smaller loyal segment, while churn risk remains high. 
-- The business should prioritize retaining top segments and running reactivation campaigns for lost customers to improve overall lifetime value.

-- ===========================================================================================================================================

-- Problem 2: Do customers who joined in earlier months retun more than customers who joined later?(Cohort retention)
----------------------------------------------------------------------------------------------------------------------------------------------
   WITH order_value AS (
    SELECT
        o.order_id,
        cu.customer_unique_id,
        o.order_purchase_timestamp
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset cu
        ON o.customer_id = cu.customer_id
    WHERE o.order_status = 'delivered'
),

first_purchase AS (
    SELECT
        customer_unique_id,
        DATEFROMPARTS(
            YEAR(MIN(order_purchase_timestamp)),
            MONTH(MIN(order_purchase_timestamp)),
            1
        ) AS cohort_month
    FROM order_value
    GROUP BY customer_unique_id
),

cohort_data AS (
    SELECT
        ov.customer_unique_id,
        fp.cohort_month,
        DATEFROMPARTS(
            YEAR(ov.order_purchase_timestamp),
            MONTH(ov.order_purchase_timestamp),
            1
        ) AS order_month
    FROM order_value ov
    JOIN first_purchase fp
        ON ov.customer_unique_id = fp.customer_unique_id
),

cohort_result AS (
    SELECT
        cohort_month,
        DATEDIFF(MONTH, cohort_month, order_month) AS month_number,
        COUNT(DISTINCT customer_unique_id) AS customers_retained
    FROM cohort_data
    GROUP BY
        cohort_month,
        DATEDIFF(MONTH, cohort_month, order_month)
),

cohort_size AS (
    SELECT
        cohort_month,
        customers_retained AS cohort_size
    FROM cohort_result
    WHERE month_number = 0
)

SELECT
    cr.cohort_month,
    cr.month_number,
    cr.customers_retained,
    cs.cohort_size,
    ROUND(
        cr.customers_retained * 100.0 / cs.cohort_size,2
    ) AS retention_percent
FROM cohort_result cr
JOIN cohort_size cs
    ON cr.cohort_month = cs.cohort_month
ORDER BY
    cr.cohort_month,
    cr.month_number;

-- Insight:
-- Across cohorts, customer retention drops sharply after the first purchase month. 
-- While initial cohort sizes grow over time, repeat engagement remains consistently low, 
-- showing that most customers do not return beyond early months. 
-- This indicates a strong acquisition funnel but weak long-term retention, 
-- highlighting the need for better post-purchase engagement and loyalty strategies.

-- ===========================================================================================================================================

-- Problem 3: How does customer lifetime value(LTV) evolve month-by-month for each cohort? (Cohort revenue & Cumulative LTV trend)
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

    ROUND(
        COUNT(DISTINCT order_id) * 100.0
        / SUM(COUNT(DISTINCT order_id)) OVER (),
        2
    ) AS order_share_percent,

    ROUND(AVG(review_score * 1.0), 2) AS avg_review_score,

    ROUND(
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(DISTINCT order_id),
        2
    ) AS low_rating_percent

FROM delay_bucket
GROUP BY
    delay_category,
    sort_key
ORDER BY
    sort_key;

-- Insight:
-- On-time/Early deliveries make up 93.34% of orders (89,443 orders) and receive a high average rating of 4.29, with only 9.3% low ratings.
-- 1–3 days late orders drop to an average rating of 3.29, and low ratings jump to 32.18%, even though they form just 1.93% of orders.
-- 4–7 days late deliveries see ratings fall sharply to 2.11, with 67.68% low ratings.
-- Orders delayed more than 7 days perform worst: average rating 1.70 and 79.4% low ratings, despite being only 2.9% of total orders (2,781 orders).

-- ===========================================================================================================================================
-- ===========================================================================================================================================

-- SECTION 8 - ADVANCED ANALYTICS (FINAL INSIGHT)
----------------------------------------------------------------------------------------------------------------------------------------------
-- RFM analysis shows a strong split: a small group of Champions and Loyal Customers generate high monetary value, 
-- while a large portion of customers fall into Lost or One-time buyer segments, indicating weak repeat behavior.
-- Cohort retention analysis reveals a sharp drop after the first purchase across almost all cohorts. 
-- While cohort sizes grow over time, monthly retention remains consistently low, 
-- showing most customers do not return after early months.
-- cohort size is 2K-7K customers, only single-digit customers return in later months.
-- Long-term engagement is limited, meaning growth is currently driven more by new customer acquisition than customer retention.
-- Overall, the data highlights a strong acquisition funnel but weak post-purchase engagement, 
-- signaling a major opportunity to improve loyalty programs, 
-- repeat purchase incentives, and lifecycle marketing.

