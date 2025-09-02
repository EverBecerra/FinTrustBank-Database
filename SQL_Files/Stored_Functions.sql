# Stored Function 1
/***
Calculates the ratio of total debt to total liquidity. 
Returns NULL if liquidity is zero to avoid divide-by-zero errors.
Used to evaluate customer financial health.
***/
DELIMITER $$

-- Calculates debt-to-liquidity ratio for a customer.
CREATE FUNCTION Debt_to_Liquidity_Ratio_Function 
	(Debt DECIMAL(11,2), 
    Liquid DECIMAL(14,2)
)
RETURNS FLOAT 
DETERMINISTIC 
BEGIN 
	-- Prevent division by zero.
	IF Liquid = 0 THEN 
		RETURN NULL;
	END IF;
    
    -- Return the debt-to-liquidity ratio.
    RETURN Debt / Liquid; 
END$$

DELIMITER ;

-- Query: Get debt-to-liquidity ratio for each customer.
SELECT 
	cx.Cust_ID, 
	Debt_to_Liquidity_Ratio_Function(
		SUM(cc.Outstanding_Balance),
		SUM(a.Account_Balance)
	) AS Debt_to_Liquidity 
FROM Credit_Cards cc 
INNER JOIN Customers cx 
	ON cc.Customer_ID = cx.Cust_ID 
INNER JOIN `Account` a 
	ON cx.Cust_ID = a.Customer_ID 
GROUP BY cx.Cust_ID
LIMIT 5;


# Stored Function 2
/***
Takes a FixedDeposit ID and returns the annual APR earnings (Amount × Interest Rate). 
Returns NULL if the fixed deposit is closed. 
]***/
DELIMITER $$

-- Returns the annual interest amount (APR) for a fixed deposit if it’s active.
CREATE FUNCTION APR_Return_Function (FD_ID INT)
RETURNS FLOAT
DETERMINISTIC 
BEGIN
	DECLARE InterstEarned FLOAT;
    DECLARE DepositStatus VARCHAR(20);
    
    -- Retrieve interest amount and status for the given fixed deposit.
    SELECT fd.Amount * ROUND((fd.Interest_Rate/100),2), fd.Status
    INTO InterstEarned, DepositStatus
    FROM Fixed_Deposits fd
    WHERE FixedDeposits_ID = FD_ID;

	-- Only return interest if the deposit is still active.
	IF DepositStatus = 'Closed' THEN 
		RETURN NULL;
	ELSEIF DepositStatus = 'Active' THEN 
		RETURN InterstEarned;
	END IF;
END $$

DELIMITER ;

-- Example 1: Run function for a specific fixed deposit.
SELECT * 
FROM Fixed_Deposits 
WHERE FixedDeposits_ID = 4;

SELECT APR_Return_Function(4) AS 'APR_Return';

-- Example 2: Run function across multiple fixed deposits.
SELECT 
	Customer_ID, 
	FixedDeposits_ID, 
    Amount, 
    Interest_Rate,
    Status,
	APR_Return_Function(FixedDeposits_ID) AS 'APR_Return'
FROM Fixed_Deposits
LIMIT 5;

-- Example 3: Check function behavior for a closed deposit (should return NULL).
SELECT 
	Customer_ID, 
    FixedDeposits_ID, 
    Amount, 
    Interest_Rate, 
    APR_Return_Function(FixedDeposits_ID) AS 'APR_Return'
FROM Fixed_Deposits 
WHERE Status = 'Closed'
LIMIT 1;


# Stored Function 3
/***
Suggests appropriate account types based on customer's age 
calculated from their birthdate in the Customers table.
***/
DELIMITER $$

CREATE FUNCTION Account_Suggestion_byAge(Customer_ID INT)
RETURNS VARCHAR(250)
DETERMINISTIC
BEGIN

	-- Declares variables to store date of birth, age and results.
	DECLARE DOB DATE;
    DECLARE Age INT;
    DECLARE Result VARCHAR(250);
    
    -- Attains the customer's birthdate from Customers table.
    SELECT Cust_Birth_Date 
    INTO DOB
    FROM Customers
    WHERE Cust_ID = Customer_ID;
    
    -- Calculates customer age using current date, since age is not defined in the table.
    SET Age = TIMESTAMPDIFF(YEAR, DOB, CURDATE());
    
    -- Determine account suggestion based on age
    IF Age < 18 THEN
		SET Result = 'Youth Savings/Checkings - Parental Approval Required';
	ELSEIF Age <= 25 THEN
		SET Result = 'Student Checking and/or High-Yield Savings';
	ELSEIF Age <=59 THEN
		SET Result = 'Standard Checking and High-Yield Savings and Fixed Deposits';
	ELSE
		SET Result = 'Senior Benefits Account';
    END IF;
    
    RETURN Result;
END$$

DELIMITER ;

-- Example 1: Get account suggestion for a specific customer.
SELECT Account_Suggestion_byAge(15) AS Suggested_Account;

-- Example 2: Get suggestions for all customers.
SELECT 
    Cust_ID,
    CONCAT(Cust_First_Name, ' ', Cust_Last_Name) AS Full_Name,
    Account_Suggestion_byAge(Cust_ID) AS Suggested_Account
FROM Customers;


# Stored Function 4
/***
Calculates the credit utilization ratio, a key metric used to assess a customer’s credit risk.
It returns the ratio as a decimal value.
***/
DELIMITER $$

-- Creates a function that returns the credit utilization as a percentage value.
CREATE FUNCTION Card_Utilization(
    Balance DECIMAL(10,2),
    `Limit` DECIMAL(10,2)
) 
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE Utilization DECIMAL(5,2);

    -- Handle division by zero.
    IF `Limit` = 0 THEN
        RETURN 0;
    ELSE		
		-- Calculate and round the utilization percentage.
        SET Utilization = (Balance / `Limit`) * 100;
        RETURN ROUND(Utilization, 2);
    END IF;
END$$

DELIMITER ;

-- Example 1: Query displays card utilization percentages for each credit card.
SELECT 
    Card_ID,
    Customer_ID,
    Card_Type,
    Outstanding_Balance,
    Credit_Limit,
    CONCAT(Card_Utilization(Outstanding_Balance, Credit_Limit),'%') AS Utilization_Percentage
FROM Credit_Cards
LIMIT 10;


# Stored Function 5
/***
Stored function to calculate the total value of all active fixed deposits for a specific customer. 
If no active deposits exist, returns 0.
***/
DELIMITER $$

CREATE FUNCTION Total_Fixed_Deposit_by_Customer (Cx_ID INT)
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE Total_fd DECIMAL(15,2);

    -- Get total of active fixed deposits or 0 if none.
    SELECT COALESCE(SUM(Amount), 0)
    INTO Total_fd
    FROM Fixed_Deposits
    WHERE Customer_ID = Cx_ID
      AND Status = 'Active';

    RETURN Total_fd;
END $$

DELIMITER ;

-- Example 1: View total active fixed deposits for customer ID = 4.
SELECT * 
FROM Fixed_Deposits 
WHERE Customer_ID = 4;

SELECT Total_Fixed_Deposit_by_Customer(4) AS Total_FD_Balance;
