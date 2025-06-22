create database e_commerce;
use e_commerce;

create table Customers(
	ID INTEGER PRIMARY KEY,
    Gender CHAR(1),
    Location VARCHAR(40),
    Tenure_months INTEGER,
    Offline_spend FLOAT,
    Online_spend FLOAT
);

create table Products(
	SKU VARCHAR(14) PRIMARY KEY,
    Product_Description VARCHAR(150),
    Product_Category VARCHAR(30),
    Avg_Price FLOAT
);

create table Transactions(
	ID INTEGER,
    Customer_ID INTEGER references Customers(ID),
    Transaction_date date
);

CREATE TABLE Transactions_Financials (
    Transaction_ID INTEGER REFERENCES Transactions(ID),
    Item_Index INTEGER,
    PRIMARY KEY (Transaction_ID, Item_Index),
    Product_SKU VARCHAR(14) REFERENCES Products(SKU),
    Quantity INTEGER,
    Delivery_Charges FLOAT,
    Coupon_Status VARCHAR(15),
    Coupon_Code VARCHAR(10),
    Discount_pct FLOAT,
    GST FLOAT
);


/* Optimized tables */
create table Products_OPT(
	SKU VARCHAR(14) PRIMARY KEY,
    Product_Description VARCHAR(150),
    Product_Category VARCHAR(30),
    Avg_Price FLOAT,
    check(Avg_Price > 0) 
);

create table Transactions_OPT(
	ID INTEGER PRIMARY KEY,
    Customer_ID INTEGER,
	index new_customer_id(Customer_ID),
    foreign key(Customer_ID) references Customers(ID),
    Transaction_date date
);

CREATE TABLE Transactions_Financials_OPT(
    Transaction_ID INTEGER,
	index new_transaction_id(Transaction_ID),
    FOREIGN KEY (Transaction_ID) REFERENCES Transactions_OPT(ID),
    Item_Index INTEGER,
    PRIMARY KEY (Transaction_ID, Item_Index),
    Product_SKU VARCHAR(14), 
    index new_product_sku(Product_SKU),
    FOREIGN KEY(Product_SKU) REFERENCES Products_OPT(SKU),
    Quantity INTEGER,
    Delivery_Charges FLOAT,
    Coupon_Status VARCHAR(15),
    Coupon_Code VARCHAR(10),
    Discount_pct FLOAT,
    GST FLOAT
);

-- HW1
-- Query 1: Returns all information of the customers living in New York ordered by tenure month in descendent order
SELECT *
FROM Customers
WHERE Location = 'New York'
ORDER BY Tenure_months DESC;


-- Query 2: Returns all product information bought by a specific customer (with ID 15527) order by avg price in descendent order
SELECT DISTINCT P.*
FROM Products P JOIN Transactions_Financials TF ON P.SKU = TF.Product_SKU
		JOIN Transactions T ON TF.Transaction_ID = T.ID
WHERE T.Customer_ID = 15527
ORDER BY P.Avg_Price DESC;


-- Query 3: Returns the ID of the customer, the product description, and the transaction date only if the avg_price < $$$
SELECT DISTINCT T.Customer_ID, P.Product_Description, T.Transaction_Date
FROM Products P JOIN Transactions_Financials TF ON P.SKU = TF.Product_SKU
		JOIN Transactions T ON TF.Transaction_ID = T.ID
WHERE P.Avg_Price < 170;


-- Query 4: Return the number of transactions of each customer who made a transaction in a specific month
SELECT Customer_ID, COUNT(*) AS Num_Transactions
FROM Transactions
where MONTH(Transaction_date) = 05 
GROUP BY Customer_ID;


-- Query 5: Returns the total quantity bought for each product category
SELECT P.Product_Category, SUM(TF.Quantity) AS Total_Quantity
FROM Products P JOIN Transactions_Financials TF ON P.SKU = TF.Product_SKU
GROUP BY P.Product_Category;


-- Query 6: Calculates the total and raw total spent by each customer
SELECT T.Customer_ID, 
		SUM((P.Avg_Price * TF.Quantity)) AS Raw_Total_Spent,
       SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_Spent
FROM Transactions_Financials TF JOIN Transactions T ON TF.Transaction_ID = T.ID 
		JOIN Products P ON TF.Product_SKU = P.SKU
GROUP BY T.Customer_ID;


-- Query 7: Returns the quantity bought by each customer for each product in a specific month ordered by the total quantity in descendent order
SELECT C.ID, P.Product_Description, P.SKU, sum(TF.quantity) as Total_Quantity
FROM Customers C JOIN Transactions T ON C.ID = T.Customer_ID
		JOIN Transactions_Financials TF ON T.ID = TF.Transaction_ID
		JOIN Products P ON TF.Product_SKU = P.SKU
WHERE MONTH(T.Transaction_date) = 10 
GROUP BY C.ID, P.SKU
ORDER BY Total_Quantity DESC;


-- Query 8: Returns the total number of coupons used per customer, and the total number of transactions, if the customer has used more than a certain coupons
SELECT 
    T.Customer_ID,
    COUNT(DISTINCT U.TID) AS Total_Coupon_Used,
    COUNT(DISTINCT T.ID) AS Tot_Transactions
FROM Transactions T JOIN Transactions_Financials TF ON T.ID = TF.Transaction_ID
		LEFT JOIN (
			SELECT DISTINCT T1.ID AS TID, T1.Customer_ID
			FROM Transactions T1
			JOIN Transactions_Financials TF1 ON T1.ID = TF1.Transaction_ID
			WHERE TF1.Coupon_Status = 'Used'
		) AS U ON T.ID = U.TID
GROUP BY T.Customer_ID
HAVING Total_Coupon_Used > 5;


-- Query 9: Returns the customer who spent the most
SELECT T.Customer_ID, 
       SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_Spent
FROM Transactions_Financials TF JOIN Transactions T ON TF.Transaction_ID = T.ID
		JOIN Products P ON TF.Product_SKU = P.SKU
GROUP BY T.Customer_ID
HAVING Total_Spent = (
    SELECT MAX(total_spent)
    FROM (
        SELECT SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS total_spent
        FROM Transactions_Financials TF JOIN Transactions T ON TF.Transaction_ID = T.ID
				JOIN Products P ON TF.Product_SKU = P.SKU
        GROUP BY T.Customer_ID
    ) AS subquery
);


/*
	Query 10: Returns detailed spending information for customers who have been with the company 
			for more than a year and used coupons
*/
SELECT 
    C.ID AS Customer_ID,
    C.Gender,
    C.Location,
    C.Tenure_months,
    SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_spent,
    COUNT(distinct T.ID) AS Total_Transactions,
    SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges)/COUNT(distinct T.ID) AS Avg_Spend_Per_Transaction,
    MAX(T.Transaction_date) AS Last_Purchase_Date
FROM Customers C JOIN Transactions T ON C.ID = T.Customer_ID
		JOIN Transactions_Financials TF ON T.ID = TF.Transaction_ID
        JOIN Products P ON TF.Product_SKU = P.SKU
WHERE C.Tenure_months > 12  
		AND TF.Coupon_Status = 'Used' 
GROUP BY C.ID, C.Gender, C.Location, C.Tenure_months
ORDER BY Total_Spent DESC; 






-- HW2

-- Query 6 Optimized version (Adding indexes)
-- ~ 110 ms ---> ~ 40 ms
SELECT T.Customer_ID, 
		SUM((P.Avg_Price * TF.Quantity)) AS Raw_Total_Spent,
       SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_Spent
FROM Transactions_Financials_OPT TF JOIN Transactions_OPT T ON TF.Transaction_ID = T.ID 
		JOIN Products_OPT P ON TF.Product_SKU = P.SKU
GROUP BY T.Customer_ID;


-- Query 8 Optimized version (Create view and adding indexes)
-- ~ 130 ms ---> ~ 80 ms
CREATE VIEW Coupon_Usage AS
SELECT 
    T.Customer_ID,
    T.ID AS Transaction_ID
FROM Transactions_OPT T JOIN Transactions_Financials_OPT TF ON T.ID = TF.Transaction_ID
WHERE TF.Coupon_Status = 'Used';

SELECT 
    T.Customer_ID,
    COUNT(DISTINCT CU.Transaction_ID) AS Total_Coupon_Used,
    COUNT(DISTINCT T.ID) AS Tot_Transactions
FROM Transactions_OPT T LEFT JOIN Coupon_Usage CU ON T.ID = CU.Transaction_ID
GROUP BY T.Customer_ID
HAVING Total_Coupon_Used > 5;


-- Query 9 Optimized version (rewrite the query and adding indexes)
-- ~ 190 ms ---> ~ 103 ms
SELECT T.Customer_ID, 
       SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_Spent
FROM Transactions_Financials_OPT TF JOIN Transactions_OPT T ON TF.Transaction_ID = T.ID
		JOIN Products_OPT P ON TF.Product_SKU = P.SKU
GROUP BY T.Customer_ID
ORDER BY Total_Spent DESC
LIMIT 1;


-- Query 10 optimized version with view and indexes
-- ~ 110 ms ---> ~ 95 ms 
CREATE VIEW customer_coupon_stats AS
SELECT 
    T.Customer_ID,
    SUM((P.Avg_Price * TF.Quantity) * (1 - COALESCE(TF.Discount_pct, 0)/100) + TF.GST + TF.Delivery_Charges) AS Total_spent,
    COUNT(DISTINCT T.ID) AS Total_Transactions,
    MAX(T.Transaction_date) AS Last_Purchase_Date
FROM Transactions_OPT T JOIN Transactions_Financials_OPT TF ON T.ID = TF.Transaction_ID
		JOIN Products P ON TF.Product_SKU = P.SKU
WHERE TF.Coupon_Status = 'Used'
GROUP BY T.Customer_ID;

SELECT 
    C.ID AS Customer_ID,
    C.Gender,
    C.Location,
    C.Tenure_months,
    CCS.Total_spent,
    CCS.Total_Transactions,
    CCS.Total_spent/CCS.Total_Transactions AS Avg_Spend_Per_Transaction,
    CCS.Last_Purchase_Date
FROM Customers C JOIN customer_coupon_stats CCS ON C.ID = CCS.Customer_ID
WHERE C.Tenure_months > 12
ORDER BY CCS.Total_spent DESC;