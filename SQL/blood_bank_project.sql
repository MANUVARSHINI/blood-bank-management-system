-- Create tables
CREATE TABLE Donor (
    Donor_ID NUMBER PRIMARY KEY,
    Name VARCHAR2(50),
    Gender VARCHAR2(10),
    Age NUMBER,
    Blood_Group VARCHAR2(5),
    Phone VARCHAR2(15),
    Address VARCHAR2(100),
    Last_Donation_Date DATE
);

CREATE TABLE BloodDonation (
    Donation_ID NUMBER PRIMARY KEY,
    Donation_Date DATE,
    Quantity NUMBER,
    Donor_ID NUMBER REFERENCES Donor(Donor_ID)
);

CREATE TABLE BloodUnit (
    BloodUnit_ID NUMBER PRIMARY KEY,
    Blood_Group VARCHAR2(5),
    Quantity NUMBER,
    Collection_Date DATE,
    Expiry_Date DATE,
    Donation_ID NUMBER REFERENCES BloodDonation(Donation_ID)
);

CREATE TABLE Hospital (
    Hospital_ID NUMBER PRIMARY KEY,
    Hospital_Name VARCHAR2(50),
    Address VARCHAR2(100),
    Contact_Number VARCHAR2(15)
);

CREATE TABLE Patient (
    Patient_ID NUMBER PRIMARY KEY,
    Name VARCHAR2(50),
    Gender VARCHAR2(10),
    Age NUMBER,
    Blood_Group VARCHAR2(5),
    Phone VARCHAR2(15),
    Address VARCHAR2(100)
);

CREATE TABLE BloodRequest (
    Request_ID NUMBER PRIMARY KEY,
    Patient_ID NUMBER REFERENCES Patient(Patient_ID),
    Address VARCHAR2(100),
    Blood_Group VARCHAR2(5),
    Quantity NUMBER,
    Status VARCHAR2(20),
    Hospital_ID NUMBER REFERENCES Hospital(Hospital_ID)
);

CREATE TABLE BloodIssue (
    Issue_ID NUMBER PRIMARY KEY,
    Issue_Date DATE,
    Quantity NUMBER,
    Request_ID NUMBER UNIQUE REFERENCES BloodRequest(Request_ID),
    BloodUnit_ID NUMBER REFERENCES BloodUnit(BloodUnit_ID)
);


-- Insert sample data
INSERT INTO Donor VALUES (1, 'Arun Kumar', 'Male', 28, 'O+', '9876543210', 'Chennai', DATE '2026-06-01');
INSERT INTO Donor VALUES (2, 'Priya S', 'Female', 24, 'A+', '9876500000', 'Chennai', DATE '2026-05-15');
INSERT INTO Donor VALUES (3, 'Ravi Shankar', 'Male', 31, 'B+', '9988776655', 'Coimbatore', DATE '2026-07-10');

INSERT INTO BloodDonation VALUES (101, DATE '2026-08-01', 350, 1);
INSERT INTO BloodDonation VALUES (102, DATE '2026-08-02', 350, 2);
INSERT INTO BloodDonation VALUES (103, DATE '2026-08-03', 350, 3);

INSERT INTO BloodUnit VALUES (201, 'O+', 350, DATE '2026-08-01', DATE '2026-09-12', 101);
INSERT INTO BloodUnit VALUES (202, 'A+', 350, DATE '2026-08-02', DATE '2026-09-13', 102);
INSERT INTO BloodUnit VALUES (203, 'B+', 350, DATE '2026-08-03', DATE '2026-09-14', 103);

INSERT INTO Hospital VALUES (301, 'City General Hospital', 'Anna Nagar, Chennai', '04423456789');
INSERT INTO Hospital VALUES (302, 'Apollo Hospital', 'Greams Road, Chennai', '04428290200');

INSERT INTO Patient VALUES (401, 'Karthik R', 'Male', 35, 'O+', '9123456789', 'Velachery, Chennai');
INSERT INTO Patient VALUES (402, 'Deepa N', 'Female', 29, 'A+', '9012345678', 'Adyar, Chennai');

INSERT INTO BloodRequest VALUES (501, 401, 'Velachery, Chennai', 'O+', 2, 'Pending', 301);
INSERT INTO BloodRequest VALUES (502, 402, 'Adyar, Chennai', 'A+', 1, 'Pending', 302);

COMMIT;


-- Select queries
SELECT Name, Last_Donation_Date FROM Donor
WHERE Last_Donation_Date >= SYSDATE - 90;

SELECT Blood_Group, COUNT(*) AS Units_Available FROM BloodUnit bu
WHERE NOT EXISTS (SELECT 1 FROM BloodIssue bi WHERE bi.BloodUnit_ID = bu.BloodUnit_ID)
GROUP BY Blood_Group;

SELECT br.Request_ID, p.Name AS Patient, h.Hospital_Name, br.Blood_Group, br.Status
FROM BloodRequest br
JOIN Patient p ON br.Patient_ID = p.Patient_ID
JOIN Hospital h ON br.Hospital_ID = h.Hospital_ID;


-- Trigger
CREATE OR REPLACE TRIGGER trg_check_expiry
BEFORE INSERT ON BloodIssue
FOR EACH ROW
DECLARE
    v_expiry DATE;
BEGIN
    SELECT Expiry_Date INTO v_expiry FROM BloodUnit WHERE BloodUnit_ID = :NEW.BloodUnit_ID;
    IF v_expiry < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cannot issue expired blood unit.');
    END IF;
END;
/

-- Procedure
CREATE OR REPLACE PROCEDURE fulfill_request(p_request_id NUMBER) AS
    v_bg VARCHAR2(5);
    v_unit_id NUMBER;
    v_qty NUMBER;
BEGIN
    SELECT Blood_Group, Quantity INTO v_bg, v_qty FROM BloodRequest WHERE Request_ID = p_request_id;

    SELECT BloodUnit_ID INTO v_unit_id FROM BloodUnit bu
    WHERE Blood_Group = v_bg AND Expiry_Date > SYSDATE
    AND NOT EXISTS (SELECT 1 FROM BloodIssue bi WHERE bi.BloodUnit_ID = bu.BloodUnit_ID)
    AND ROWNUM = 1;

    INSERT INTO BloodIssue VALUES (
        (SELECT NVL(MAX(Issue_ID),0)+1 FROM BloodIssue), SYSDATE, v_qty, p_request_id, v_unit_id
    );

    UPDATE BloodRequest SET Status = 'Fulfilled' WHERE Request_ID = p_request_id;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' fulfilled with unit ' || v_unit_id);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No matching blood unit found for this request.');
END;
/

-- Function
CREATE OR REPLACE FUNCTION days_to_expiry(p_unit_id NUMBER) RETURN NUMBER AS
    v_expiry DATE;
BEGIN
    SELECT Expiry_Date INTO v_expiry FROM BloodUnit WHERE BloodUnit_ID = p_unit_id;
    RETURN v_expiry - SYSDATE;
END;
/


-- Test PL/SQL objects
SET SERVEROUTPUT ON;

EXEC fulfill_request(501);
EXEC fulfill_request(502);

SELECT * FROM BloodIssue;
SELECT * FROM BloodRequest;

SELECT days_to_expiry(201) AS Days_Left FROM DUAL;
