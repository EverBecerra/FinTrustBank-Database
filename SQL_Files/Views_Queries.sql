# View 1
/*** 
This view summarizes each customer's accounts by showing their total balance and number of beneficiaries. 
***/
CREATE VIEW Customer_Account_Overview_View AS
SELECT 
    c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_last_name) AS Customer_Name,
    SUM(a.Account_Balance) AS Total_Balance,
    COUNT(ab.Beneficiary_ID) AS Number_of_Beneficiaries
FROM Customers c 
JOIN `Account` a 
	ON c.Cust_ID = a.Customer_ID
LEFT JOIN Account_Beneficiaries ab 
	ON a.Account_ID = ab.Account_ID
GROUP BY
	c.Cust_ID,
	Customer_Name;

-- Call View: Query the view to display account balances and beneficiaries per customer.
SELECT * 
FROM Customer_Account_Overview_View;


# View 2 
/***
This view displays each loan application with the customer’s name, requested amount, decision status, and score. 
***/
CREATE VIEW Loan_Status_View AS
SELECT 
    la.Application_ID,
    c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Customer_Name,
    la.Amount_Requested AS LoanAmount,
    als.Decision AS LoanStatus,
    als.LA_Score AS Score
FROM Loan_Applications la
JOIN Customers c 
	ON la.Customer_ID = c.Cust_ID
LEFT JOIN Procedure_Audit_Loan_Scores als 
	ON la.Application_ID = als.Application_ID;
    
-- Call View: Query the view to see loan applications with their approval status and scores.
SELECT *
FROM Loan_Status_View;


# View 3
/***
This view summarizes branch performance by showing the number of accounts and total balance managed at each branch. 
***/
CREATE VIEW Branch_Performance_View AS
SELECT 
    b.Branch_ID,
    b.Branch_Name,
    COUNT(a.Account_ID) AS Total_Accounts,
    SUM(a.Account_Balance) AS Total_Balance
FROM 
    Branches b
LEFT JOIN Customers c
	ON b.Branch_ID = c.Branch_ID
LEFT JOIN `Account` a 
	ON c.Cust_ID = a.Customer_ID
GROUP BY 
    b.Branch_ID, 
	b.Branch_Name;

-- Call View: Query the view to see accounts and balances aggregated by branch.
SELECT *
FROM Branch_Performance_View;


# View 4
/***
This view aggregates in-branch transactions by service type, showing total count and amount per type. 
***/
CREATE VIEW Daily_Transaction_Summary_View AS
SELECT 
    Service_Type AS Transaction_Type,
    COUNT(*) AS Transaction_Count,
    SUM(Amount) AS Total_Amount
FROM In_Branch_Transactions
GROUP BY Service_Type;

-- Call View: Query the view to see daily totals grouped by transaction type.
SELECT *
FROM Daily_Transaction_Summary_View;
