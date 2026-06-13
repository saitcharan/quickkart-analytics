SELECT status as Order_Status, COUNT(*) AS orders,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct
FROM orders
GROUP BY status
ORDER BY orders DESC;

SELECT CONCAT(ROUND(SUM(unit_price * quantity)/1e9 ,2),' E9')as gmv,
       CONCAT(ROUND(SUM(unit_price* quantity * platform_fee_pct)/1e9,2), ' E9')as platform_fee
FROM OJ_Commerce.order_items;


SELECT shipments_per_order, COUNT(*) AS num_orders
FROM (
  SELECT order_id, COUNT(*) AS shipments_per_order
  FROM shipments
  GROUP BY order_id
) t
GROUP BY shipments_per_order;

SELECT o.status, COUNT(*) AS n
FROM orders o
LEFT JOIN shipments s ON s.order_id = o.order_id
WHERE s.order_id IS NULL
GROUP BY o.status;

SELECT delivery_status, COUNT(*) AS n,
       SUM(delivered_at IS NULL) AS missing_delivered_date
FROM shipments
GROUP BY delivery_status
ORDER BY n DESC;

SELECT COUNT(*) AS delivered_orders,
       ROUND(100*SUM(s.delivery_status <> 'OnTime')/COUNT(*),1)                       AS pct_delayed_by_bucket,
       ROUND(100*SUM(DATE(s.delivered_at) > o.promised_delivery_date)/COUNT(*),1)     AS pct_delayed_by_formula
FROM shipments s
JOIN orders o ON o.order_id = s.order_id
WHERE s.delivered_at IS NOT NULL;

SELECT DATEDIFF(promised_delivery_date, created_at) AS promise_days,
       is_fast_delivery_eligible AS fast,
       COUNT(*) AS n
FROM orders
GROUP BY promise_days, fast
ORDER BY promise_days;