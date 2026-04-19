-- =============================================
-- SUPERSTORE SQL ANALYSIS
-- "What Excel Couldn't Tell Me"
-- =============================================
-- CONTEXT:
-- A previous Excel project analyzed Superstore sales by region, 
-- category, product, and time period.
-- Key finding from Excel: West region leads in total sales ($725K), 
-- followed by East ($679K), Central ($501K), and South ($392K).
-- 
-- However, Excel pivot tables could not cleanly calculate 
-- average order value per region -- only total aggregates.
-- 
-- This SQL project picks up where Excel left off by asking:
-- Does the region with the highest total sales also generate 
-- the highest value per transaction? 
-- And what else can structured querying reveal that 
-- flat file analysis couldn't?
-- =============================================

-- =============================================
-- PART 1: DATABASE SETUP
-- Table creation and data loading
-- =============================================
CREATE TABLE Customer (
    Customer_id VARCHAR(20) PRIMARY KEY,
    Customer_name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Postal_code VARCHAR(20),
    Region VARCHAR(20)
);
CREATE TABLE Product (
    Product_id VARCHAR(50) PRIMARY KEY,
    Category VARCHAR(50),
    Sub_category VARCHAR(50),
    Product_name VARCHAR(150)
);
CREATE TABLE Orders (
    Order_id VARCHAR(20) PRIMARY KEY,
    Order_date DATE,
    Ship_date DATE,
    Ship_mode VARCHAR(50),
    Customer_id VARCHAR(20) REFERENCES Customer(Customer_id)
);
CREATE TABLE Order_Items (
    Order_id VARCHAR(20) REFERENCES Orders(Order_id),
    Product_id VARCHAR(50) REFERENCES Product(Product_id),
    Sales NUMERIC(10,2),
    Quantity INT,
    Discount NUMERIC(5,2),
    Profit NUMERIC(10,2),
    PRIMARY KEY (Order_id, Product_id)
);
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'order_items'
ORDER BY ordinal_position;
CREATE TABLE staging (
    Row_ID INT,
    Order_ID VARCHAR(20),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(20),
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Postal_Code VARCHAR(20),
    Region VARCHAR(20),
    Product_ID VARCHAR(50),
    Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Product_Name VARCHAR(150),
    Sales NUMERIC(10,2),
    Quantity INT,
    Discount NUMERIC(5,2),
    Profit NUMERIC(10,2)
);
SELECT COUNT(*) FROM staging;

INSERT INTO Customer (Customer_id, Customer_name, Segment, Country, City, State, Postal_code, Region)
SELECT DISTINCT ON (Customer_id) Customer_id, Customer_name, Segment, Country, City, State, Postal_code, Region
FROM staging
ORDER BY Customer_id;

INSERT INTO Product (Product_id, Category, Sub_category, Product_name)
SELECT DISTINCT ON (Product_id) Product_id, Category, Sub_category, Product_name
FROM staging
ORDER BY Product_id;

INSERT INTO Orders (Order_id, Order_date, Ship_date, Ship_mode, Customer_id)
SELECT DISTINCT ON (Order_id) Order_id, Order_date, Ship_date, Ship_mode, Customer_id
FROM staging
ORDER BY Order_id;

INSERT INTO Order_Items (Order_id, Product_id, Sales, Quantity, Discount, Profit)
SELECT DISTINCT ON (Order_id, Product_id) Order_id, Product_id, Sales, Quantity, Discount, Profit
FROM staging
ORDER BY Order_id, Product_id;

SELECT 'Customer' AS table_name, COUNT(*) AS row_count FROM Customer
UNION ALL
SELECT 'Product', COUNT(*) FROM Product
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'Order_Items', COUNT(*) FROM Order_Items;

-- =============================================
-- VALIDATION: Confirm regional totals match Excel findings
-- Expected: West ~$725K, East ~$679K, Central ~$501K, South ~$392K
-- Note: Minor differences expected due to 8 duplicate order-product 
-- combinations removed during data loading.
-- SQL totals are based on clean, deduplicated data.
-- =============================================
SELECT 
    c.Region,
    ROUND(SUM(oi.Sales)::NUMERIC, 2) AS Total_Sales
FROM Order_Items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Region
ORDER BY Total_Sales DESC;

-- Based on the cleaned SQL data, as expected, the numbers differ slightly
-- West: ~$761K | East: ~$685K | Central: ~$466K | South: ~$382K
-- But ranking is still consistent with Excel findings -- West leads, South trails

-- =============================================
-- PART 2: ANALYSIS
-- Business questions and insights
-- =============================================

-- =============================================
-- SECTION A: ORDER ANALYSIS
-- =============================================
--What is the overall Average order value?
SELECT 
    ROUND(SUM(Sales) / COUNT(DISTINCT Order_id):: NUMERIC, 2) AS Avg_Order_Value
FROM Order_Items;
-- The overall average order value is 458.06 

--Does average order value differ by region?
SELECT 
ROUND(SUM (oi.Sales)/COUNT(DISTINCT oi.Order_id):: NUMERIC,2) AS Avg_Order_Value_Reg, c.Region
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON  c.Customer_id = o.Customer_id
GROUP BY c.Region
ORDER BY Avg_Order_Value_Reg DESC;
-- INSIGHT: East has the highest average order value (472.56) despite West leading in total sales 
-- This suggests West wins on volume while East wins on transaction value.

--Compare the overall average to each region's average
SELECT Region, Overall_Avg, Avg_Order_Value_Reg, 
    ROUND(Avg_Order_Value_Reg - Overall_Avg, 2) AS Diff_From_Avg
FROM
    (SELECT 
        (SELECT ROUND(SUM(Sales)/COUNT(DISTINCT Order_id)::NUMERIC, 2) FROM Order_Items) AS Overall_Avg,
        ROUND(SUM(oi.Sales)/COUNT(DISTINCT oi.Order_id)::NUMERIC, 2) AS Avg_Order_Value_Reg, 
        c.Region
    FROM Order_items oi
    JOIN Orders o ON o.Order_id = oi.Order_id
    JOIN Customer c ON c.Customer_id = o.Customer_id
    GROUP BY c.Region) AS Regional_Summary
ORDER BY Avg_Order_Value_Reg DESC;
--INSIGHT: East is the only region above the overall average (+14.50)
-- West leads in total sales but sits below average order value (-5.22)
-- South is weakest on both total sales and transaction value (-11.47) 

-- =============================================
-- DEEPER INVESTIGATION: What explains the regional order value differences?
-- =============================================
-- East leads on average order value ($472) despite West leading on total sales ($760K)
-- West appears to win through volume rather than transaction size
--
-- Two hypotheses to test:
-- H1: Product mix explains it -- West may order more lower-value categories 
--     like Office Supplies, while East orders more high-value Technology products
-- H2: Customer segment explains it -- East may have more Corporate buyers
--     who typically place larger orders than Consumer buyers
--
-- If neither hypothesis holds, we look elsewhere
-- =============================================

SELECT 
    ROUND(SUM(oi.Sales)::NUMERIC, 2) AS Total_Sales,
    COUNT(DISTINCT oi.Order_id) AS Total_Orders,
    ROUND(SUM(oi.Sales)/COUNT(DISTINCT oi.Order_id)::NUMERIC, 2) AS Avg_Order_Value,
	ROUND(
    COUNT(DISTINCT oi.Order_id) * 100.0 /
    SUM(COUNT(DISTINCT oi.Order_id)) OVER (PARTITION BY p.Category),
    2
) AS Region_Share_Of_Category_Orders,
    c.Region,
    p.Category
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
JOIN Product p ON p.Product_id = oi.Product_id
GROUP BY c.Region, p.Category
ORDER BY p.Category, Region_Share_Of_Category_Orders DESC;

-- INSIGHT:
-- West leads in order share across all categories, indicating that its higher total sales
-- are driven by consistently higher transaction volume.

-- In contrast, East places fewer orders, particularly in Technology, but achieves significantly
-- higher average order value within that category.

-- This suggests that East’s stronger performance in average order value may be driven by
-- higher-value transactions rather than order volume, helping explain why East leads in
-- average order value despite West leading in total sales.

SELECT 
    ROUND(SUM(oi.Sales)::NUMERIC, 2) AS Total_Sales,
    COUNT(DISTINCT oi.Order_id) AS Total_Orders,
    ROUND(SUM(oi.Sales)/COUNT(DISTINCT oi.Order_id)::NUMERIC, 2) AS Avg_Order_Value,
	ROUND(
    COUNT(DISTINCT oi.Order_id) * 100.0 /
    SUM(COUNT(DISTINCT oi.Order_id)) OVER (PARTITION BY c.Segment),
    2
) AS Region_Share_Of_Segment_Orders,
    c.Region,
    c.Segment
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Region, c.Segment
ORDER BY c.Segment, Region_Share_Of_Segment_Orders DESC;

-- INSIGHT:

-- Analysis by customer segment shows that West leads in order share across all segments,
-- indicating that its higher total sales are driven by consistently higher transaction volume.

-- However, average order value varies across segments and regions. East outperforms West in
-- both Corporate and Home Office segments, while Central and South show higher values in
-- specific segments such as Consumer and Corporate respectively.

-- These results indicate that no single customer segment fully explains the higher average
-- order value observed in the East region.

-- Instead, East’s stronger performance appears to be driven by consistently higher-value
-- transactions across multiple segments, while West’s high order volume dilutes its overall
-- average order value.

-- Therefore, H2 (customer segment distribution) does not fully explain the difference in
-- regional performance, suggesting that transaction-level behavior, rather than segment mix,
-- is the primary driver.

-- =============================================
-- CONCLUSION: Average Order Value Investigation
-- =============================================
-- The original question was: does the region with the highest total sales 
-- also generate the highest value per transaction?
-- 
-- Answer: No.
-- West leads in total sales through consistently high order volume 
-- across all categories and segments.
-- East leads in average order value through higher-value transactions,
-- particularly in Technology, Corporate, and Home Office segments.
--
-- H1 partially explains this -- East's Technology orders are significantly
-- higher in value than other regions.
-- H2 does not explain this -- segment distribution is similar across regions.
-- The primary driver is transaction-level behavior, not product mix or segment mix.
-- =============================================

-- =============================================
-- SECTION B: SHIPPING ANALYSIS
-- =============================================
--What is the average number of days it takes to ship an order?

SELECT 
	ROUND(AVG(Ship_date - Order_date),2) AS Avg_Shipping_days
FROM Orders;

--It takes 3.96 days on average to ship an order across the whole company.
-- The overall average of 3.96 days is pulled down by Same Day deliveries (0.05 days).
-- Excluding Same Day, fulfillment averages closer to 4-5 days.

--Does shipping time differ by ship mode?
SELECT 
	ROUND(AVG(Ship_date - Order_date),2) AS Avg_Shipping_days, Ship_mode
FROM Orders
GROUP BY Ship_mode
ORDER BY Avg_Shipping_days;

--Yes, it differs by shipping mode, with same-day delivery being the fastest
--followed by First class, second class, and standard class, respectively.

-- Does shipping time differ by region?
SELECT 
	ROUND(AVG(Ship_date - Order_date),2) AS Avg_Shipping_days, c.Region
FROM Orders o
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Region
ORDER BY Avg_Shipping_days;

--The difference between the smallest and largest average shipping days is 0.07
--Therefore, we can say that shipping time is consistent across regions, which 
--suggests the company's fulfillment operations are geographically uniform.

--How is shipping mode distributed across regions?
SELECT
	c.Region,
	o.Ship_mode,
	COUNT (*) AS Total_Orders
FROM Orders o
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Region, o.Ship_Mode
ORDER BY c.Region, Total_Orders DESC;

--West has the highest Standard Class usage (1,015 orders) 
--which is consistent with its slightly higher average shipping days 
--but the difference is too small to be operationally significant.
--Rather the highest Standard class usage can be traced to its high volume sales.

--Does shipping time differ by region AND ship mode combined?
SELECT 
	ROUND(AVG(Ship_date - Order_date),2) AS Avg_Shipping_days, c.Region, o.Ship_mode
FROM Orders o
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Region, o.Ship_Mode
ORDER BY Avg_Shipping_days;
-- INSIGHT:
-- Shipping time is consistent across all regions within each ship mode.
-- Differences within ship modes are negligible (less than 0.15 days in all cases).

-- =============================================
-- HYPOTHESIS: Does shipping mode relate to order value?
-- =============================================
-- Customers who choose faster shipping modes (Same Day, First Class)
-- may be ordering higher value items -- urgency or item importance
-- may drive both the choice of faster shipping and higher spend.
-- Standard Class customers may be ordering lower value, non-urgent items
-- and are willing to wait longer.
-- =============================================

SELECT
    o.Ship_Mode,
    ROUND(SUM(oi.Sales), 2) AS Total_Sales,
    COUNT(DISTINCT o.Order_id) AS Total_Orders,
    ROUND(SUM(oi.Sales) / COUNT(DISTINCT o.Order_id)::NUMERIC, 2) AS Avg_Order_Value
FROM Orders o
JOIN Order_Items oi ON oi.Order_id = o.Order_id
GROUP BY o.Ship_Mode
ORDER BY Avg_Order_Value DESC;

-- INSIGHT:
-- Same-day shipping has the highest average order value, but the pattern is not consistent across other modes.
-- First Class has the lowest average, showing that faster shipping does not reliably correspond to higher-value orders.
-- Therefore, the hypothesis is not supported as a general pattern, and other
-- factors such as customer behavior, pricing strategies, or company policies
-- are likely influencing the observed differences.
-- =============================================
-- CONCLUSION: Average Shipping Time Investigation
-- =============================================
-- INSIGHT:
-- Average shipping time is approximately 4 days across the company.
-- As expected, shipping time differs by ship mode, with Same Day being the fastest
-- and Standard Class the slowest.

-- Regional differences in average shipping time are small (less than 1 day overall),
-- indicating that fulfillment performance is broadly consistent across regions.

-- Further analysis by region and ship mode shows that differences within each ship mode
-- are negligible, suggesting that the small variation in regional shipping averages is
-- driven primarily by shipping mode mix rather than operational inefficiency.

-- In short, no region appears to be materially disadvantaged in fulfillment performance.
-- =============================================


-- =============================================
-- SECTION C: CUSTOMER ANALYSIS
-- =============================================
-- =============================================
-- HYPOTHESIS: Customer Value vs Purchase Frequency
-- =============================================
-- Customers can be segmented based on how they contribute to revenue:
--
-- 1. High value, low frequency customers:
--    These customers generate large order values but purchase infrequently.
--    Their total contribution is driven by a small number of high-value transactions.
--    Losing a single order from these customers could significantly impact revenue.
--
-- 2. High frequency, lower value customers:
--    These customers place many smaller orders over time.
--    Their contribution is more consistent and less dependent on individual transactions.
--
-- This analysis aims to examine whether revenue is driven more by
-- high-value transactions or by repeated purchasing behavior.
--
-- Understanding this distinction helps identify different customer
-- management strategies, as these groups contribute to revenue in fundamentally different ways.
-- =============================================
--Who are the top 10 customers by total sales?

SELECT 
    c.Customer_Name,
    ROUND(SUM(oi.Sales),2) AS Total_Sales,
    COUNT(DISTINCT o.Order_id) AS Total_Orders,
    ROUND(SUM(oi.Sales)/COUNT(DISTINCT o.Order_id)::NUMERIC,2) AS Avg_Order_Value
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Customer_name
ORDER BY Total_Sales DESC
LIMIT 10;

--INSIGHT:
-- Top sales customers vary significantly in order frequency and average order value,
-- suggesting two distinct buyer types: high value low frequency and high frequency lower value.

--Who are the top 10 customers by profit?
SELECT 
    c.Customer_Name,
    ROUND(SUM(oi.Sales),2) AS Total_Sales, ROUND(SUM(oi.Profit),2) AS Total_Profit,
    COUNT(DISTINCT o.Order_id) AS Total_Orders,
    ROUND(SUM(oi.Sales)/COUNT(DISTINCT o.Order_id)::NUMERIC,2) AS Avg_Order_Value
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Customer_name
ORDER BY Total_Profit DESC
LIMIT 10;
-- INSIGHT:
-- Not all top revenue-generating customers appear among the top profit contributors,
-- highlighting that strong sales performance does not guarantee strong profitability.

--Do customers with high sales but low profit receive higher discounts?
SELECT 
    c.Customer_Name,
    ROUND(SUM(oi.Sales),2) AS Total_Sales, ROUND(SUM(oi.Profit),2) AS Total_Profit,
	ROUND(SUM(oi.Profit) / SUM(oi.Sales) * 100 ::NUMERIC, 2) AS Profit_Margin_Pct,
    ROUND(SUM(oi.Discount)/COUNT(DISTINCT o.Order_id)::NUMERIC,2) AS Avg_Order_Discount,
	COUNT(DISTINCT o.Order_id) AS Total_Orders
FROM Order_items oi
JOIN Orders o ON o.Order_id = oi.Order_id
JOIN Customer c ON c.Customer_id = o.Customer_id
GROUP BY c.Customer_name
ORDER BY Total_Sales DESC
LIMIT 10;

-- =============================================
-- CONCLUSION: Customer Analysis
-- =============================================
-- Incorporating profit margin provides a clearer view of true customer value,
-- revealing that high sales do not necessarily translate to profitability.

-- Sean Miller, the highest revenue-generating customer, has a negative profit
-- margin (-7.91%) and the highest average discount (0.74), indicating that
-- excessive discounting can result in losses despite strong sales performance.

-- In contrast, Tamara Chand demonstrates both high profit and the highest
-- profit margin (47.14%), making her the most valuable customer in terms of
-- profitability rather than revenue alone.

-- Similarly, Hunter Lopez, despite ranking lower in total sales, achieves a
-- high profit margin (43.68%) with minimal discounting (0.03), highlighting
-- the importance of pricing discipline in maintaining profitability.

-- Other customers, such as Ken Lonsdale, exhibit high order frequency but
-- low profitability (5.69% margin), suggesting that frequent purchasing alone
-- does not guarantee strong business value.

-- Overall, the results show that customer performance varies significantly
-- across three dimensions: revenue, transaction frequency, and profitability.
-- Profit margin provides the most complete measure of customer value,
-- reinforcing the need to evaluate customers beyond total sales.

-- This pattern is consistent with findings from the Python profitability diagnostic,
-- where heavy discounting was identified as the primary driver of margin erosion
-- at both the regional and product level. The same mechanism is now confirmed
-- at the individual customer level.

-- This reinforces a key business insight: maximizing revenue alone does not
-- guarantee profitability. Sustainable performance depends on balancing
-- transaction volume, pricing strategy, and margin efficiency.

-- =============================================
-- FINAL CONCLUSION
-- =============================================

-- This SQL analysis extended the earlier Excel project by moving from
-- descriptive regional comparisons to order-level validation and deeper
-- investigation of performance drivers.

-- The initial observation showed that West leads in total sales, while
-- East leads in average order value. This prompted further analysis to
-- understand whether these differences were driven by product mix,
-- customer segment distribution, or other factors.

-- Hypothesis testing revealed that product mix (H1) only partially explains
-- the difference, while customer segment distribution (H2) does not provide
-- a consistent explanation. This indicates that neither category preference
-- nor segment composition is the primary driver of regional performance.

-- Further investigation at the customer level showed that revenue and
-- profitability behave differently. Some customers generate high sales
-- through frequent transactions, while others generate higher value through
-- more profitable purchases. Importantly, discounting was identified as a
-- key contributing factor to profitability differences, with extreme cases
-- such as Sean Miller demonstrating that high revenue can result in losses
-- when discount levels are excessive.

-- Shipping analysis confirmed that fulfillment performance is consistent
-- across regions, with minimal variation in shipping time. Differences in
-- overall shipping averages were explained by shipping mode distribution
-- rather than operational inefficiency, indicating that logistics are not
-- a source of regional performance disparity.

-- Overall, the analysis shows that regional performance differences are
-- primarily driven by transaction-level behavior rather than structural
-- factors such as product mix, customer segment, or operational constraints.
-- West’s performance is volume-driven, while East’s advantage comes from
-- higher-value transactions. Profitability further depends on pricing
-- discipline, reinforcing the importance of evaluating both revenue and
-- margin when assessing business performance.

-- This project highlights the value of structured querying in uncovering
-- deeper insights beyond what flat-file analysis can provide, particularly
-- in validating assumptions and isolating the true drivers of business outcomes.
