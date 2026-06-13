CREATE OR REPLACE VIEW v_order_gmv AS
SELECT
    order_id,
    SUM(quantity * unit_price)                    AS gmv,
    SUM(quantity * unit_price * platform_fee_pct) AS platform_revenue,
    COUNT(*)                                      AS line_items
FROM order_items
GROUP BY order_id;

-- B1

WITH order_base AS ( 
    SELECT
        o.order_id,
        o.customer_id,
        c.city,
        DATE_FORMAT(o.created_at, '%Y-%m-01') AS ym,
        g.gmv,
        CASE WHEN o.status = 'Delivered' THEN 1 ELSE 0 END AS is_delivered
    FROM orders o
    JOIN customers   c ON c.customer_id = o.customer_id
    LEFT JOIN v_order_gmv g ON g.order_id = o.order_id
),
cust_month AS (
    SELECT customer_id, city, ym, SUM(is_delivered) AS delivered_in_month
    FROM order_base
    GROUP BY customer_id, city, ym
),
cust_month_cum AS (
    SELECT customer_id, city, ym,
           SUM(delivered_in_month) OVER (PARTITION BY customer_id ORDER BY ym) AS cum_delivered
    FROM cust_month
),
month_city AS (
    SELECT city, ym,
           SUM(gmv) AS gmv,
           COUNT(*) AS number_of_orders,
           COUNT(DISTINCT customer_id) AS unique_customers
    FROM order_base
    GROUP BY city, ym
),
repeat_cust AS (  
    SELECT city, ym, COUNT(*) AS repeat_customers
    FROM cust_month_cum
    WHERE cum_delivered >= 2
    GROUP BY city, ym
)
SELECT
    mc.ym AS month,
    mc.city,
    ROUND(mc.gmv) AS gmv,
    mc.number_of_orders,
    mc.unique_customers,
    ROUND(COALESCE(rc.repeat_customers,0) / mc.unique_customers, 4) AS repeat_purchase_rate
FROM month_city mc
LEFT JOIN repeat_cust rc ON rc.city = mc.city AND rc.ym = mc.ym
ORDER BY mc.ym, mc.city;


-- B2
WITH delivered_orders AS (
SELECT o.customer_id, o.order_id, o.created_at, s.delivery_status,
ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at, o.order_id) AS rn
FROM orders o
JOIN shipments s ON s.order_id = o.order_id
WHERE o.status = 'Delivered'
AND s.delivery_status IN ('OnTime','Late_1_2d','Late_3_5d','Late_5p')
),
first_order AS (
SELECT customer_id, order_id, created_at,
CASE WHEN delivery_status = 'OnTime' THEN 'OnTime' ELSE 'Delayed' END AS first_order_delay_status
FROM delivered_orders
WHERE rn = 1
),
repeat_flag AS (
SELECT f.customer_id, f.first_order_delay_status,
MAX(CASE WHEN o2.created_at > f.created_at
AND o2.created_at <= DATE_ADD(f.created_at, INTERVAL 90 DAY)
THEN 1 ELSE 0 END) AS repeated_90d
FROM first_order f
LEFT JOIN orders o2
ON o2.customer_id = f.customer_id
AND o2.order_id <> f.order_id
GROUP BY f.customer_id, f.first_order_delay_status
)
SELECT
first_order_delay_status,
COUNT(*) AS customers,
SUM(repeated_90d) AS repeated_customers,
ROUND(AVG(repeated_90d), 4) AS repeat_rate_90d
FROM repeat_flag
GROUP BY first_order_delay_status
ORDER BY first_order_delay_status;


-- B3

WITH seller_order AS (
SELECT
oi.seller_id, oi.order_id,
SUM(oi.quantity * oi.unit_price) AS seller_gmv,
s.carrier, s.ship_to_city,
CASE WHEN s.delivery_status IN ('Late_1_2d','Late_3_5d','Late_5p') THEN 1 ELSE 0 END AS is_delayed,
DATEDIFF(DATE(s.delivered_at), o.promised_delivery_date) AS delay_days
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN shipments s ON s.order_id = oi.order_id
WHERE s.delivered_at IS NOT NULL
GROUP BY oi.seller_id, oi.order_id, s.carrier, s.ship_to_city,
s.delivery_status, s.delivered_at, o.promised_delivery_date
)
SELECT
seller_id, carrier, ship_to_city,
COUNT(*) AS delivered_orders,
ROUND(SUM(seller_gmv)) AS total_gmv,
ROUND(SUM(CASE WHEN is_delayed = 1 THEN seller_gmv ELSE 0 END)) AS delayed_gmv,
ROUND(AVG(is_delayed), 4) AS delayed_order_rate,
ROUND(AVG(CASE WHEN is_delayed = 1 THEN delay_days END), 2) AS avg_delay_days
FROM seller_order
GROUP BY seller_id, carrier, ship_to_city
HAVING COUNT(*) >= 25
ORDER BY delayed_order_rate DESC, delayed_gmv DESC;

-- B4

SELECT
    o.order_id,
    s.delivered_at,
    o.created_at,
    c.city
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN shipments s ON s.order_id    = o.order_id
WHERE s.delivery_status <> 'OnTime';