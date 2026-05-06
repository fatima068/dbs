-- =====================================================================
-- Project Issue Tracking System - Complete Database Schema
-- CS 2005 Database Systems Project
-- MySQL / MariaDB
-- =====================================================================

DROP DATABASE IF EXISTS project_issue_tracking;
CREATE DATABASE project_issue_tracking CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE project_issue_tracking;

-- =====================================================================
-- CORE TABLES
-- =====================================================================

-- Roles (strong entity)
CREATE TABLE roles (
    role_id      INT AUTO_INCREMENT PRIMARY KEY,
    role_name    VARCHAR(50)  NOT NULL UNIQUE,
    description  VARCHAR(255)
) ENGINE=InnoDB;

-- Users (strong entity)
-- `created_by` is a self-reference: the admin who created the account
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,           -- bcrypt via password_hash()
    role_id        INT          NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by     INT,
    CONSTRAINT fk_users_role      FOREIGN KEY (role_id)    REFERENCES roles(role_id),
    CONSTRAINT fk_users_createdby FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Status (lookup)
CREATE TABLE status (
    status_id   INT AUTO_INCREMENT PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Priority (lookup)
CREATE TABLE priority (
    priority_id   INT AUTO_INCREMENT PRIMARY KEY,
    priority_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Projects (strong entity)
CREATE TABLE projects (
    project_id   INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(150) NOT NULL,
    description  TEXT,
    start_date   DATE,
    end_date     DATE,
    status_id    INT,
    CONSTRAINT fk_projects_status FOREIGN KEY (status_id) REFERENCES status(status_id),
    CONSTRAINT chk_project_dates  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
) ENGINE=InnoDB;

-- ProjectMembers (associative entity: M:N between users and projects)
CREATE TABLE projectmembers (
    project_id INT NOT NULL,
    user_id    INT NOT NULL,
    role_id    INT NOT NULL,
    PRIMARY KEY (project_id, user_id),
    CONSTRAINT fk_pm_project FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    CONSTRAINT fk_pm_user    FOREIGN KEY (user_id)    REFERENCES users(user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_pm_role    FOREIGN KEY (role_id)    REFERENCES roles(role_id)
) ENGINE=InnoDB;

-- Tasks (strong entity)
CREATE TABLE tasks (
    task_id     INT AUTO_INCREMENT PRIMARY KEY,
    project_id  INT          NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    assigned_to INT,
    assigned_by INT,
    status_id   INT,
    priority_id INT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_date    DATE,
    CONSTRAINT fk_tasks_project     FOREIGN KEY (project_id)  REFERENCES projects(project_id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_assignedto  FOREIGN KEY (assigned_to) REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_tasks_assignedby  FOREIGN KEY (assigned_by) REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_tasks_status      FOREIGN KEY (status_id)   REFERENCES status(status_id),
    CONSTRAINT fk_tasks_priority    FOREIGN KEY (priority_id) REFERENCES priority(priority_id)
) ENGINE=InnoDB;

-- Issues (strong entity)
CREATE TABLE issues (
    issue_id    INT AUTO_INCREMENT PRIMARY KEY,
    project_id  INT          NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    assigned_to INT,
    assigned_by INT,
    status_id   INT,
    priority_id INT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_issues_project    FOREIGN KEY (project_id)  REFERENCES projects(project_id) ON DELETE CASCADE,
    CONSTRAINT fk_issues_assignedto FOREIGN KEY (assigned_to) REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_issues_assignedby FOREIGN KEY (assigned_by) REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_issues_status     FOREIGN KEY (status_id)   REFERENCES status(status_id),
    CONSTRAINT fk_issues_priority   FOREIGN KEY (priority_id) REFERENCES priority(priority_id)
) ENGINE=InnoDB;

-- Comments (weak entity - existence depends on task OR issue)
-- XOR constraint: exactly one of task_id / issue_id must be non-NULL
CREATE TABLE comments (
    comment_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    task_id      INT,
    issue_id     INT,
    comment_text TEXT NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_user  FOREIGN KEY (user_id)  REFERENCES users(user_id)  ON DELETE CASCADE,
    CONSTRAINT fk_comments_task  FOREIGN KEY (task_id)  REFERENCES tasks(task_id)  ON DELETE CASCADE,
    CONSTRAINT fk_comments_issue FOREIGN KEY (issue_id) REFERENCES issues(issue_id) ON DELETE CASCADE,
    CONSTRAINT chk_comments_target CHECK (
        (task_id IS NOT NULL AND issue_id IS NULL) OR
        (task_id IS NULL     AND issue_id IS NOT NULL)
    )
) ENGINE=InnoDB;

-- StatusHistory (weak entity - existence depends on task OR issue)
CREATE TABLE statushistory (
    history_id  INT AUTO_INCREMENT PRIMARY KEY,
    task_id     INT,
    issue_id    INT,
    status_id   INT NOT NULL,
    changed_by  INT NOT NULL,
    changed_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sh_task     FOREIGN KEY (task_id)    REFERENCES tasks(task_id)   ON DELETE CASCADE,
    CONSTRAINT fk_sh_issue    FOREIGN KEY (issue_id)   REFERENCES issues(issue_id) ON DELETE CASCADE,
    CONSTRAINT fk_sh_status   FOREIGN KEY (status_id)  REFERENCES status(status_id),
    CONSTRAINT fk_sh_user     FOREIGN KEY (changed_by) REFERENCES users(user_id),
    CONSTRAINT chk_sh_target  CHECK (
        (task_id IS NOT NULL AND issue_id IS NULL) OR
        (task_id IS NULL     AND issue_id IS NOT NULL)
    )
) ENGINE=InnoDB;

-- ActivityLog (weak entity on user; task/issue optional context)
CREATE TABLE activitylog (
    activity_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NOT NULL,
    task_id     INT,
    issue_id    INT,
    action      VARCHAR(255) NOT NULL,
    timestamp   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_user  FOREIGN KEY (user_id)  REFERENCES users(user_id)   ON DELETE CASCADE,
    CONSTRAINT fk_log_task  FOREIGN KEY (task_id)  REFERENCES tasks(task_id)   ON DELETE SET NULL,
    CONSTRAINT fk_log_issue FOREIGN KEY (issue_id) REFERENCES issues(issue_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- ACCESS CONTROL (NEW)
-- =====================================================================

-- Pages: catalog of every protected page in the system.
-- Seeded at install time; admin UI does NOT allow adding/removing pages.
CREATE TABLE pages (
    page_id     INT AUTO_INCREMENT PRIMARY KEY,
    page_name   VARCHAR(100) NOT NULL UNIQUE,
    page_path   VARCHAR(255) NOT NULL,
    description VARCHAR(255)
) ENGINE=InnoDB;

-- Privileges: M:N mapping between roles and pages.
-- Admin UI allows toggling can_access only.
CREATE TABLE privileges (
    privilege_id INT AUTO_INCREMENT PRIMARY KEY,
    role_id      INT NOT NULL,
    page_id      INT NOT NULL,
    can_access   TINYINT(1) NOT NULL DEFAULT 0,
    UNIQUE KEY uq_role_page (role_id, page_id),
    CONSTRAINT fk_priv_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_priv_page FOREIGN KEY (page_id) REFERENCES pages(page_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- VIEWS  (required by project rubric: each shows JOINs / aggregates)
-- =====================================================================

-- 1. Project summary: joins projects + status + correlated counts for tasks/issues
CREATE OR REPLACE VIEW v_project_summary AS
SELECT
    p.project_id,
    p.project_name,
    p.start_date,
    p.end_date,
    s.status_name,
    (SELECT COUNT(*) FROM tasks  t WHERE t.project_id = p.project_id)                      AS total_tasks,
    (SELECT COUNT(*) FROM tasks  t WHERE t.project_id = p.project_id AND t.status_id = 3)  AS completed_tasks,
    (SELECT COUNT(*) FROM tasks  t WHERE t.project_id = p.project_id
                                       AND t.status_id <> 3 AND t.due_date < CURDATE())   AS overdue_tasks,
    (SELECT COUNT(*) FROM issues i WHERE i.project_id = p.project_id)                      AS total_issues,
    (SELECT COUNT(*) FROM issues i WHERE i.project_id = p.project_id AND i.status_id = 3)  AS resolved_issues
FROM projects p
LEFT JOIN status s ON p.status_id = s.status_id;

-- 2. Task details: 4-way join for assignments, status, priority, project
CREATE OR REPLACE VIEW v_task_details AS
SELECT
    t.task_id, t.title, t.description, t.due_date, t.created_at,
    t.project_id, t.assigned_to, t.status_id, t.priority_id,
    p.project_name,
    s.status_name,
    pr.priority_name,
    CONCAT(ua.first_name, ' ', ua.last_name) AS assigned_to_name,
    CONCAT(ub.first_name, ' ', ub.last_name) AS assigned_by_name
FROM tasks t
LEFT JOIN projects p ON t.project_id  = p.project_id
LEFT JOIN status   s ON t.status_id   = s.status_id
LEFT JOIN priority pr ON t.priority_id = pr.priority_id
LEFT JOIN users    ua ON t.assigned_to = ua.user_id
LEFT JOIN users    ub ON t.assigned_by = ub.user_id;

-- 3. Issue details: same pattern as tasks
CREATE OR REPLACE VIEW v_issue_details AS
SELECT
    i.issue_id, i.title, i.description, i.created_at,
    i.project_id, i.assigned_to, i.status_id, i.priority_id,
    p.project_name,
    s.status_name,
    pr.priority_name,
    CONCAT(ua.first_name, ' ', ua.last_name) AS assigned_to_name,
    CONCAT(ub.first_name, ' ', ub.last_name) AS assigned_by_name
FROM issues i
LEFT JOIN projects p  ON i.project_id  = p.project_id
LEFT JOIN status   s  ON i.status_id   = s.status_id
LEFT JOIN priority pr ON i.priority_id = pr.priority_id
LEFT JOIN users    ua ON i.assigned_to = ua.user_id
LEFT JOIN users    ub ON i.assigned_by = ub.user_id;

-- 4. User activity summary: aggregate COUNT of log actions per user
CREATE OR REPLACE VIEW v_user_activity_summary AS
SELECT
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    u.email,
    r.role_name,
    COUNT(a.activity_id) AS total_actions,
    MAX(a.timestamp)     AS last_active
FROM users u
LEFT JOIN roles       r ON u.role_id = r.role_id
LEFT JOIN activitylog a ON a.user_id = u.user_id
GROUP BY u.user_id, u.first_name, u.last_name, u.email, r.role_name;

-- 5. Overdue tasks: filter + DATEDIFF built-in
CREATE OR REPLACE VIEW v_overdue_tasks AS
SELECT
    t.task_id, t.title, t.due_date,
    p.project_name,
    CONCAT(u.first_name, ' ', u.last_name) AS assigned_to_name,
    s.status_name,
    DATEDIFF(CURDATE(), t.due_date) AS days_overdue
FROM tasks t
JOIN projects p ON t.project_id = p.project_id
LEFT JOIN users  u ON t.assigned_to = u.user_id
LEFT JOIN status s ON t.status_id   = s.status_id
WHERE t.due_date < CURDATE() AND t.status_id <> 3;

-- 6. Role privileges: CROSS JOIN every role with every page; LEFT JOIN actual privileges
CREATE OR REPLACE VIEW v_role_privileges AS
SELECT
    r.role_id, r.role_name,
    pg.page_id, pg.page_name, pg.page_path, pg.description,
    COALESCE(pv.can_access, 0) AS can_access
FROM roles r
CROSS JOIN pages pg
LEFT JOIN privileges pv
       ON pv.role_id = r.role_id AND pv.page_id = pg.page_id;

-- 7. Comments with author and target (polymorphic: task OR issue)
CREATE OR REPLACE VIEW v_comments_full AS
SELECT
    c.comment_id, c.comment_text, c.created_at,
    c.task_id, c.issue_id,
    CONCAT(u.first_name, ' ', u.last_name) AS author_name,
    u.user_id  AS author_id,
    COALESCE(t.title, i.title) AS target_title,
    CASE WHEN c.task_id IS NOT NULL THEN 'Task'
         WHEN c.issue_id IS NOT NULL THEN 'Issue'
         ELSE 'Unknown' END AS target_type
FROM comments c
JOIN users u ON c.user_id = u.user_id
LEFT JOIN tasks  t ON c.task_id  = t.task_id
LEFT JOIN issues i ON c.issue_id = i.issue_id;

-- =====================================================================
-- STORED PROCEDURES  (required: transaction handling)
-- =====================================================================

DELIMITER $$

-- Atomically update a task's status, log it in statushistory, and write an activity log entry.
-- Fixes the bug in the original app where these three writes were not wrapped in a transaction.
DROP PROCEDURE IF EXISTS sp_update_task_status$$
CREATE PROCEDURE sp_update_task_status(
    IN p_task_id   INT,
    IN p_status_id INT,
    IN p_user_id   INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        UPDATE tasks SET status_id = p_status_id WHERE task_id = p_task_id;
        INSERT INTO statushistory (task_id, status_id, changed_by) VALUES (p_task_id, p_status_id, p_user_id);
        INSERT INTO activitylog   (user_id, task_id, action)       VALUES (p_user_id, p_task_id, 'Updated task status');
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_update_issue_status$$
CREATE PROCEDURE sp_update_issue_status(
    IN p_issue_id  INT,
    IN p_status_id INT,
    IN p_user_id   INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        UPDATE issues SET status_id = p_status_id WHERE issue_id = p_issue_id;
        INSERT INTO statushistory (issue_id, status_id, changed_by) VALUES (p_issue_id, p_status_id, p_user_id);
        INSERT INTO activitylog   (user_id, issue_id, action)       VALUES (p_user_id, p_issue_id, 'Updated issue status');
    COMMIT;
END$$

-- Atomically add a comment and log the activity
DROP PROCEDURE IF EXISTS sp_add_task_comment$$
CREATE PROCEDURE sp_add_task_comment(
    IN p_user_id INT,
    IN p_task_id INT,
    IN p_text    TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        INSERT INTO comments    (user_id, task_id, comment_text) VALUES (p_user_id, p_task_id, p_text);
        INSERT INTO activitylog (user_id, task_id, action)       VALUES (p_user_id, p_task_id, 'Added comment on task');
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_add_issue_comment$$
CREATE PROCEDURE sp_add_issue_comment(
    IN p_user_id  INT,
    IN p_issue_id INT,
    IN p_text     TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        INSERT INTO comments    (user_id, issue_id, comment_text) VALUES (p_user_id, p_issue_id, p_text);
        INSERT INTO activitylog (user_id, issue_id, action)       VALUES (p_user_id, p_issue_id, 'Added comment on issue');
    COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- INDEXES  (speed up the most common queries seen in the PHP code)
-- =====================================================================
CREATE INDEX idx_tasks_assigned_to   ON tasks(assigned_to);
CREATE INDEX idx_tasks_project       ON tasks(project_id);
CREATE INDEX idx_tasks_status        ON tasks(status_id);
CREATE INDEX idx_issues_assigned_to  ON issues(assigned_to);
CREATE INDEX idx_issues_project      ON issues(project_id);
CREATE INDEX idx_issues_status       ON issues(status_id);
CREATE INDEX idx_activity_user       ON activitylog(user_id);
CREATE INDEX idx_activity_ts         ON activitylog(timestamp);
CREATE INDEX idx_sh_task             ON statushistory(task_id);
CREATE INDEX idx_sh_issue            ON statushistory(issue_id);
CREATE INDEX idx_pm_user             ON projectmembers(user_id);

-- =====================================================================
-- SEED DATA
-- =====================================================================

INSERT INTO roles (role_id, role_name, description) VALUES
(1, 'Admin',       'System administrator with full privileges'),
(2, 'Manager',     'Project manager'),
(3, 'Developer',   'Developer assigned to tasks and issues'),
(4, 'Stakeholder', 'Stakeholder with read-only dashboards');

INSERT INTO status (status_id, status_name) VALUES
(1, 'Pending'),
(2, 'In Progress'),
(3, 'Completed'),
(4, 'Overdue');

INSERT INTO priority (priority_id, priority_name) VALUES
(1, 'Low'),
(2, 'Medium'),
(3, 'High'),
(4, 'Critical');

-- Default admin account.
-- password_hash below is bcrypt of 'Admin@123' (verified working).
-- PHP's password_verify() accepts $2a$/$2b$/$2y$ interchangeably (all bcrypt variants).
-- IMPORTANT: after first login, reset this password via the Reset Password UI.
INSERT INTO users (user_id, first_name, last_name, email, password_hash, role_id, created_by) VALUES
(1, 'System', 'Admin', 'admin@example.com',
 '$2b$12$BzQZr/YY7IKrJ4xH1zNcSut/8TOtv47MHFoSpBFZ/Sf.51kRDki.u',
 1, NULL);

-- Pages catalog (must match the actual PHP page filenames)
INSERT INTO pages (page_name, page_path, description) VALUES
-- Admin
('admin_home',               'admin/home.php',                'Admin dashboard'),
('manage_users',             'admin/manage_users.php',        'Manage system users'),
('manage_roles',             'admin/manage_roles.php',        'Manage user roles'),
('manage_projects_admin',    'admin/manage_projects.php',     'Admin project management'),
('manage_comments',          'admin/manage_comments.php',     'Moderate comments'),
('monitoring_reports',       'admin/monitoring_reports.php',  'System-wide monitoring reports'),
('view_activity_logs_admin', 'admin/view_activity_logs.php',  'View all activity logs'),
('manage_privileges',        'admin/manage_privileges.php',   'Manage role privileges'),
-- Manager
('manager_home',             'manager/home.php',              'Manager dashboard'),
('manage_projects_mgr',      'manager/manage_projects.php',   'Manage projects'),
('manage_tasks',             'manager/manage_tasks.php',      'Create and assign tasks'),
('manage_issues',            'manager/manage_issues.php',     'Create and assign issues'),
('project_reports_mgr',      'manager/project_reports.php',   'Project reports'),
('view_activity_logs_mgr',   'manager/view_activity_logs.php','View activity logs'),
-- Developer
('developer_home',           'developer/home.php',            'Developer dashboard'),
('my_tasks',                 'developer/my_tasks.php',        'View my tasks'),
('my_issues',                'developer/my_issues.php',       'View my issues'),
('my_projects',              'developer/my_projects.php',     'View my projects'),
('activity_logs_dev',        'developer/activity_logs.php',   'My activity logs'),
-- Stakeholder
('stakeholder_home',         'stakeholder/home.php',          'Stakeholder dashboard'),
('project_overview',         'stakeholder/project_overview.php','Project overview'),
('project_progress',         'stakeholder/project_progress.php','Project progress'),
('project_reports_stk',      'stakeholder/project_reports.php', 'Project reports');

-- Default privilege matrix.
-- Admin gets everything; other roles get only the pages belonging to their area.
INSERT INTO privileges (role_id, page_id, can_access)
SELECT 1, page_id, 1 FROM pages;

INSERT INTO privileges (role_id, page_id, can_access)
SELECT 2, page_id,
       CASE WHEN page_name IN (
           'manager_home','manage_projects_mgr','manage_tasks','manage_issues',
           'project_reports_mgr','view_activity_logs_mgr'
       ) THEN 1 ELSE 0 END
FROM pages;

INSERT INTO privileges (role_id, page_id, can_access)
SELECT 3, page_id,
       CASE WHEN page_name IN (
           'developer_home','my_tasks','my_issues','my_projects','activity_logs_dev'
       ) THEN 1 ELSE 0 END
FROM pages;

INSERT INTO privileges (role_id, page_id, can_access)
SELECT 4, page_id,
       CASE WHEN page_name IN (
           'stakeholder_home','project_overview','project_progress','project_reports_stk'
       ) THEN 1 ELSE 0 END
FROM pages;
