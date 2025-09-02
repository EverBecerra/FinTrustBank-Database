# Stored Trigger 1
/***
This trigger logs each new customer into Trigger_Audit_New_Customer after an insert on Customers, capturing their ID, 
name, email, phone, and timestamp.
***/

CREATE TABLE IF NOT EXISTS Trigger_Audit_New_Customer(
	New_Customer_ID INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
    Customer_ID INT, 
    Customer_FN VARCHAR(100),
    Customer_LN VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
	Created_At DATETIME DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (Customer_ID) REFERENCES Customers(Cust_ID)
);

DELIMITER $$

CREATE TRIGGER New_Customer_Trigger
AFTER INSERT ON Customers
FOR EACH ROW 
BEGIN
    -- Use NEW.* to reference values from the freshly inserted row
	INSERT INTO Trigger_Audit_New_Customer (New_Customer_ID, Customer_ID, Customer_FN, Customer_LN, Email, Phone, Created_At)
    VALUES (NEW.Cust_ID, NEW.Cust_ID, NEW.Cust_First_Name, NEW.Cust_Last_Name, NEW.Cust_Email, NEW.Cust_Phone, NOW());
END$$

DELIMITER ;

-- Example 1: Inserting a new customer automatically creates an audit record in the audit table.
INSERT INTO Customers (Cust_First_Name, Cust_Last_Name, Cust_Email, Cust_Phone, Cust_Birth_Date, Cust_ssn, Credit_Score, Cust_Address, Cust_Status, Branch_ID) VALUES 
('Ever', 'Becerra', 'becerrae123@outlook.com', '469-247-4027', '2002-11-29',
AES_ENCRYPT('154-44-6899', 'encryption_key'), 750, '2112 Euclid Ave, Melissa, TX 75002', 'Active', 'B005');

SELECT * 
FROM Trigger_Audit_New_Customer;


# Stored Trigger 2
/***
This trigger logs each failed login into the audit table after an insert on online banking login 
accurs and the Login status is set as "Failed".
***/

CREATE TABLE IF NOT EXISTS Trigger_Audit_Login_Failed (
    Audit_ID INT AUTO_INCREMENT PRIMARY KEY,
    Table_Name VARCHAR(50),
    Action_Type VARCHAR(50),
    Action_Description TEXT,
    Login_ID INT,
    Action_Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (Login_ID) REFERENCES Online_Banking_Logins(Login_ID)
);
select * from Online_Banking_Logins;
DELIMITER $$

CREATE TRIGGER Log_Failed_Login
AFTER INSERT ON Online_Banking_Logins
FOR EACH ROW
BEGIN
	-- Insert the failed attempt details into the audit table.
    IF NEW.Login_Status = 'Failed' THEN
        INSERT INTO Trigger_Audit_Login_Failed (Table_Name, Action_Type, Action_Description, Login_ID, Action_Timestamp)
        VALUES ('Online_Banking_Logins', 'LOGIN_FAIL', 
				CONCAT('Failed login from IP ', NEW.IP_Address, ' for Customer ID: ', NEW.Customer_ID), 
				Login_ID, NOW()
        );
    END IF;
END$$

DELIMITER ;

-- Example 1: A successful login is inserted but not recorded in the audit table.
INSERT INTO Online_Banking_Logins (Customer_ID, Login_Timestamp, Login_Status, IP_Address)
VALUES (7, NOW(), 'Success', '200.34.15.66');

-- Example 2: A failed login is inserted and automatically recorded in the audit table.
INSERT INTO Online_Banking_Logins (Customer_ID, Login_Timestamp, Login_Status, IP_Address)
VALUES (4, NOW(), 'Failed', '101.22.33.44');

SELECT * 
FROM Trigger_Audit_Login_Failed;


# Stored Trigger 3 
/***
This trigger blocks a card when a card's new updated outstanding balance exceeds credit limit 
and writes an audit row with old/new status. 
***/
CREATE TABLE Trigger_Audit_Blocked_Cards (
    Audit_ID INT PRIMARY KEY AUTO_INCREMENT,
    Card_ID INT,
    Customer_ID INT,
    Blocked_On TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Reason VARCHAR(255),
    Old_Status ENUM('Active', 'Inactive', 'Blocked'),
    New_Status ENUM('Active', 'Inactive', 'Blocked'),
	FOREIGN KEY (Card_ID) REFERENCES Credit_Cards (Card_ID)
);

DELIMITER $$

CREATE TRIGGER Block_Credit_Card
BEFORE UPDATE ON Credit_Cards
FOR EACH ROW
BEGIN
    -- Block if balance exceeds limit and card wasn’t already blocked.
    IF NEW.Outstanding_Balance > NEW.Credit_Limit AND OLD.Status != 'Blocked' THEN
        SET NEW.Status = 'Blocked';
        
        -- Log the change (use NEW.Status)
        INSERT INTO Trigger_Audit_Blocked_Cards (Card_ID, Customer_ID, Blocked_On, Reason, Old_Status, New_Status) 
        VALUES (NEW.Card_ID, NEW.Customer_ID, NOW(), 
				CONCAT('Outstanding Balance (', NEW.Outstanding_Balance, ') exceeded Credit Limit (', NEW.Credit_Limit, ')'),
				NEW.Status, 'Blocked'
        );
    END IF;
END$$

DELIMITER ;

-- Example 1: 
-- Insert a new credit card with balance under limit (card remains Active).
INSERT INTO credit_cards (Card_ID, Customer_ID, Card_Type, Card_Number, Expiry_Date, CVV, Credit_Limit, Outstanding_Balance, Status) 
VALUES (101, 1, 'Visa', '1234567812345678', '2026-12-31', 123, 10000.00, 5000.00, 'Active');

-- Update balance above limit (trigger blocks the card and logs the change).
UPDATE credit_cards
SET Outstanding_Balance = 20000
WHERE Card_ID = 101;

-- Verify audit log
SELECT * 
FROM Trigger_Audit_Blocked_Cards;   


# Stored Trigger 4
/***
This trigger blocks new Checking/Savings accounts with deposits under 5000 and logs the attempt.
***/

-- Audit table is MyISAM so the log persists even if the account insert is rolled back.
CREATE TABLE IF NOT EXISTS Trigger_Audit_MinimumBalance_Alert (
	Min_Audit_ID INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
    Customer_ID INT NOT NULL,
    Amount_Recorded INT NOT NULL,
    Action_Description TEXT,
	FOREIGN KEY (Customer_ID) REFERENCES Customers(Cust_ID)
) ENGINE = MyISAM;

DELIMITER $$

CREATE TRIGGER MinimumBalance_Alert
BEFORE INSERT ON `Account`
FOR EACH ROW
BEGIN
    -- Check only Checking/Savings accounts below 5000.
    IF NEW.Account_Type IN ('Checking', 'Savings')
		AND NEW.Account_Balance < 5000 THEN 

        -- Log the failed attempt in the audit table.
        INSERT INTO Trigger_Audit_MinimumBalance_Alert (Customer_ID, Amount_Recorded, Action_Description)
		VALUES (NEW.Customer_ID, NEW.Account_Balance, 'Initial deposit must be at least $200 per account.');
		
        -- Block the insert into Account.
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Initial deposit must be at least $200 per account.';
		
    END IF;
    
END$$ 

DELIMITER ;

-- Example 1: Attempting to open a Checking account with insufficient funds.
INSERT INTO `Account` (Customer_ID, Account_Type, Account_Balance, Status)
VALUES (4, 'Checking', 1, 'Active');

SELECT * 
FROM Trigger_Audit_MinimumBalance_Alert;


# Stored Trigger 5
/***
This trigger blocks deleting customers who still have active loans or fixed deposits to maintain data integrity.
***/
DELIMITER $$

CREATE TRIGGER Prevent_Customer_Deletion
BEFORE DELETE ON Customers
FOR EACH ROW
BEGIN
    DECLARE Active_Loans INT DEFAULT 0;
    DECLARE Active_FD INT DEFAULT 0;

    -- Count active loans linked to the customer
    SELECT COUNT(*) 
    INTO Active_Loans
    FROM Loan_Applications
    WHERE Customer_ID = OLD.Cust_ID;
    
    -- Count active fixed deposits (still maturing and active)
    SELECT COUNT(*) 
    INTO Active_FD
    FROM Fixed_Deposits
    WHERE Customer_ID = OLD.Cust_ID
      AND Maturity_Date > CURRENT_DATE
      AND Status = 'Active';

    -- Block deletion if either loans or fixed deposits exist
    IF Active_Loans > 0 OR Active_FD > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Can not delete customer with active loans or fixed deposits.';
    END IF;
END$$

DELIMITER ;

-- Example 1: Find customers who cannot be deleted due to active loans or deposits
SELECT 
    c.Cust_ID,
    l.Application_ID,
    f.FixedDeposits_ID,
	f.Status,
    f.Maturity_Date
FROM Customers c
INNER JOIN Loan_Applications l
	ON c.Cust_ID = l.Customer_ID
INNER JOIN Fixed_Deposits f
	ON c.Cust_ID = f.Customer_ID
WHERE f.Maturity_Date > CURRENT_DATE
      AND f.Status = 'Active';

-- Attempting to delete such a customer raises an error and blocks the deletion
DELETE 
FROM Customers 
WHERE Cust_ID = 4;