ALTER TABLE users ADD COLUMN notify_chamados INTEGER NOT NULL DEFAULT 0;
UPDATE users SET notify_chamados = 1 WHERE role = 'gestor';
CREATE TABLE IF NOT EXISTS employees (id TEXT PRIMARY KEY, name TEXT NOT NULL, role_title TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL DEFAULT '', user_id TEXT REFERENCES users(id) ON DELETE SET NULL, active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS employee_epis (id TEXT PRIMARY KEY, employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE, name TEXT NOT NULL, ca_number TEXT NOT NULL DEFAULT '', delivered_on TEXT NOT NULL DEFAULT '', expires_on TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS employee_exams (id TEXT PRIMARY KEY, employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE, kind TEXT NOT NULL, name TEXT NOT NULL, done_on TEXT NOT NULL, valid_months INTEGER NOT NULL DEFAULT 12, expires_on TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS employee_documents (id TEXT PRIMARY KEY, employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE, kind TEXT NOT NULL, name TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Pendente', expires_on TEXT NOT NULL DEFAULT '', attachment_id TEXT REFERENCES attachments(id) ON DELETE SET NULL, updated_at TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS notifications (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', link TEXT NOT NULL DEFAULT '', read INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, dedupe_key TEXT);
CREATE UNIQUE INDEX IF NOT EXISTS notifications_dedupe ON notifications (dedupe_key);
CREATE INDEX IF NOT EXISTS notifications_by_user ON notifications (user_id, read);
