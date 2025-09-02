# Complex Query 1
-- Retrieves employee details including, Employee ID, Employee name (concat first + last name), Job title, Managed Branch (Branch ID + Name).
-- Uses an INNER JOIN between Employees and Branches on Branch_ID.
SELECT 
	emp.Employee_ID,
	CONCAT(emp.First_Name, ' ', emp.Last_Name) AS Employee_Name,
	emp.Job_Title,
	CONCAT(b.Branch_ID, ' - ', b.Branch_Name) AS Managed_Branch,
	b.Address
FROM Employees emp
JOIN Branches b 
	ON emp.Branch_ID = b.Branch_ID
ORDER BY Employee_ID;


# Complex Query 2
-- Retrieves each customer's total account balance and number of accounts, ordered from highest to lowest balance.
SELECT 
	DISTINCT c.Cust_ID,
	CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Customer_Name,
	c.Cust_email, 
    c.Cust_phone,
	COUNT(a.Account_ID) AS Total_Accounts,
	CONCAT('$ ',SUM(a.Account_Balance)) AS Total_Account_Balance			-- Could handle NULLs with COALESCE(...,0), but leaving NULL highlights customers with no account.
FROM Customers c
LEFT JOIN `Account` a 
	ON c.Cust_ID = a.Customer_ID
GROUP BY 
	c.Cust_ID, 
    Customer_Name, 
    c.Cust_Email, 
    c.Cust_Phone
ORDER BY 
	(Total_Account_Balance IS NULL),
    Total_Account_Balance DESC;


# Complex Query 3
-- Returns the total amount of deposits or withdrawls in the ATM_Service table, grouped by Service Type and Branch (Name and ID). 
SELECT 
    b.Branch_ID,
    b.Branch_Name,
    a.Service_Type,
    SUM(a.Amount) AS Branch_Transaction
FROM Branches b
JOIN Atm_Service a 
	ON b.Branch_ID = a.Branch_ID
WHERE a.Service_Type IN ('Deposit', 'Withdrawal')
GROUP BY 
	b.Branch_ID, 
	b.Branch_Name,
    a.Service_Type
ORDER BY b.Branch_Name;
	

# Complex Query 4
-- This query returns the customer name (first + last name), customer ID, the total number of customer service tickets with an active status, and the count of distinct accounts per customer.
SELECT 
    c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Customer_Name,
    COUNT(DISTINCT a.Account_ID) AS Active_Accounts,
    COUNT(t.Status) AS Open_Tickets
FROM Customers c
JOIN `Account` a 
	ON c.Cust_ID = a.Customer_ID 
JOIN Customer_Service_Tickets t 
	ON a.Account_ID = t.Account_ID 
WHERE t.Status in ('In Progress', 'Open')
GROUP BY c.Cust_ID;


# Complex Query 5
-- Displays each customer's total debt from credit cards with outstanding balance over 5000.
-- Along with the count of qualifying accounts, sorted from highest to lowest total debt.
SELECT 
	c.Cust_ID,
	c.Cust_First_Name, 
	c.Cust_Last_Name, 
    SUM(z.Outstanding_Balance) AS Total_Debt,
    COUNT(z.Outstanding_Balance) AS Number_of_Accounts
FROM Credit_Cards z
JOIN Customers c 
	ON z.Customer_ID = c.Cust_ID
WHERE z.Outstanding_Balance > 5000
GROUP BY 
	c.Cust_ID,
	c.Cust_First_Name, 
	c.Cust_Last_Name
ORDER BY Total_Debt DESC;


# Complex Query 6
-- Retrieves customer details (ID, name, email) along with their active fixed deposit records 
-- (deposit ID, amount, and maturity date) and the associated account (ID, type, and balance). Only includes accounts that are active and of type 'Savings' or 'Checking'.
SELECT 
    c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Cust_Name,
    c.Cust_Email,
    fd.FixedDeposits_ID,
    fd.Amount AS Fixed_Deposit_Amount,
    fd.Maturity_Date,
    a.Account_ID AS Primary_Account_ID,
    a.Account_Type AS Primary_Account_Type,
    a.Account_Balance AS Primary_Account_Balance
FROM Customers c
JOIN Fixed_Deposits fd 
	ON c.Cust_ID = fd.Customer_id
JOIN `Account` a 
	ON c.Cust_ID = a.Customer_ID
WHERE a.Account_Type IN ('Savings', 'Checking') 
	AND a.Status = 'Active';


# Complex Query 7
-- This query returns the total value of fixed deposits for eeach customer along with their beneficiary information, grouped by customer and beneficiary.
SELECT 
    c.Cust_ID,
    c.Cust_First_Name,
    c.Cust_Last_Name,
    ab.Beneficiary_Name,
    SUM(fd.Amount) AS Total_Fixed_Deposit_Holdings
FROM `Account` a
JOIN Account_Beneficiaries ab 
	ON a.Account_ID = ab.Account_ID
JOIN Customers c 
	ON a.Customer_ID = c.Cust_ID
LEFT JOIN Fixed_Deposits fd 
	ON c.Cust_ID = fd.Customer_id
GROUP BY 
	c.Cust_ID, 
	c.Cust_First_Name, 
	c.Cust_Last_Name, 
	ab.Beneficiary_Name
ORDER BY Total_Fixed_Deposit_Holdings DESC;


# Complex Query 8
-- This query returns each customer's total balance by combining their account balances and fixed deposit amounts, grouped by customer and ordered descending.
SELECT 
	c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Customer_Name,
    COALESCE(SUM(a.Account_Balance), 0) + COALESCE(SUM(fd.Amount), 0) AS Total_Balance
FROM Customers c
LEFT JOIN `Account` a
	ON c.Cust_ID = a.Customer_ID
LEFT JOIN Fixed_Deposits fd 
	ON c.Cust_ID = fd.Customer_ID
GROUP BY c.Cust_ID
ORDER BY Total_Balance DESC;