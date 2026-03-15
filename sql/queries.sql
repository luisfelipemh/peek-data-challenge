-- Task A, Monthly Product Metrics

WITH conversion AS (
  SELECT 
    DATE_TRUNC(DATE(e.created_at), MONTH) AS month,
    COUNT(DISTINCT CASE WHEN e.event_type = 'purchase' THEN e.session_id END) /
    COUNT(DISTINCT CASE WHEN e.event_type = 'department' THEN e.session_id END) AS conversion_rate
  FROM `bigquery-public-data.thelook_ecommerce.events` e
  GROUP BY 1
),

order_metrics AS (
  SELECT 
    DATE_TRUNC(DATE(ot.created_at), MONTH) AS month,
    SUM(ot.sale_price) AS revenue,
    COUNT(DISTINCT ot.order_id) AS orders,
    COUNT(ot.order_id) AS units,
    SUM(ot.sale_price) / COUNT(DISTINCT ot.order_id) AS aov
  FROM `bigquery-public-data.thelook_ecommerce.order_items` ot
  WHERE ot.status = 'Complete' 
    AND ot.returned_at IS NULL
  GROUP BY 1
)

SELECT
  om.month,
  om.revenue,
  om.orders,
  om.units,
  om.aov,
  c.conversion_rate
FROM order_metrics om
LEFT JOIN conversion c ON om.month = c.month
ORDER BY 1 DESC

-- Task B, New vs Returning Mix

WITH first_order AS (
  SELECT 
    ot.user_id,
    MIN(DATE_TRUNC(DATE(ot.created_at), MONTH)) AS first_order_month
  FROM `bigquery-public-data.thelook_ecommerce.order_items` ot
  WHERE ot.status = 'Complete' AND ot.returned_at IS NULL
  GROUP BY 1
)

SELECT 
  DATE_TRUNC(DATE(ot.created_at), MONTH) AS month,
  COUNT(DISTINCT CASE WHEN ot.status = 'Complete' THEN ot.user_id END) AS active_customers,
  COUNT(DISTINCT CASE WHEN DATE_TRUNC(DATE(ot.created_at), MONTH) = fo.first_order_month THEN ot.user_id END) AS new_customers,
  COUNT(DISTINCT CASE WHEN DATE_TRUNC(DATE(ot.created_at), MONTH) != fo.first_order_month THEN ot.user_id END) AS returning_customers,
  SUM(CASE WHEN DATE_TRUNC(DATE(ot.created_at), MONTH) = fo.first_order_month THEN ot.sale_price END) AS revenue_new,
  SUM(CASE WHEN DATE_TRUNC(DATE(ot.created_at), MONTH) != fo.first_order_month THEN ot.sale_price END) AS revenue_returning,
  SUM(CASE WHEN DATE_TRUNC(DATE(ot.created_at), MONTH) != fo.first_order_month THEN ot.sale_price END) /
  SUM(ot.sale_price) AS pct_revenue_from_returning
FROM `bigquery-public-data.thelook_ecommerce.order_items` ot
LEFT JOIN first_order fo ON fo.user_id = ot.user_id
WHERE ot.status = 'Complete' 
  AND ot.returned_at IS NULL
GROUP BY 1
ORDER BY 1 DESC

-- Task C, 90 Day Churn

WITH user_orders AS (
    SELECT 
        ot.user_id,
        ot.sale_price, -- 1. Grab the price of the item
        DATE_TRUNC(DATE(ot.created_at), MONTH) AS month,
        DATE(ot.created_at) AS order_date,
        LEAD(DATE(ot.created_at)) OVER (PARTITION BY ot.user_id ORDER BY ot.created_at) AS next_order_date
    FROM `bigquery-public-data.thelook_ecommerce.order_items` ot
    WHERE ot.status = 'Complete' AND ot.returned_at IS NULL
)

SELECT
    month,
    SUM(sale_price) AS total_monthly_revenue, -- 2. Sum it up for the month
    COUNT(DISTINCT user_id) AS active_customers,
    COUNT(DISTINCT CASE WHEN next_order_date IS NULL OR DATE_DIFF(next_order_date, order_date, DAY) > 90 THEN user_id END) AS churned_customers_90d,
    ROUND(COUNT(DISTINCT CASE WHEN next_order_date IS NULL OR DATE_DIFF(next_order_date, order_date, DAY) > 90 THEN user_id END) / COUNT(DISTINCT user_id), 4) AS churn_rate_90d
FROM user_orders
GROUP BY 1
ORDER BY 1 DESC;


-- Task D, Product Change Impact

WITH order_totals AS (
    SELECT
        o.order_id,
        DATE_TRUNC(DATE(o.created_at), MONTH) AS order_month,
        CASE 
            WHEN DATE(o.created_at) >= '2022-01-15' THEN 'Post-Launch' 
            ELSE 'Pre-Launch' 
        END AS launch_period,
        u.traffic_source, 
        SUM(oi.sale_price) AS order_revenue
    FROM `bigquery-public-data.thelook_ecommerce.orders` o
    JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
        ON o.order_id = oi.order_id
    JOIN `bigquery-public-data.thelook_ecommerce.users` u
        ON o.user_id = u.id
    WHERE 
        oi.status = 'Complete' 
        AND oi.returned_at IS NULL
        AND DATE(o.created_at) >= '2021-07-15' 
        AND DATE(o.created_at) < '2022-07-15'
    GROUP BY 1, 2, 3, 4
)

SELECT
    order_month,
    launch_period,
    traffic_source,
    CASE 
        WHEN order_revenue >= 100 THEN 'Over $100 (Free Shipping Eligible)'
        ELSE 'Under $100 (Not Eligible)'
    END AS segment,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_monthly_revenue,
    SUM(order_revenue) / COUNT(DISTINCT order_id) AS average_order_value
FROM order_totals
GROUP BY 1, 2, 3, 4
ORDER BY order_month, traffic_source, segment;

-- Task D, Product Chance Impact [For Looker Charts]

WITH order_totals AS (
    SELECT
        o.order_id,
        DATE(o.created_at) AS order_date, 
        u.traffic_source, 
        SUM(oi.sale_price) AS order_revenue
    FROM `bigquery-public-data.thelook_ecommerce.orders` o
    JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi
        ON o.order_id = oi.order_id
    JOIN `bigquery-public-data.thelook_ecommerce.users` u
        ON o.user_id = u.id
    WHERE 
        oi.status = 'Complete' 
        AND oi.returned_at IS NULL
        AND DATE(o.created_at) BETWEEN '2021-11-16' AND '2022-03-16'
    GROUP BY 1, 2, 3
)

SELECT
    order_date,
    traffic_source,
    -- Original metrics
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_revenue) AS total_daily_revenue,
    SUM(order_revenue) / COUNT(DISTINCT order_id) AS average_order_value,
    
    -- Proxy Segment Metrics: Counting orders above and below $100
    COUNT(DISTINCT CASE WHEN order_revenue >= 100 THEN order_id END) AS orders_over_100,
    COUNT(DISTINCT CASE WHEN order_revenue < 100 THEN order_id END) AS orders_under_100

FROM order_totals
GROUP BY 1, 2
ORDER BY 1, 2;

-- Part 2.1, Retention + Churn by Acquisition Channel

WITH first_touch AS (
    SELECT 
        user_id,
        traffic_source AS first_traffic_source
    FROM (
        SELECT 
            user_id,
            traffic_source,
            ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at ASC) as session_rank
        FROM `bigquery-public-data.thelook_ecommerce.events`
    )
    WHERE session_rank = 1
),

first_purchase AS (
    SELECT 
        oi.user_id,
        ft.first_traffic_source,
        MIN(DATE_TRUNC(DATE(oi.created_at), MONTH)) AS cohort_month
    FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
    JOIN first_touch ft 
        ON ft.user_id = oi.user_id
    WHERE oi.status = 'Complete' AND oi.returned_at IS NULL
    GROUP BY 1, 2
),

user_activity AS (
    SELECT 
        fp.first_traffic_source,
        fp.user_id,
        DATE_DIFF(DATE_TRUNC(DATE(oi.created_at), MONTH), fp.cohort_month, MONTH) AS month_number
    FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
    JOIN first_purchase fp 
        ON oi.user_id = fp.user_id
    WHERE oi.status = 'Complete' 
        AND oi.returned_at IS NULL
        AND DATE_TRUNC(DATE(oi.created_at), MONTH) >= fp.cohort_month
)

SELECT 
    first_traffic_source AS traffic_source,
    CONCAT('M', CAST(month_number AS STRING)) AS month_label,
    month_number, 
    COUNT(DISTINCT user_id) AS active_users,
    COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY first_traffic_source) AS retention_rate
FROM user_activity
WHERE month_number <= 12
GROUP BY 1, 2, 3
ORDER BY 1, 3;


-- Part 2.2. Funnel of a typycal user journey

WITH session_journey AS (
  SELECT 
    session_id,
    1 AS total_visitors, -- Every unique session counts as a site visit
    MAX(CASE WHEN event_type = 'product' THEN 1 ELSE 0 END) AS viewed_product,
    MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS added_to_cart,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
  FROM `bigquery-public-data.thelook_ecommerce.events`
  GROUP BY session_id
),

funnel_aggregates AS (
  SELECT
    SUM(total_visitors) AS total_sessions,
    SUM(viewed_product) AS product_sessions,
    SUM(added_to_cart) AS cart_sessions,
    SUM(purchased) AS purchase_sessions
  FROM session_journey
)

SELECT
  '1 - Site Visit' AS funnel_stage,
  total_sessions AS unique_sessions,
  100.0 AS conversion_rate_pct
FROM funnel_aggregates

UNION ALL

SELECT
  '2 - Product View' AS funnel_stage,
  product_sessions AS unique_sessions,
  ROUND(SAFE_DIVIDE(product_sessions, total_sessions) * 100, 2) AS conversion_rate_pct
FROM funnel_aggregates

UNION ALL

SELECT
  '3 - Add to Cart' AS funnel_stage,
  cart_sessions AS unique_sessions,
  ROUND(SAFE_DIVIDE(cart_sessions, total_sessions) * 100, 2) AS conversion_rate_pct
FROM funnel_aggregates

UNION ALL

SELECT
  '4 - Purchase' AS funnel_stage,
  purchase_sessions AS unique_sessions,
  ROUND(SAFE_DIVIDE(purchase_sessions, total_sessions) * 100, 2) AS conversion_rate_pct
FROM funnel_aggregates

ORDER BY funnel_stage;


-- Part 2.3, Retention + Churn by Country

WITH first_purchase AS (
    SELECT 
        oi.user_id,
        u.country,
        MIN(DATE_TRUNC(DATE(oi.created_at), MONTH)) AS cohort_month
    FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
    JOIN `bigquery-public-data.thelook_ecommerce.users` u ON u.id = oi.user_id
    WHERE oi.status = 'Complete' AND oi.returned_at IS NULL
    GROUP BY 1, 2
),

user_activity AS (
    SELECT 
        fp.country,
        fp.user_id,
        DATE_DIFF(DATE_TRUNC(DATE(oi.created_at), MONTH), fp.cohort_month, MONTH) AS month_number
    FROM `bigquery-public-data.thelook_ecommerce.order_items` oi
    JOIN first_purchase fp ON oi.user_id = fp.user_id
    WHERE oi.status = 'Complete' 
        AND oi.returned_at IS NULL
        AND DATE_TRUNC(DATE(oi.created_at), MONTH) >= fp.cohort_month
)

SELECT 
    country,
    -- This forces the output to be 'M0', 'M1', 'M2' etc. Looker Studio CAN'T make this a calendar date.
    CONCAT('M', CAST(month_number AS STRING)) AS month_label,
    month_number, -- Keep this just for sorting the chart correctly
    COUNT(DISTINCT user_id) AS active_users,
    COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY country) AS retention_rate
FROM user_activity
WHERE month_number <= 12
GROUP BY 1, 2, 3
ORDER BY 1, 3;
