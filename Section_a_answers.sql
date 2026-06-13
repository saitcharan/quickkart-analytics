-- A1.1  Monthly GMV by city and category
SELECT
    DATE_FORMAT(o.created_at, '%Y-%m-01') AS month,
    c.city,
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price)) AS gmv
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY month, c.city, p.category
ORDER BY month, c.city, p.category;

-- A1.1  GMV share by category
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price)) AS gmv,
    ROUND(100 * SUM(oi.quantity * oi.unit_price) / (SELECT SUM(quantity * unit_price) FROM order_items), 1) AS pct_of_gmv
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY gmv DESC;

-- A1.2  Monthly orders and unique active customers
SELECT
    DATE_FORMAT(created_at, '%Y-%m-01') AS month,
    COUNT(*) AS number_of_orders,
    COUNT(DISTINCT customer_id) AS unique_active_customers
FROM orders
GROUP BY month
ORDER BY month;

-- A1.3  Monthly repeat-purchase rate (overall)
WITH cust_month AS (
    SELECT
        customer_id,
        DATE_FORMAT(created_at, '%Y-%m-01') AS ym,
        SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_in_month
    FROM orders
    GROUP BY customer_id, ym
),
cust_month_cum AS (
    SELECT
        customer_id,
        ym,
        SUM(delivered_in_month) OVER (PARTITION BY customer_id ORDER BY ym) AS cum_delivered
    FROM cust_month
)
SELECT
    ym AS month,
    COUNT(*) AS active_customers,
    SUM(CASE WHEN cum_delivered >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(AVG(CASE WHEN cum_delivered >= 2 THEN 1 ELSE 0 END), 4) AS repeat_purchase_rate
FROM cust_month_cum
GROUP BY ym
ORDER BY ym;

-- A1.4 (a)  Share of delayed orders by carrier
SELECT
    carrier,
    COUNT(*) AS delivered_orders,
    SUM(delivery_status LIKE 'Late%') AS delayed_orders,
    ROUND(100 * SUM(delivery_status LIKE 'Late%') / COUNT(*), 1) AS delayed_pct
FROM shipments
WHERE delivered_at IS NOT NULL
GROUP BY carrier
ORDER BY delayed_pct DESC;

-- A1.4 (b)  Share of delayed orders by city
SELECT
    ship_to_city,
    COUNT(*) AS delivered_orders,
    ROUND(100 * SUM(delivery_status LIKE 'Late%') / COUNT(*), 1) AS delayed_pct
FROM shipments
WHERE delivered_at IS NOT NULL
GROUP BY ship_to_city
ORDER BY delayed_pct DESC;

-- A1.4 (c)  City x carrier cross-tab
SELECT
    ship_to_city,
    ROUND(100 * SUM(CASE WHEN carrier = 'InHouse' AND delivery_status LIKE 'Late%' THEN 1 ELSE 0 END) / NULLIF(SUM(carrier = 'InHouse'), 0), 0) AS inhouse_pct,
    ROUND(100 * SUM(CASE WHEN carrier = 'Delhivery' AND delivery_status LIKE 'Late%' THEN 1 ELSE 0 END) / NULLIF(SUM(carrier = 'Delhivery'), 0), 0) AS delhivery_pct,
    ROUND(100 * SUM(CASE WHEN carrier = 'Ekart' AND delivery_status LIKE 'Late%' THEN 1 ELSE 0 END) / NULLIF(SUM(carrier = 'Ekart'), 0), 0) AS ekart_pct,
    ROUND(100 * SUM(CASE WHEN carrier = 'BlueDart' AND delivery_status LIKE 'Late%' THEN 1 ELSE 0 END) / NULLIF(SUM(carrier = 'BlueDart'), 0), 0) AS bluedart_pct
FROM shipments
WHERE delivered_at IS NOT NULL
GROUP BY ship_to_city
ORDER BY ship_to_city;
