CREATE TABLE IF NOT EXISTS profiles (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, perms TEXT NOT NULL DEFAULT '[]', screens TEXT NOT NULL DEFAULT '[]', builtin INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_gestor', 'Gestor', '["receive","report","review","configure"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","colaboradores","avisos","config"]', 1, '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_atendente', 'Atendente', '["receive","report"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","avisos","config"]', 1, '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_revisor', 'Revisor', '["receive","review"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","avisos","config"]', 1, '');
ALTER TABLE users ADD COLUMN profile_id TEXT REFERENCES profiles(id);
UPDATE users SET profile_id = 'p_' || role WHERE profile_id IS NULL;
CREATE INDEX IF NOT EXISTS users_by_profile ON users (profile_id);
