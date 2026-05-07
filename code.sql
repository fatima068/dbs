-- LAB 8 

-- ── 1a. BEFORE INSERT: print message ─────────────────────────
CREATE OR REPLACE TRIGGER bi_Superheroes
BEFORE INSERT ON superheroes
FOR EACH ROW
DECLARE
    v_user VARCHAR2(15);
BEGIN
    SELECT user INTO v_user FROM dual;
    DBMS_OUTPUT.PUT_LINE('You Just Inserted a Row Mr.' || v_user);
END;
/

    -- ── 1d. Combined INSERT/UPDATE/DELETE — detect which operation ─
CREATE OR REPLACE TRIGGER tr_superheroes
BEFORE INSERT OR DELETE OR UPDATE ON superheroes
FOR EACH ROW
DECLARE
    v_user VARCHAR2(15);
BEGIN
    SELECT user INTO v_user FROM dual;
    IF INSERTING THEN
        DBMS_OUTPUT.PUT_LINE('Inserted by ' || v_user);
    ELSIF DELETING THEN
        DBMS_OUTPUT.PUT_LINE('Deleted by '  || v_user);
    ELSIF UPDATING THEN
        DBMS_OUTPUT.PUT_LINE('Updated by '  || v_user);
    END IF;
END;
/

-- ── 1e. Table Auditing: log :NEW and :OLD into audit table ────
CREATE OR REPLACE TRIGGER superheroes_audit
BEFORE INSERT OR DELETE OR UPDATE ON superheroes
FOR EACH ROW
DECLARE
    v_user VARCHAR2(30);
    v_date VARCHAR2(30);
BEGIN
    SELECT user, TO_CHAR(SYSDATE, 'DD/MON/YYYY HH24:MI:SS')
    INTO   v_user, v_date FROM dual;
    IF INSERTING THEN
        INSERT INTO sh_audit VALUES (:NEW.sh_name, NULL,          v_user, SYSDATE, 'Insert');
    ELSIF DELETING THEN
        INSERT INTO sh_audit VALUES (NULL,          :OLD.sh_name, v_user, SYSDATE, 'Delete');
    ELSIF UPDATING THEN
        INSERT INTO sh_audit VALUES (:NEW.sh_name,  :OLD.sh_name, v_user, SYSDATE, 'Update');
    END IF;
END;
/

-- ── 1f. Synchronized Backup: keep backup table in sync ────────
CREATE OR REPLACE TRIGGER sh_Backup
BEFORE INSERT OR DELETE OR UPDATE ON superheroes
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO superheroes_backup (sh_name) VALUES (:NEW.sh_name);
    ELSIF DELETING THEN
        DELETE FROM superheroes_backup WHERE sh_name = :OLD.sh_name;
    ELSIF UPDATING THEN
        UPDATE superheroes_backup SET sh_name = :NEW.sh_name
        WHERE sh_name = :OLD.sh_name;
    END IF;
END;
/

--  DML TASK 1: Auto-bonus on employee INSERT (10% of salary)
CREATE TABLE employee_bonus (employee_id INT, bonus INT, bonus_date DATE);

CREATE OR REPLACE TRIGGER trg_auto_bonus
AFTER INSERT ON hr.employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_bonus (employee_id, bonus, bonus_date)
    VALUES (:NEW.employee_id, :NEW.salary * 0.10, SYSDATE);
END;
/
    
--  DML TASK 2: Block salary UPDATE if > 10,000
CREATE OR REPLACE TRIGGER trg_salary_threshold
BEFORE UPDATE ON hr.employees
FOR EACH ROW
BEGIN
    IF :NEW.salary > 10000 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: Salary cannot exceed 10,000. Update rejected.');
    END IF;
END;
/

--  DML TASK 3: Log deleted employees to audit table
CREATE OR REPLACE TRIGGER trg_log_deleted_emp
AFTER DELETE ON hr.employees
FOR EACH ROW
DECLARE
    v_user VARCHAR2(30);
BEGIN
    SELECT user INTO v_user FROM dual;
    INSERT INTO deleted_employees_log
    VALUES (:OLD.employee_id, :OLD.first_name, :OLD.last_name,
            :OLD.salary, :OLD.job_id, v_user, SYSDATE);
END;
/
    
CREATE OR REPLACE TRIGGER hr_audit_tr
AFTER DDL ON SCHEMA
BEGIN
    INSERT INTO schema_audit
    VALUES (SYSDATE,
            SYS_CONTEXT('USERENV', 'CURRENT_USER'),
            ora_dict_obj_type,
            ora_dict_obj_name,
            ora_sysevent);
END;
/

--  DDL TASK 1: Log every CREATE TABLE into audit_log
CREATE OR REPLACE TRIGGER trg_log_table_create
AFTER CREATE ON DATABASE
DECLARE
    v_user VARCHAR2(30);
BEGIN
    IF ora_dict_obj_type = 'TABLE' THEN
        SELECT user INTO v_user FROM dual;
        INSERT INTO audit_log (table_name, created_by, creation_time)
        VALUES (ora_dict_obj_name, v_user, SYSDATE);
    END IF;
END;
/

--  DDL TASK 2: Block ALTER on employees outside business hours (8AM–6PM)
CREATE OR REPLACE TRIGGER trg_block_alter_emp
BEFORE ALTER ON DATABASE
BEGIN
    IF ora_dict_obj_name = 'EMPLOYEES' AND ora_dict_obj_owner = 'HR' THEN
        IF TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) >= 18 OR
           TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) < 8 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Error: ALTER on hr.employees is not allowed outside business hours (8AM-6PM).');
        END IF;
    END IF;
END;
/

ALTER TABLE hr.employees ADD test_col VARCHAR2(10);

--  DDL TASK 3: Log every DROP to drop_log
CREATE TABLE drop_log (
    object_name  VARCHAR2(50),
    object_type  VARCHAR2(30),
    dropped_by   VARCHAR2(30),
    dropped_on   DATE
);

CREATE OR REPLACE TRIGGER trg_log_drop
BEFORE DROP ON DATABASE
DECLARE
    v_user VARCHAR2(30);
BEGIN
    SELECT user INTO v_user FROM dual;
    INSERT INTO drop_log (object_name, object_type, dropped_by, dropped_on)
    VALUES (ora_dict_obj_name, ora_dict_obj_type, v_user, SYSDATE);
END;
/

--  DDL TASK 4: Protect audit_log table from being dropped
CREATE OR REPLACE TRIGGER trg_protect_audit_log
BEFORE DROP ON DATABASE
BEGIN
    IF ora_dict_obj_name = 'AUDIT_LOG' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Warning: The audit_log table is protected and cannot be dropped.');
    END IF;
END;
/

-- ── Startup trigger ───────────────────────────────────────────
CREATE OR REPLACE TRIGGER tr_startup_audit
AFTER STARTUP ON DATABASE
BEGIN
    INSERT INTO startup_audit
    VALUES (ora_sysevent, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'));
END;
/

-- ── Schema-level LOGON / LOGOFF ───────────────────────────────
CREATE OR REPLACE TRIGGER hr_lgon_audit
AFTER LOGON ON SCHEMA
BEGIN
    INSERT INTO hr_evnt_audit
    VALUES (ora_sysevent, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), NULL, NULL);
    COMMIT;
END;
/

--  SYSTEM TASK 2: Log failed login attempts (ORA-01017 = bad password)
CREATE TABLE failed_logins (username VARCHAR2(30), attempt_time DATE);

CREATE OR REPLACE TRIGGER trg_failed_login
AFTER SERVERERROR ON DATABASE
DECLARE
    v_user VARCHAR2(30);
BEGIN
    IF ora_is_servererror(1017) THEN
        SELECT user INTO v_user FROM dual;
        INSERT INTO failed_logins (username, attempt_time) VALUES (v_user, SYSDATE);
        COMMIT;
    END IF;
END;
/

    --  SYSTEM TASK 3: Log session duration on logout
CREATE TABLE user_activity_log (
    username         VARCHAR2(30),
    logon_time       DATE,
    logoff_time      DATE,
    duration_minutes NUMBER
);

-- Logon: record entry
CREATE OR REPLACE TRIGGER trg_capture_logon
AFTER LOGON ON DATABASE
BEGIN
    INSERT INTO user_activity_log (username, logon_time)
    VALUES (USER, SYSDATE);
    COMMIT;
END;
/

-- Logoff: compute and store duration
CREATE OR REPLACE TRIGGER trg_log_logout
BEFORE LOGOFF ON DATABASE
DECLARE
    v_logon_time DATE;
BEGIN
    SELECT logon_time INTO v_logon_time
    FROM   user_activity_log
    WHERE  username = USER AND logoff_time IS NULL AND ROWNUM = 1
    ORDER BY logon_time DESC;

    UPDATE user_activity_log
    SET    logoff_time      = SYSDATE,
           duration_minutes = ROUND((SYSDATE - v_logon_time) * 24 * 60, 2)
    WHERE  username = USER AND logoff_time IS NULL;
    COMMIT;
END;
/

SELECT * FROM user_activity_log;

--  SECTION 4: INSTEAD OF TRIGGERS
--  Fire on DML against VIEWS (not tables).
--  Use when view is non-updatable (has JOINs, aggregates, etc.)
CREATE OR REPLACE TRIGGER tr_Io_Insert
INSTEAD OF INSERT ON db_lab_view
FOR EACH ROW
BEGIN
    INSERT INTO trainer  (full_name)    VALUES (:NEW.full_name);
    INSERT INTO subject  (subject_name) VALUES (:NEW.subject_name);
END;
/

--  INSTEAD OF TASK 1: Insert into Employees + Departments via view
CREATE OR REPLACE TRIGGER trgInsertEmpDept
INSTEAD OF INSERT ON hr.empDeptView
DECLARE
    v_dept_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_dept_count
    FROM   hr.departments
    WHERE  department_id = :NEW.department_id;

    IF v_dept_count = 0 THEN
        INSERT INTO hr.departments (department_id, department_name)
        VALUES (:NEW.department_id, :NEW.department_name);
    END IF;

    INSERT INTO hr.employees
        (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id)
    VALUES
        (:NEW.employee_id, :NEW.first_name, :NEW.last_name,
         UPPER(SUBSTR(:NEW.first_name, 1, 1) || :NEW.last_name),
         SYSDATE, 'IT_PROG', :NEW.salary, :NEW.department_id);
END;
/
-- compound trigger
    CREATE OR REPLACE TRIGGER comp_trg
FOR INSERT OR DELETE OR UPDATE ON superheroes
COMPOUND TRIGGER
 v_count NUMBER := 0;

 BEFORE STATEMENT IS
 BEGIN
   DBMS_OUTPUT.PUT_LINE('Statement started');
 END BEFORE STATEMENT;

 BEFORE EACH ROW IS
 BEGIN
   v_count := v_count + 1;
 END BEFORE EACH ROW;

 AFTER EACH ROW IS
 BEGIN
   DBMS_OUTPUT.PUT_LINE('Row processed');
 END AFTER EACH ROW;

 AFTER STATEMENT IS
 BEGIN
   DBMS_OUTPUT.PUT_LINE('Total rows affected: ' || v_count);
 END AFTER STATEMENT;
END;
/

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
