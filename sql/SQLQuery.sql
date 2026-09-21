USE Northwind;
GO

ALTER TABLE [dbo].[category clean] ADD CONSTRAINT PK_category_clean PRIMARY KEY ([CategoryID]);
ALTER TABLE [dbo].[customer clean] ADD CONSTRAINT PK_customer_clean PRIMARY KEY ([CustomerID]);
ALTER TABLE [dbo].[product_clean] ADD CONSTRAINT PK_product_clean PRIMARY KEY ([ProductID]);
ALTER TABLE [dbo].[orders clean done] ADD CONSTRAINT PK_orders_clean_done PRIMARY KEY ([OrderID]);
GO

-- 1.  NOT NULL
ALTER TABLE [dbo].[order details clean] 
ALTER COLUMN [OrderID] INT NOT NULL;

ALTER TABLE [dbo].[order details clean] 
ALTER COLUMN [ProductID] INT NOT NULL;
GO

-- 2.  Composite Primary Key
ALTER TABLE [dbo].[order details clean]
ADD CONSTRAINT PK_order_details_clean PRIMARY KEY ([OrderID], [ProductID]);
GO
USE Northwind;
GO

-- ==========================================
-- STEP 1: FIX DATA TYPES FOR FOREIGN KEYS
-- ==========================================

-- Convert CategoryID in product_clean table to INT to match category clean table
ALTER TABLE [dbo].[product_clean]
ALTER COLUMN [CategoryID] INT NULL;
GO

-- Convert ProductID in order details clean table to INT
ALTER TABLE [dbo].[order details clean]
ALTER COLUMN [ProductID] INT NULL;
GO

-- ==========================================
-- STEP 2: CREATE FOREIGN KEY RELATIONSHIPS
-- ==========================================

-- 1. Link Product Table to Category Table
ALTER TABLE [dbo].[product_clean]
ADD CONSTRAINT FK_Product_Category 
FOREIGN KEY ([CategoryID]) REFERENCES [dbo].[category clean]([CategoryID]);
GO

-- 2. Link Orders Table to Customer Table
ALTER TABLE [dbo].[orders clean done]
ADD CONSTRAINT FK_Orders_Customer 
FOREIGN KEY ([CustomerID]) REFERENCES [dbo].[customer clean]([CustomerID]);
GO

-- 3. Link Order Details Table to Orders Table
ALTER TABLE [dbo].[order details clean]
ADD CONSTRAINT FK_OrderDetails_Orders 
FOREIGN KEY ([OrderID]) REFERENCES [dbo].[orders clean done]([OrderID]);
GO

-- 4. Link Order Details Table to Product Table
ALTER TABLE [dbo].[order details clean]
ADD CONSTRAINT FK_OrderDetails_Product 
FOREIGN KEY ([ProductID]) REFERENCES [dbo].[product_clean]([ProductID]);
GO

-- ==========================================
-- SQL ANALYSIS - PART 2
-- ==========================================

USE Northwind;
GO

--Question 1: Best Performing Products
SELECT TOP 10
    p.ProductID,
    p.ProductName,
    SUM(od.Quantity) AS TotalUnitsSold,
    CAST(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))) AS DECIMAL(10,2)) AS TotalRevenue
FROM [dbo].[order details clean] od
INNER JOIN [dbo].[product_clean] p ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalRevenue DESC;
GO

-- Question 2: Highest Revenue Customers
SELECT TOP 10
    c.CustomerID,
    c.CompanyName,
    c.ContactName,
    COUNT(DISTINCT o.OrderID) AS TotalOrdersCount,
    CAST(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))) AS DECIMAL(10,2)) AS TotalRevenue
FROM [dbo].[order details clean] od
INNER JOIN [dbo].[orders clean done] o ON od.OrderID = o.OrderID
INNER JOIN [dbo].[customer clean] c ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.CompanyName, c.ContactName
ORDER BY TotalRevenue DESC;
GO

-- Question 3: Most Profitable Categories
SELECT 
    c.CategoryID,
    UPPER(c.CategoryName) AS CategoryName,
    COUNT(DISTINCT o.OrderID) AS TotalOrdersCount,
    SUM(od.Quantity) AS TotalUnitsSold,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))), 2) AS TotalRevenue
FROM [dbo].[category clean] c
LEFT JOIN [dbo].[product_clean] p ON c.CategoryID = p.CategoryID
LEFT JOIN [dbo].[order details clean] od ON p.ProductID = od.ProductID
LEFT JOIN [dbo].[orders clean done] o ON od.OrderID = o.OrderID
WHERE p.Discontinued = '0' OR p.Discontinued IS NULL
GROUP BY c.CategoryID, c.CategoryName
ORDER BY TotalRevenue DESC;
GO

-- Question 4: Regional Performance
CREATE OR ALTER VIEW VW_RegionalPerformance AS
SELECT 
    ISNULL(o.ShipCountry, 'Unknown') AS Country,
    ISNULL(o.ShipRegion, 'N/A') AS Region,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    (
        SELECT SUM(od.Quantity) 
        FROM [dbo].[order details clean] od 
        WHERE od.OrderID IN (SELECT o2.OrderID FROM [dbo].[orders clean done] o2 WHERE ISNULL(o2.ShipCountry, 'Unknown') = ISNULL(o.ShipCountry, 'Unknown'))
    ) AS RegionalUnitsSold,
    CAST(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))) AS DECIMAL(10,2)) AS TotalRevenue
FROM [dbo].[orders clean done] o
INNER JOIN [dbo].[order details clean] od ON o.OrderID = od.OrderID
GROUP BY o.ShipCountry, o.ShipRegion;
GO

SELECT TOP 10 * FROM VW_RegionalPerformance ORDER BY TotalRevenue DESC;
GO

-- Question 5: Performance Over Time
WITH MonthlySalesCTE AS (
    SELECT 
        YEAR(o.OrderDate) AS SalesYear,
        MONTH(o.OrderDate) AS SalesMonth,
        CAST(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))) AS DECIMAL(10,2)) AS MonthlyRevenue
    FROM [dbo].[orders clean done] o
    INNER JOIN [dbo].[order details clean] od ON o.OrderID = od.OrderID
    WHERE o.OrderDate IS NOT NULL
    GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
)
SELECT 
    SalesYear,
    SalesMonth,
    MonthlyRevenue,
    SUM(MonthlyRevenue) OVER (ORDER BY SalesYear, SalesMonth) AS RunningTotalRevenue,
    LAG(MonthlyRevenue, 1, 0) OVER (ORDER BY SalesYear, SalesMonth) AS PreviousMonthRevenue
FROM MonthlySalesCTE
ORDER BY SalesYear, SalesMonth;
GO

-- Question 6: Underperforming Products & Inactive Customers
SELECT TOP 10
    p.ProductID,
    p.ProductName,
    ISNULL(SUM(od.Quantity), 0) AS TotalUnitsSold,
    ISNULL(CAST(SUM(od.UnitPrice * od.Quantity * (1 - ISNULL(od.Discount, 0))) AS DECIMAL(10,2)), 0) AS TotalRevenue
FROM [dbo].[order details clean] od
RIGHT JOIN [dbo].[product_clean] p ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalRevenue ASC;
GO

SELECT c.CustomerID, c.CompanyName, c.ContactName
FROM [dbo].[customer clean] c
WHERE c.CustomerID IN (
    SELECT CustomerID FROM [dbo].[customer clean]
    EXCEPT
    SELECT CustomerID FROM [dbo].[orders clean done]
);
GO