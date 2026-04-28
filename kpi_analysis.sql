/* ============================================================
CUSTOMER PROFITABILITY & RETENTION INTELLIGENCE SYSTEM
FINAL CONSOLIDATED SQL SCRIPT
============================================================ */
---
## --  PHASE 1: DATA VALIDATION & QUALITY CHECKS

-- 1. Row Count Check

SELECT
	COUNT(*) AS CUSTOMERS_COUNT
FROM
	CUSTOMERS;

SELECT
	COUNT(*) AS ORDERS_COUNT
FROM
	ORDERS;

SELECT
	COUNT(*) AS MARKETING_COUNT
FROM
	MARKETING_SPEND;

SELECT
	COUNT(*) AS SUBSCRIPTION_COUNT
FROM
	SUBSCRIPTION_HISTORY;

SELECT
	COUNT(*) AS FEATURES_COUNT
FROM
	CUSTOMER_FEATURES;

SELECT
	COUNT(*) AS UNIT_ECONOMICS_COUNT
FROM
	CUSTOMER_UNIT_ECONOMICS;

SELECT
	COUNT(*) AS DATE_DIM_COUNT
FROM
	DATE_DIM;

-- 2. Null Value Check
SELECT
	*
FROM
	CUSTOMERS
WHERE
	CUSTOMER_ID IS NULL
	OR SIGNUP_DATE IS NULL
	OR ACQUISITION_CHANNEL IS NULL;

-- 3. Negative Revenue Check
SELECT
	*
FROM
	ORDERS
WHERE
	REVENUE < 0;

-- 4. Order Date vs Signup Date
SELECT
	O.*
FROM
	ORDERS O
	JOIN CUSTOMERS C ON O.CUSTOMER_ID = C.CUSTOMER_ID
WHERE
	O.ORDER_DATE < C.SIGNUP_DATE;

-- 5. Revenue Distribution
SELECT
	MIN(REVENUE) AS MIN_REVENUE,
	MAX(REVENUE) AS MAX_REVENUE,
	AVG(REVENUE) AS AVG_REVENUE
FROM
	ORDERS;

-- 6. Marketing Channel Consistency
SELECT DISTINCT
	CHANNEL
FROM
	MARKETING_SPEND;

-- 7. Duplicate Customer Check
SELECT
	CUSTOMER_ID,
	COUNT(*)
FROM
	CUSTOMERS
GROUP BY
	CUSTOMER_ID
HAVING
	COUNT(*) > 1;

-- 8. Date Range Check
SELECT
	MIN(DATE) AS START_DATE,
	MAX(DATE) AS END_DATE
FROM
	DATE_DIM;

---
## -- PHASE 2: KPI CALCULATIONS (STANDARDIZED)
-- Profit Logic (REFERENCE)
-- profit = revenue - (all costs) - refund
-- 9. Total Revenue
SELECT
	SUM(REVENUE) AS TOTAL_REVENUE
FROM
	ORDERS;

-- 10. Total Cost
SELECT
	SUM(
		COST_OF_GOODS + SHIPPING_COST + DELIVERY_REGION_COST + PAYMENT_PROCESSING_FEE + REFUND_AMOUNT
	) AS TOTAL_COST
FROM
	ORDERS;

-- 11. Total Profit
SELECT
	SUM(
		REVENUE - (
			COST_OF_GOODS + SHIPPING_COST + DELIVERY_REGION_COST + PAYMENT_PROCESSING_FEE
		) - REFUND_AMOUNT
	) AS TOTAL_PROFIT
FROM
	ORDERS;

-- 12. Profit Margin %
SELECT
	ROUND(
		SUM(
			REVENUE - (
				COST_OF_GOODS + SHIPPING_COST + DELIVERY_REGION_COST + PAYMENT_PROCESSING_FEE
			) - REFUND_AMOUNT
		) * 100.0 / NULLIF(SUM(REVENUE), 0),
		2
	) AS PROFIT_MARGIN_PERCENT
FROM
	ORDERS;

-- 13. Total Customers
SELECT
	COUNT(DISTINCT CUSTOMER_ID) AS TOTAL_CUSTOMERS
FROM
	CUSTOMERS;

-- 14. Active Customers
SELECT
	COUNT(DISTINCT CUSTOMER_ID) AS ACTIVE_CUSTOMERS
FROM
	ORDERS;

-- 15. Total Orders
SELECT
	COUNT(ORDER_ID) AS TOTAL_ORDERS
FROM
	ORDERS;

-- 16. Orders per Customer
SELECT
	ROUND(
		COUNT(ORDER_ID)::NUMERIC / COUNT(DISTINCT CUSTOMER_ID),
		2
	) AS ORDERS_PER_CUSTOMER
FROM
	ORDERS;

-- 17. CLV (from view)
SELECT
	AVG(CUSTOMER_CLV) AS AVG_CLV
FROM
	VW_CUSTOMER_INSIGHTS;

-- 18. Total Marketing Spend
SELECT
	SUM(SPEND_AMOUNT) AS TOTAL_MARKETING_SPEND
FROM
	MARKETING_SPEND;

-- 19. CAC
SELECT
	ROUND(
		SUM(SPEND_AMOUNT) / NULLIF(SUM(NEW_CUSTOMERS), 0),
		2
	) AS CAC
FROM
	MARKETING_SPEND;

-- 20. Churn Rate
SELECT
	ROUND(
		COUNT(
			CASE
				WHEN CHURN_FLAG = TRUE THEN 1
			END
		)::NUMERIC / COUNT(*) * 100,
		2
	) AS CHURN_RATE_PERCENT
FROM
	SUBSCRIPTION_HISTORY;

-- 21. Retention Rate
SELECT
	ROUND(
		100 - (
			COUNT(
				CASE
					WHEN CHURN_FLAG = TRUE THEN 1
				END
			)::NUMERIC / COUNT(*) * 100
		),
		2
	) AS RETENTION_RATE_PERCENT
FROM
	SUBSCRIPTION_HISTORY;

---
## --  PHASE 3: BUSINESS ANALYSIS (VIEW-DRIVEN)
-- 22. Revenue by Product Category
SELECT
	PRODUCT_CATEGORY,
	SUM(REVENUE) AS TOTAL_REVENUE
FROM
	ORDERS
GROUP BY
	PRODUCT_CATEGORY
ORDER BY
	TOTAL_REVENUE DESC;

-- 23. Marketing Channel Performance
SELECT
	CHANNEL,
	SUM(NEW_CUSTOMERS) AS CUSTOMERS_ACQUIRED,
	SUM(SPEND_AMOUNT) AS TOTAL_SPEND
FROM
	MARKETING_SPEND
GROUP BY
	CHANNEL
ORDER BY
	CUSTOMERS_ACQUIRED DESC;

-- 24. CAC by Channel
SELECT
	CHANNEL,
	SUM(SPEND_AMOUNT) AS TOTAL_SPEND,
	SUM(NEW_CUSTOMERS) AS CUSTOMERS,
	ROUND(
		SUM(SPEND_AMOUNT) / NULLIF(SUM(NEW_CUSTOMERS), 0),
		2
	) AS CAC_PER_CHANNEL
FROM
	MARKETING_SPEND
GROUP BY
	CHANNEL
ORDER BY
	CAC_PER_CHANNEL;

-- 25. Customer Segmentation (FINAL)
SELECT
	CUSTOMER_SEGMENT,
	COUNT(CUSTOMER_ID) AS NUMBER_OF_CUSTOMERS,
	SUM(CUSTOMER_CLV) AS TOTAL_PROFIT,
	AVG(CUSTOMER_CLV) AS AVG_PROFIT
FROM
	VW_CUSTOMER_INSIGHTS
GROUP BY
	CUSTOMER_SEGMENT
ORDER BY
	TOTAL_PROFIT DESC;

-- 26. Monthly Revenue Trend
SELECT
	DATE_TRUNC('month', ORDER_DATE) AS MONTH,
	SUM(REVENUE) AS MONTHLY_REVENUE
FROM
	ORDERS
GROUP BY
	MONTH
ORDER BY
	MONTH;

-- 27. Top Customers by Profit
SELECT
	CUSTOMER_ID,
	CUSTOMER_CLV AS TOTAL_PROFIT
FROM
	VW_CUSTOMER_INSIGHTS
ORDER BY
	TOTAL_PROFIT DESC
LIMIT
	10;

---
## --  FINAL DATA MODEL (POWER BI READY VIEWS)
-- VIEW 1: KPI SUMMARY
CREATE OR REPLACE VIEW VW_KPI_SUMMARY AS
SELECT
	O.ORDER_DATE,
	SUM(O.REVENUE) AS TOTAL_REVENUE,
	SUM(
		O.COST_OF_GOODS + O.SHIPPING_COST + O.DELIVERY_REGION_COST + O.PAYMENT_PROCESSING_FEE
	) AS TOTAL_COST,
	SUM(
		O.REVENUE - (
			O.COST_OF_GOODS + O.SHIPPING_COST + O.DELIVERY_REGION_COST + O.PAYMENT_PROCESSING_FEE
		) - O.REFUND_AMOUNT
	) AS TOTAL_PROFIT,
	ROUND(
		SUM(
			O.REVENUE - (
				O.COST_OF_GOODS + O.SHIPPING_COST + O.DELIVERY_REGION_COST + O.PAYMENT_PROCESSING_FEE
			) - O.REFUND_AMOUNT
		) * 1.0 / NULLIF(SUM(O.REVENUE), 0),
		4
	) AS PROFIT_MARGIN_PCT,
	COUNT(DISTINCT O.CUSTOMER_ID) AS TOTAL_CUSTOMERS
FROM
	ORDERS O
WHERE
	O.ORDER_STATUS = 'Completed'
GROUP BY
	O.ORDER_DATE;

-- VIEW 2: CUSTOMER INTELLIGENCE
CREATE OR REPLACE VIEW VW_CUSTOMER_INSIGHTS AS
WITH
	BASE AS (
		SELECT
			O.CUSTOMER_ID,
			SUM(O.REVENUE) AS TOTAL_REVENUE,
			SUM(
				O.REVENUE - (
					O.COST_OF_GOODS + O.SHIPPING_COST + O.DELIVERY_REGION_COST + O.PAYMENT_PROCESSING_FEE
				) - O.REFUND_AMOUNT
			) AS CUSTOMER_CLV,
			COUNT(O.ORDER_ID) AS ORDER_COUNT,
			MAX(O.ORDER_DATE) AS LAST_ORDER_DATE
		FROM
			ORDERS O
		WHERE
			O.ORDER_STATUS = 'Completed'
		GROUP BY
			O.CUSTOMER_ID
	)
SELECT
	CUSTOMER_ID,
	TOTAL_REVENUE,
	CUSTOMER_CLV AS TOTAL_PROFIT,
	ORDER_COUNT,
	LAST_ORDER_DATE,
	CUSTOMER_CLV,
	CASE
		WHEN CUSTOMER_CLV < 0 THEN 'Loss Making'
		WHEN CUSTOMER_CLV >= 15000 THEN 'High Value'
		WHEN CUSTOMER_CLV >= 3000 THEN 'Medium Value'
		ELSE 'Low Value'
	END AS CUSTOMER_SEGMENT
FROM
	BASE;

-- VIEW 3: MARKETING PERFORMANCE
CREATE OR REPLACE VIEW VW_MARKETING_PERFORMANCE AS
SELECT
	CAMPAIGN_ID,
	CHANNEL,
	REGION,
	MONTH,
	SUM(SPEND_AMOUNT) AS TOTAL_MARKETING_SPEND,
	SUM(IMPRESSIONS) AS TOTAL_IMPRESSIONS,
	SUM(CLICKS) AS TOTAL_CLICKS,
	SUM(CONVERSIONS) AS TOTAL_CONVERSIONS,
	SUM(NEW_CUSTOMERS) AS TOTAL_NEW_CUSTOMERS,
	ROUND(
		SUM(CONVERSIONS) * 1.0 / NULLIF(SUM(CLICKS), 0),
		4
	) AS CONVERSION_RATE_PCT,
	ROUND(
		SUM(SPEND_AMOUNT) * 1.0 / NULLIF(SUM(NEW_CUSTOMERS), 0),
		2
	) AS CAC
FROM
	MARKETING_SPEND
GROUP BY
	CAMPAIGN_ID,
	CHANNEL,
	REGION,
	MONTH;

---
## --  FINAL TEST

SELECT
	*
FROM
	VW_KPI_SUMMARY
LIMIT
	5;

SELECT
	*
FROM
	VW_CUSTOMER_INSIGHTS
LIMIT
	5;

SELECT
	*
FROM
	VW_MARKETING_PERFORMANCE
LIMIT
	5;





# Changes Durimg Power bi ablysis and reporting:

Region added to customer insights view for better segmentation and analysis.

CREATE VIEW vw_customer_insights AS
WITH customer_orders AS (
    SELECT
        o.customer_id,
        c.region,
        o.order_id,
        o.order_date,
        o.revenue,
        o.cost_of_goods,
        o.shipping_cost,
        o.delivery_region_cost,
        o.payment_processing_fee,
        o.refund_amount
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
),

customer_agg AS (
    SELECT
        customer_id,
        region,
        COUNT(order_id) AS total_orders,
        SUM(revenue) AS total_revenue,
        
        SUM(
            cost_of_goods +
            shipping_cost +
            delivery_region_cost +
            payment_processing_fee +
            refund_amount
        ) AS total_cost,

        MAX(order_date) AS last_order_date,
        MIN(order_date) AS first_order_date
    FROM customer_orders
    GROUP BY customer_id, region
)



SELECT
    customer_id,
    region,
    total_orders,
    total_revenue,
    total_cost,
    (total_revenue - total_cost) AS total_profit,
    (total_revenue - total_cost) AS customer_clv,
    last_order_date,
    first_order_date,
    CASE
        WHEN (total_revenue - total_cost) < 0 THEN 'Loss Making'
        WHEN total_revenue >= 15000 THEN 'High Value'
        WHEN total_revenue >= 3000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_agg;


## Order_id added for churn analyis


CREATE VIEW vw_customer_insights AS
WITH customer_orders AS (
    SELECT
        o.customer_id,
        c.region,
        o.order_id,
        o.order_date,
        o.revenue,
        o.cost_of_goods,
        o.shipping_cost,
        o.delivery_region_cost,
        o.payment_processing_fee,
        o.refund_amount
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
),

customer_agg AS (
    SELECT
        customer_id,
        region,
        COUNT(order_id) AS order_count,   -- 👈 THIS IS KEY
        SUM(revenue) AS total_revenue,

        SUM(
            cost_of_goods +
            shipping_cost +
            delivery_region_cost +
            payment_processing_fee +
            refund_amount
        ) AS total_cost,

        MAX(order_date) AS last_order_date,
        MIN(order_date) AS first_order_date
    FROM customer_orders
    GROUP BY customer_id, region
)

SELECT
    customer_id,
    region,
    order_count,
    total_revenue,
    total_cost,
    (total_revenue - total_cost) AS total_profit,
    (total_revenue - total_cost) AS customer_clv,
    last_order_date,
    first_order_date,
    CASE
        WHEN (total_revenue - total_cost) < 0 THEN 'Loss Making'
        WHEN total_revenue >= 15000 THEN 'High Value'
        WHEN total_revenue >= 3000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_agg;