# Stored Procedure 1
/***  
This procedure evaluates whether a loan applicant is eligible for the requested amount. 
Eligibility is dependent on a applicant's credit score, amount requested, and total account balance

Loan Application Score (LAS) formula:
	LAS = (Credit_Score / 850) * 0.5 + (Total_Account_Balance / Amount_Requested) * 0.5
   
Explanation:
1. Credit_Score / 850 normalizesn the score value between 0 and 1.
2. Checkings_Balance / Loan_Amount measures a customer's liquidity relative to the loan.
3. Both factors are weighted equally at 50%.
***/

-- Audit table is created to record loan application scores and decision traceability.
CREATE TABLE IF NOT EXISTS Procedure_Audit_Loan_Scores (
	Score_ID INT AUTO_INCREMENT PRIMARY KEY, 
    Application_ID INT,
    LA_Score DECIMAL(10,4),
    Decision VARCHAR(15), 
    Reviewed_At DATETIME DEFAULT CURRENT_TIMESTAMP, 
    FOREIGN KEY (Application_ID) REFERENCES Loan_Applications(Application_ID)
);

-- Here is were the loan application score (LAS) is calculated and records decision based on the criteria.
DELIMITER $$

-- Parameter is declared.
CREATE PROCEDURE Loan_Application_Review_Procedure (IN App_ID INT) 			

BEGIN
	-- Delcare variables to store application data.
	DECLARE CS SMALLINT; 													
	DECLARE TotalAccountBalance DECIMAL(12,2);
    DECLARE AmountRequested DECIMAL(12,2);
	DECLARE CustomerID INT;

	-- These variables are used in the calculation logic.
    DECLARE LAS DECIMAL(10,4); 										
    DECLARE Decision VARCHAR(15);

	-- Retrieve applicant's customer ID, credit score, amount requested, and total balance amount.
    SELECT  c.Credit_Score, c.Cust_ID, SUM(a.Account_Balance), la.Amount_Requested 			
    INTO CS, CustomerID, TotalAccountBalance, AmountRequested
    FROM Loan_Applications la 
    INNER JOIN Customers c 
		ON la.Customer_ID = c.Cust_ID
	INNER JOIN `Account` a 
		ON c.Cust_ID = a.Customer_ID 
	WHERE la.Application_ID = App_ID 													    -- The WHERE clause filters rows so that only the loan application matching the argument (App_ID) is retrieved.
    GROUP BY 
		c.Cust_ID, 
		c.Credit_Score, 
		la.Amount_Requested
    LIMIT 1; 																				-- Limit 1 safe guards that we only get one row.
    
	-- Calculate LAS, avoiding divide-by-zero when AmountRequested = 0.
    IF AmountRequested = 0 THEN                         									   
		SET LAS = 0;  
	ELSE                                    													
		SET LAS = (CS / 850) * 0.5 + (TotalAccountBalance / AmountRequested) * 0.5;
	END IF;
    
    IF LAS >= 0.6 THEN                 													
		SET Decision = 'Accepted';
	ELSE 
		SET Decision = 'Declined';
    END IF; 
    
    INSERT INTO Procedure_Audit_Loan_Scores (Application_ID, LA_Score, Decision)
    VALUES (App_ID, LAS, Decision);
    
END$$

DELIMITER ;    

-- Example 1: retrieve details of application ID 5 before procedure is called.
SELECT 
	c.Cust_ID,
    CONCAT(c.Cust_First_Name, ' ', c.Cust_Last_Name) AS Cust_Name,
    c.Credit_Score, 
    la.Application_ID,
    la.Amount_Requested,
	SUM(a.Account_Balance)
FROM Loan_Applications la 
INNER JOIN Customers c 
	ON la.Customer_ID = c.Cust_ID
INNER JOIN `Account` a
	ON c.Cust_ID = a.Customer_ID
WHERE la.Application_ID = 5
GROUP BY
	c.Cust_ID,
	c.Credit_Score, 
    la.Application_ID,
    la.Amount_Requested;

-- Execute stored procedure for application ID 5.
CALL Loan_Application_Review_Procedure(5);

-- Review the aduit log to observe the decision recorded by the procedure.
SELECT * 
FROM Procedure_Audit_Loan_Scores;


# Stored Procedure 2
/***
This procedure processes a credit card payment using funds from a customer's account. It validates a sufficient account balance and ensures the payment 
does not exceed the outstanding card balance. It updates both balances and records the transaction in its designated audit table if valid. 
***/

-- Audit table is created to record data of payments and the direction of the transactions.
CREATE TABLE IF NOT EXISTS Procedure_Audit_Credit_Card_Payments (
	Transaction_ID INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
    Cust_ID INT, 
	Payment_Amount DECIMAL(6,2),
    Checkings_ID INT,
    Card_ID INT, 
	Date DATETIME DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (Card_ID) REFERENCES Credit_Cards (Card_ID)
);

DELIMITER $$

-- Parameters are declared.
CREATE PROCEDURE Credit_Card_Payment_Procedure ( 
	IN in_Customer_ID INT, 
	IN in_Account_ID INT, 
    IN in_Card_ID INT,
    IN in_Amount DECIMAL (6,2)
)     

BEGIN
	-- Variables are delcared to compare funds. 
	DECLARE AccountBalance DECIMAL (12,2);    
    DECLARE OutstandingBalance DECIMAL (10,2);   
    
    -- Start transaction to ensure database atomicity (all or nothing).
    START TRANSACTION; 
    
    -- Retrieve data from specified customer, account, and credit card.
    SELECT a.Account_Balance, cc.Outstanding_Balance
    INTO AccountBalance, OutstandingBalance
    FROM `Account` a 
    INNER JOIN Customers co 
		ON a.Customer_ID = co.Cust_ID
    INNER JOIN Credit_Cards cc 
		on co.Cust_ID = cc.Customer_ID
    WHERE cc.Card_ID = in_Card_ID 
		AND a.Account_ID = in_Account_ID 
		AND co.Cust_ID = in_Customer_ID;
    
	-- Validation 1: Ensure the customer has sufficient funds in their account.  
	-- Validation 2: Ensure the payment does not exceed the outstanding card balance.  
	-- If both validations pass, the account and card balances are updated and the transaction is recorded.
    IF AccountBalance < in_Amount THEN  
		ROLLBACK;
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient funds in Checkings account.';
        
    ELSEIF OutstandingBalance < in_Amount THEN 
		ROLLBACK;
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT  = 'Payment Amount is more than the Credit Card Outstanding Balance';
        
	ELSE 
		UPDATE `Account` 
		SET Account_Balance = Account_Balance - in_Amount
		WHERE Account_ID = in_Account_ID;
            
		UPDATE Credit_Cards 
		SET Outstanding_Balance = Outstanding_Balance - in_Amount
		WHERE Card_ID = in_Card_ID;
            
		INSERT INTO Procedure_Audit_Credit_Card_Payments (Cust_ID, Payment_Amount, Checkings_ID , Card_ID , Date) VALUES 
		(in_Customer_ID, in_Amount, in_Account_ID , in_Card_ID , NOW());
		
        COMMIT;
        
	END IF;
    
END$$

DELIMITER ;

-- (Customer ID, Account ID, Credit Card ID, Amount to be transfered).
-- Example 1: Attempt overpayment.
CALL Credit_Card_Payment_Procedure(4, 5, 7, 500);

-- Example 2: Check balances for the same previous customer, but now attempting to pay with a different card.
SELECT 
	co.Cust_ID, 
	cc.Card_ID, 
    cc.Outstanding_Balance, 
	a.Account_ID, 
    a.Account_Balance
FROM Credit_Cards cc 
INNER JOIN Customers co 
	ON cc.Customer_ID = co.Cust_ID
INNER JOIN `Account` a 
	ON co.Cust_ID = a.Customer_ID
WHERE co.Cust_ID = 4 
	AND a.Account_ID = 5
	AND cc.Card_ID = 31;

-- Successfully calls and executes stored procedure.
CALL Credit_Card_Payment_Procedure(4, 5, 31, 500);

-- Review audit table transaction.
SELECT * 
FROM Procedure_Audit_Credit_Card_Payments;


# Stored Procedure 3 & 4
/***
These procedures update the branch cash holdings for ATM and in-branch services.
***/

-- This audit table records transactions performed at an ATM or inside a branch, populated by two different stored procedures.
CREATE TABLE IF NOT EXISTS Procedure_Audit_Branch_Transactions (
    Branch_Transactions INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
    Method ENUM('In-Store', 'ATM'),
    Service_Type ENUM('Deposit', 'Withdrawal'), -- NEW
    Branch_ID VARCHAR(10), 
    Payment_Amount DECIMAL(6,2),
    Date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (Branch_ID) REFERENCES Branches(Branch_ID)
);

DELIMITER $$ 

-- This procedure applies an ATM service to the branchs' cash holdings and logs the transaction on the audit table.
-- Parameters are declared.
CREATE PROCEDURE ATM_Transactions (IN in_ATMServiceID INT) 
BEGIN 
    DECLARE ServiceType VARCHAR(12);
    DECLARE MoneyInBranch DECIMAL(12,2);
	DECLARE BranchID VARCHAR(10);
	DECLARE TransferAmount DECIMAL(12,2);
	
    -- Start transaction to ensure database atomicity (all or nothing).
    START TRANSACTION; 
    
    -- Retrieve the service details and current branch holdings for the give ATM service ID.
    SELECT atm.Service_Type, bh.Holdings_Amount, atm.Amount, atm.Branch_ID
    INTO  ServiceType, MoneyInBranch, TransferAmount, BranchID
    FROM Branch_Holdings bh 
    INNER JOIN Branches b 
		ON bh.Branch_ID = b.Branch_ID
    INNER JOIN ATM_Service atm 
		ON b.Branch_ID = atm.Branch_ID
    WHERE atm.ATM_Service_ID = in_ATMServiceID;
    
    -- Validation 1: If the ATM service type is withdraw then we remove the amount from the ATM record from the branch holding.
	-- Validation 2: If the ATM service type is a deposit then we add the amount to the corresponding branch holding.
    IF ServiceType = 'Withdrawal' THEN 
		UPDATE Branch_Holdings
        SET Holdings_Amount = Holdings_Amount - TransferAmount
        WHERE Branch_ID = BranchID;
    
    ELSEIF ServiceType = 'Deposit' THEN 
		UPDATE Branch_Holdings
		SET Holdings_Amount = Holdings_Amount + TransferAmount
		WHERE Branch_ID = BranchID;
        
    END IF;
    
	INSERT INTO Procedure_Audit_Branch_Transactions (Branch_ID, Method, Service_Type, Payment_Amount, Date) 
	VALUES (BranchID, 'ATM', ServiceType, TransferAmount, NOW());

	COMMIT;
	
END$$ 

DELIMITER ; 

-- Example 1: Preview ATM service rows for branch ID B002 and its holdings.
SELECT * 
FROM ATM_Service atm
INNER JOIN Branch_Holdings bh
	ON atm.Branch_ID = bh.Branch_ID
WHERE atm.Branch_ID = 'B002'; 

-- Call stored procedure for ATM service ID 1.
CALL ATM_Transactions(1);

-- Review audit log for recorded branch transactions.
SELECT *
FROM Procedure_Audit_Branch_Transactions;


DELIMITER $$ 

-- Handles branch transactions, just like the ATM procedure.
-- Takes in Branch Transaction ID as an argument, validates the transaction type, the updates the holdings of the branch
-- and records an audit entry.
CREATE PROCEDURE In_Branch_Transactions (IN in_BranchTranscationID INT)
BEGIN 
	DECLARE ServiceType VARCHAR(12);
    DECLARE MoneyInBranch DECIMAL(12,2);
	DECLARE TransferAmount DECIMAL(12,2);
	DECLARE BranchID VARCHAR(10);
        
	-- Start transaction to ensure database atomicity (all or nothing).
    START TRANSACTION; 
    
    SELECT bt.Service_Type, bh.Holdings_Amount, bt.Amount, bt.Branch_ID
    INTO ServiceType, MoneyInBranch, TransferAmount, BranchID
    FROM Branch_Holdings bh
    INNER JOIN Branches b 
		ON bh.Branch_ID = b.Branch_ID
    INNER JOIN In_Branch_Transactions bt 
		ON b.Branch_ID = bt.Branch_ID
    WHERE bt.Branch_Transcation_ID = in_BranchTranscationID;
    
    -- Apply transaction: withdraw reduces holdings, deposit increases holdings.
    IF ServiceType = 'Withdrawal' THEN 
		UPDATE Branch_Holdings
        SET Holdings_Amount = Holdings_Amount - TransferAmount
        WHERE Branch_ID = BranchID;
    
    ELSEIF ServiceType = 'Deposit' THEN 
		UPDATE Branch_Holdings
		SET Holdings_Amount = Holdings_Amount + TransferAmount
		WHERE Branch_ID = BranchID;
        
    END IF;
    
    INSERT INTO Procedure_Audit_Branch_Transactions (Branch_ID, Method, Service_Type, Payment_Amount, Date) -- this inserts the transaction into an audit table.
	VALUES (BranchID, 'In-Store', ServiceType, TransferAmount, NOW());

		COMMIT;
	
    SELECT * FROM Branch_Holdings WHERE Branch_ID = BranchID;

END$$ 

DELIMITER ; 

-- Example 1: Preview In Branch Transaction rows for branch ID B002 and its holdings.
SELECT * 
FROM In_Branch_Transactions ibt
INNER JOIN Branch_Holdings bh
	ON ibt.Branch_ID = bh.Branch_ID
WHERE ibt.Branch_ID = 'B001'; 

-- Call stored procedure for In Branch Transaction ID 1.
CALL In_Branch_Transactions(1);

-- Review audit log for recorded branch transactions.
SELECT *
FROM Procedure_Audit_Branch_Transactions;


# Stored Procedure 5
/***
This procedure freezes Business and Investment accounts that are Active but fall below a specified balance threshold.
***/
SET SQL_SAFE_UPDATES = 0;

DELIMITER $$

CREATE PROCEDURE Freeze_HighRisk__Accounts(IN in_Risk_Limit DECIMAL(12,2))
BEGIN
    -- Update qualifying accounts to 'Account Frozen'.
    UPDATE `Account`
    SET Status = 'Account Frozen'
    WHERE Account_Type IN ('Business', 'Investment')
		AND Account_Balance IS NOT NULL
		AND Account_Balance < in_Risk_Limit 
        AND Status = 'Active'; 
        
    -- Return the number of accounts that were frozen.
    SELECT ROW_COUNT() AS Frozen_Count;
END$$

DELIMITER ;

-- Example 1: Freeze all risky accounts below 1000.
SELECT * 
FROM `Account` 
WHERE Account_Balance < 1000;

CALL Freeze_HighRisk__Accounts(1000);

SELECT * 
FROM `Account` 
WHERE Account_Balance < 1000;

-- Reset accounts to Active once balance recovers.
UPDATE `Account`
SET Status = 'Active'
WHERE Status = 'Account Frozen';
