-- LAB 10
SET SERVEROUTPUT ON;

--  TASK 1: Basic PL/SQL Block
DECLARE
    student_name VARCHAR2(50) := 'Syeda Fatima';
    course_name  VARCHAR2(50) := 'Database Systems';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Student ' || student_name ||
                         ' is enrolled in ' || course_name);
END;
/

--  TASK 2: Arithmetic Operations
DECLARE
    a       NUMBER := 50;
    b       NUMBER := 20;
    c       NUMBER := 5;
    sum_val NUMBER;
    sub_val NUMBER;
    div_val NUMBER;
BEGIN
    sum_val := a + b;
    sub_val := a - b;
    div_val := a / c;
    DBMS_OUTPUT.PUT_LINE('Sum: '         || sum_val);
    DBMS_OUTPUT.PUT_LINE('Subtraction: ' || sub_val);
    DBMS_OUTPUT.PUT_LINE('Division: '    || div_val);
END;
/

--  TASK 3: Variable Scope (outer vs inner block)
DECLARE
    x NUMBER := 10;
    y NUMBER := 20;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Outer x: ' || x);
    DBMS_OUTPUT.PUT_LINE('Outer y: ' || y);
    DECLARE
        x NUMBER := 100;
        y NUMBER := 200;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Inner x: ' || x);
        DBMS_OUTPUT.PUT_LINE('Inner y: ' || y);
    END;
    DBMS_OUTPUT.PUT_LINE('Back to outer x: ' || x);
END;
/

--  TASK 4: SELECT INTO with %TYPE
DECLARE
    e_name employees.FIRST_NAME%TYPE;
    e_sal  employees.SALARY%TYPE;
BEGIN
    SELECT FIRST_NAME, SALARY
    INTO   e_name, e_sal
    FROM   employees
    WHERE  EMPLOYEE_ID = 100;
    DBMS_OUTPUT.PUT_LINE('Name: '   || e_name);
    DBMS_OUTPUT.PUT_LINE('Salary: ' || e_sal);
END;
/

-- Multi-column SELECT INTO with JOIN
DECLARE
    e_id    employees.EMPLOYEE_ID%TYPE;
    e_name  employees.FIRST_NAME%TYPE;
    e_lname employees.LAST_NAME%TYPE;
    d_name  departments.DEPARTMENT_NAME%TYPE;
BEGIN
    SELECT e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, d.DEPARTMENT_NAME
    INTO   e_id, e_name, e_lname, d_name
    FROM   employees e
    INNER JOIN departments d ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
    WHERE  e.EMPLOYEE_ID = 100;
    DBMS_OUTPUT.PUT_LINE('ID: '         || e_id);
    DBMS_OUTPUT.PUT_LINE('First Name: ' || e_name);
    DBMS_OUTPUT.PUT_LINE('Last Name: '  || e_lname);
    DBMS_OUTPUT.PUT_LINE('Department: ' || d_name);
END;
/

--  TASK 5: IF-THEN
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
BEGIN
    SELECT SALARY INTO e_sal FROM employees WHERE EMPLOYEE_ID = e_id;
    IF (e_sal > 10000) THEN
        UPDATE employees SET salary = e_sal + 500 WHERE EMPLOYEE_ID = e_id;
        DBMS_OUTPUT.PUT_LINE('Salary updated by 500');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Salary not updated');
    END IF;
END;
/

-- Manual examples from manual (IF-THEN only)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
BEGIN
    SELECT SALARY INTO e_sal FROM employees WHERE EMPLOYEE_ID = e_id;
    IF (e_sal >= 5000) THEN
        UPDATE employees SET salary = e_sal + 1000 WHERE EMPLOYEE_ID = e_id;
        DBMS_OUTPUT.PUT_LINE('Salary updated');
    END IF;
END;
/

--  TASK 6: IF-THEN-ELSIF (tiered salary increment)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
BEGIN
    SELECT SALARY INTO e_sal FROM employees WHERE EMPLOYEE_ID = e_id;
    IF (e_sal <= 10000) THEN
        e_sal := e_sal + 500;
    ELSIF (e_sal <= 20000) THEN
        e_sal := e_sal + 300;
    ELSE
        e_sal := e_sal + 100;
    END IF;
    UPDATE employees SET salary = e_sal WHERE EMPLOYEE_ID = e_id;
    DBMS_OUTPUT.PUT_LINE('Updated Salary: ' || e_sal);
END;
/

-- Manual example (4-tier ELSIF)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
BEGIN
    SELECT SALARY INTO e_sal FROM employees WHERE EMPLOYEE_ID = e_id;
    IF (e_sal <= 15000) THEN
        UPDATE employees SET salary = e_sal + 300 WHERE EMPLOYEE_ID = e_id;
    ELSIF (e_sal <= 20000) THEN
        UPDATE employees SET salary = e_sal + 200 WHERE EMPLOYEE_ID = e_id;
    ELSIF (e_sal <= 25000) THEN
        UPDATE employees SET salary = e_sal + 100 WHERE EMPLOYEE_ID = e_id;
    ELSE
        UPDATE employees SET salary = e_sal + 400 WHERE EMPLOYEE_ID = e_id;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Salary updated: ' || e_sal);
END;
/

--  TASK 7: CASE Statement (department-based bonus)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_did employees.DEPARTMENT_ID%TYPE;
    bonus NUMBER;
BEGIN
    SELECT DEPARTMENT_ID INTO e_did FROM employees WHERE EMPLOYEE_ID = e_id;
    CASE e_did
        WHEN 10 THEN bonus := 1000;
        WHEN 20 THEN bonus := 1500;
        WHEN 30 THEN bonus := 2000;
        WHEN 90 THEN bonus := 3000;
        ELSE         bonus := 500;
    END CASE;
    DBMS_OUTPUT.PUT_LINE('Bonus applied: ' || bonus);
END;
/

-- Searched CASE (condition per WHEN)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
    e_did employees.DEPARTMENT_ID%TYPE;
BEGIN
    SELECT SALARY, DEPARTMENT_ID INTO e_sal, e_did
    FROM employees WHERE EMPLOYEE_ID = e_id;
    CASE
        WHEN e_did = 80 THEN UPDATE employees SET salary = e_sal + 100 WHERE EMPLOYEE_ID = e_id;
        WHEN e_did = 50 THEN UPDATE employees SET salary = e_sal + 200 WHERE EMPLOYEE_ID = e_id;
        WHEN e_did = 40 THEN UPDATE employees SET salary = e_sal + 300 WHERE EMPLOYEE_ID = e_id;
        ELSE DBMS_OUTPUT.PUT_LINE('No such record');
    END CASE;
    DBMS_OUTPUT.PUT_LINE('Salary updated: ' || e_sal);
END;
/

--  TASK 8: Nested IF (department + salary range)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
    e_did employees.DEPARTMENT_ID%TYPE;
BEGIN
    SELECT SALARY, DEPARTMENT_ID INTO e_sal, e_did
    FROM employees WHERE EMPLOYEE_ID = e_id;
    IF (e_did = 90) THEN
        IF (e_sal BETWEEN 20000 AND 25000) THEN
            e_sal := e_sal + 1000;
        ELSIF (e_sal BETWEEN 15000 AND 20000) THEN
            e_sal := e_sal + 500;
        END IF;
    ELSIF (e_did = 60) THEN
        IF (e_sal BETWEEN 5000 AND 10000) THEN
            e_sal := e_sal + 300;
        END IF;
    END IF;
    UPDATE employees SET salary = e_sal WHERE EMPLOYEE_ID = e_id;
    DBMS_OUTPUT.PUT_LINE('Final updated salary: ' || e_sal);
END;
/

-- Manual example (nested IF with commission)
DECLARE
    e_id  employees.EMPLOYEE_ID%TYPE := 100;
    e_sal employees.SALARY%TYPE;
    e_did employees.DEPARTMENT_ID%TYPE;
    e_com employees.COMMISSION_PCT%TYPE;
BEGIN
    SELECT SALARY, DEPARTMENT_ID, COMMISSION_PCT
    INTO   e_sal, e_did, e_com
    FROM   employees WHERE EMPLOYEE_ID = e_id;
    IF (e_did = 90) THEN
        IF (e_sal BETWEEN 20000 AND 25000) THEN
            UPDATE employees SET salary = e_sal * (1 + e_com) WHERE EMPLOYEE_ID = e_id;
        ELSIF (e_sal BETWEEN 15000 AND 20000) THEN
            UPDATE employees SET salary = (e_sal + 20) * (1 + e_com) WHERE EMPLOYEE_ID = e_id;
        END IF;
    END IF;
    IF (e_did = 40) THEN
        IF (e_sal BETWEEN 10000 AND 15000) THEN
            UPDATE employees SET salary = e_sal * (1 + e_com) WHERE EMPLOYEE_ID = e_id;
        ELSIF (e_sal BETWEEN 5000 AND 10000) THEN
            UPDATE employees SET salary = (e_sal + 20) * (1 + e_com) WHERE EMPLOYEE_ID = e_id;
        END IF;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Salary processing completed.');
END;
/

--  TASK 9: FOR LOOP with Query
DECLARE
BEGIN
    FOR c IN (
        SELECT FIRST_NAME, SALARY
        FROM   employees
        WHERE  DEPARTMENT_ID = 50
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Name: ' || c.FIRST_NAME ||
                             ' | Salary: ' || c.SALARY);
    END LOOP;
END;
/

-- Manual example (Department 90)
DECLARE
BEGIN
    FOR c IN (
        SELECT EMPLOYEE_ID, FIRST_NAME, SALARY
        FROM   employees
        WHERE  DEPARTMENT_ID = 90
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Salary for ' || c.FIRST_NAME ||
                             ' is: ' || c.SALARY);
    END LOOP;
END;
/

--  TASK 10: Stored Procedure — IN + OUT Parameters
CREATE OR REPLACE PROCEDURE Get_Emp_Salary (
    p_id  IN  NUMBER,
    p_sal OUT NUMBER
)
IS
BEGIN
    SELECT SALARY INTO p_sal
    FROM   employees
    WHERE  EMPLOYEE_ID = p_id;
END;
/

-- Call procedure with OUT parameter
DECLARE
    v_salary NUMBER;
BEGIN
    Get_Emp_Salary(100, v_salary);
    DBMS_OUTPUT.PUT_LINE('Returned Salary: ' || v_salary);
END;
/

--  BONUS: Procedure with IN parameter only
CREATE OR REPLACE PROCEDURE Show_Employee (
    e_id IN NUMBER
)
IS
    e_name employees.FIRST_NAME%TYPE;
BEGIN
    SELECT FIRST_NAME INTO e_name
    FROM   employees
    WHERE  EMPLOYEE_ID = e_id;
    DBMS_OUTPUT.PUT_LINE('Employee Name: ' || e_name);
END;
/

EXEC Show_Employee(100);

--  BONUS: Procedure with IN OUT parameter
CREATE OR REPLACE PROCEDURE Update_Value (
    num IN OUT NUMBER
)
IS
BEGIN
    num := num + 10;
END;
/

DECLARE
    value NUMBER := 50;
BEGIN
    Update_Value(value);
    DBMS_OUTPUT.PUT_LINE('Updated Value: ' || value);
END;
/


--  BONUS: Procedure with INSERT + DEFAULT parameter
CREATE OR REPLACE PROCEDURE Insert_Data (
    STREET_ADDRESS IN VARCHAR2,
    POSTAL_CODE    IN VARCHAR2 DEFAULT NULL,
    CITY           IN VARCHAR2,
    STATE_PROVINCE IN VARCHAR2,
    COUNTRY_ID     IN CHAR
)
IS
    location_id   NUMBER;
    total_record  NUMBER;
BEGIN
    SELECT COUNT(LOCATION_ID) + 1 INTO location_id FROM LOCATIONS;
    total_record := location_id;
    INSERT INTO LOCATIONS (LOCATION_ID, STREET_ADDRESS, POSTAL_CODE,
                           CITY, STATE_PROVINCE, COUNTRY_ID)
    VALUES (location_id, STREET_ADDRESS, POSTAL_CODE,
            CITY, STATE_PROVINCE, COUNTRY_ID);
    DBMS_OUTPUT.PUT_LINE('New record inserted with ID: ' || location_id);
    DBMS_OUTPUT.PUT_LINE('Total records: ' || total_record);
END;
/

EXEC Insert_Data('DHA', '1234', 'KARACHI', 'SINDH', 'PK');

--LAB 12 
-- ---------- DATABASE OPERATIONS ----------
show dbs
use SchoolDB
db
db.dropDatabase()

-- ---------- COLLECTION OPERATIONS ----------
show collections
db.createCollection("Students")
db.createCollection("Courses")
db.Students.drop()

-- ---------- CREATE: INSERT DOCUMENTS ----------
db.Students.insertOne({ _id: 1, name: "Alice", age: 20, scores: { math: 85, science: 90 } })

db.Students.insertMany([
   { _id: 1, name: "Alice",   age: 20, scores: { math: 85, science: 90 } },
   { _id: 2, name: "Bob",     age: 22, scores: { math: 78, science: 82 } },
   { _id: 3, name: "Charlie", age: 21, scores: { math: 92, science: 88 } },
   { _id: 4, name: "Daisy",   age: 23, scores: { math: 68, science: 74 } }
])

db.Courses.insertMany([
   { _id: 101, courseName: "Mathematics", instructor: "Dr. Smith", studentsEnrolled: [1, 2, 3] },
   { _id: 102, courseName: "Science",     instructor: "Dr. Adams", studentsEnrolled: [2, 3, 4] }
])

-- ---------- READ: FIND DOCUMENTS ----------
db.Students.find()
db.Students.find({ name: "Alice" })
db.Students.findOne({ name: "Alice" })

-- ---------- COMPARISON OPERATORS ----------
db.Students.find({ age: { $gt: 20 } })
db.Students.find({ age: { $gte: 20 } })
db.Students.find({ age: { $lt: 22 } })
db.Students.find({ age: { $lte: 22 } })
db.Students.find({ age: { $ne: 20 } })
db.Students.find({ "scores.math": { $gte: 80 } })

-- ---------- LOGICAL OPERATORS: AND / OR ----------
db.Students.find({
   $and: [
      { "scores.math": { $gte: 80 } },
      { "scores.science": { $lt: 90 } }
   ]
})

db.Students.find({ "scores.math": { $gte: 80 }, "scores.science": { $lt: 90 } })

db.Students.find({
   $or: [
      { age: { $lt: 23 } },
      { "scores.math": { $gte: 85 } }
   ]
})

db.Students.find({
   $and: [
      { "scores.science": { $gte: 80 } },
      { $or: [
            { "scores.math": { $lt: 75 } },
            { age: { $gt: 22 } }
        ]
      }
   ]
})

-- ---------- ARRAY QUERIES ----------
db.Courses.find({ studentsEnrolled: 3 })
db.Courses.findOne({ studentsEnrolled: 3, instructor: "Dr. Adams" })

-- ---------- UPDATE DOCUMENTS ----------
db.Students.updateOne(
   { name: "Bob" },
   { $set: { age: 25 } }
)

db.Students.updateMany(
   {},
   { $set: { status: "active" } }
)

db.Students.updateOne(
   { name: "Bob", "scores.math": { $gte: 75 } },
   { $inc: { "scores.science": 5 } }
)

db.Students.updateMany(
   { "scores.science": { $lt: 80 }, age: { $gt: 22 } },
   { $inc: { "scores.math": 5 } }
)

-- ---------- DELETE DOCUMENTS ----------
db.Students.deleteOne({ name: "Daisy", "scores.science": { $lt: 80 } })

db.Courses.deleteMany({
   $or: [
      { studentsEnrolled: 2 },
      { instructor: "Dr. Smith" }
   ]
})

-- ---------- COUNT DOCUMENTS ----------
db.books.countDocuments()
db.books.countDocuments({ publication_year: { $gt: 2000 } })

-- ---------- SORT, LIMIT, SKIP ----------
db.books.find().sort({ publication_year: 1 })
db.books.find().sort({ publication_year: -1, title: 1 })
db.books.find().limit(5)
db.books.find().skip(3)
db.books.find().skip(5).limit(5)

-- ---------- PROJECTION ----------
db.books.find({}, { title: 1, author: 1, _id: 0 })
db.books.find({}, { ISBN: 0 })

-- ---------- AGGREGATION PIPELINE ----------
db.books.aggregate([
   { $group: { _id: null, avgPublicationYear: { $avg: "$publication_year" } } }
])

db.books.aggregate([
   { $group: { _id: "$genre", count: { $sum: 1 } } }
])

db.books.aggregate([
   { $group: { _id: "$genre", count: { $sum: 1 } } },
   { $sort: { count: -1 } }
])

-- ---------- TEXT SEARCH ----------
db.books.createIndex({ title: "text", author: "text" })
db.books.find({ $text: { $search: "Road" } })

-- ---------- REGULAR EXPRESSIONS ----------
db.books.find({ title: { $regex: "^The", $options: "i" } })
db.books.find({ author: { $regex: "Lee$", $options: "i" } })

-- ---------- INCREMENT / DECREMENT ----------
db.books.updateMany({}, { $inc: { rating: 1 } })
db.books.updateOne({ title: "1984" }, { $inc: { publication_year: -5 } })

-- ---------- findOneAndUpdate / findOneAndDelete ----------
db.books.findOneAndUpdate(
   { title: "The Great Gatsby" },
   { $set: { genre: "Classic" } },
   { returnNewDocument: true }
)

db.books.findOneAndDelete({ title: "The Catcher in the Rye" })

-- ---------- DROP COLLECTION & DATABASE ----------
db.Students.drop()
db.Courses.drop()
db.dropDatabase()

-- ---------- 1. COMMIT ----------
UPDATE employees
SET salary = salary + 1000
WHERE emp_id = 101;

COMMIT;

-- ---------- 2. ROLLBACK ----------
DELETE FROM employees
WHERE emp_id = 105;

ROLLBACK;

-- ---------- 3. SAVEPOINT ----------
INSERT INTO employees VALUES (201, 'Ali', 30000);
SAVEPOINT sp1;

UPDATE employees
SET salary = 35000
WHERE emp_id = 201;

ROLLBACK TO sp1;
COMMIT;

-- ---------- 4. SET TRANSACTION ----------
SET TRANSACTION READ ONLY;

SELECT * FROM employees;

COMMIT;

-- ---------- 5. AUTOCOMMIT ----------
SET AUTOCOMMIT ON;

INSERT INTO employees VALUES (202, 'Sara', 40000);

SET AUTOCOMMIT OFF;
