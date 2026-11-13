-- ATENDA — esquema para Cloudflare D1 (SQLite)

-- Perfis de acesso: telas que cada perfil abre e ações que pode fazer. Os três padrão vêm prontos.
CREATE TABLE IF NOT EXISTS profiles (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, perms TEXT NOT NULL DEFAULT '[]', screens TEXT NOT NULL DEFAULT '[]', builtin INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_gestor', 'Gestor', '["receive","report","review","configure"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","colaboradores","avisos","config"]', 1, '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_atendente', 'Atendente', '["receive","report"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","avisos","config"]', 1, '');
INSERT OR IGNORE INTO profiles (id, name, perms, screens, builtin, created_at) VALUES ('p_revisor', 'Revisor', '["receive","review"]', '["dashboard","chamados","novo","agenda","kanban","tarefas","clientes","nfe","relatorios","sla","avisos","config"]', 1, '');

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  role TEXT NOT NULL CHECK (role IN ('gestor','atendente','revisor')),
  active INTEGER NOT NULL DEFAULT 1,
  password_hash TEXT NOT NULL,
  notify_chamados INTEGER NOT NULL DEFAULT 0,
  profile_id TEXT REFERENCES profiles(id)
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  company TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  doc TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  initials TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  link_token TEXT,
  omie_code TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS clients_link_token ON clients (link_token);

-- Unidades/postos do cliente (ex.: "PGF PPV1 - Itapecerica da Serra") e equipamentos cadastrados por cliente.
CREATE TABLE IF NOT EXISTS client_units (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS client_units_by_client ON client_units (client_id);

CREATE TABLE IF NOT EXISTS client_equipment (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  model TEXT NOT NULL DEFAULT '',
  serial_number TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS client_equipment_by_client ON client_equipment (client_id);

CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  equipment_name TEXT NOT NULL DEFAULT '',
  cost REAL NOT NULL DEFAULT 0,
  price REAL NOT NULL DEFAULT 0,
  stock_qty REAL NOT NULL DEFAULT 0,
  min_stock REAL NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  omie_code TEXT
);
CREATE INDEX IF NOT EXISTS products_by_name ON products (name);

CREATE TABLE IF NOT EXISTS catalog_services (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL NOT NULL DEFAULT 0,
  external_code TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  omie_code TEXT
);
CREATE INDEX IF NOT EXISTS catalog_services_by_name ON catalog_services (name);

CREATE TABLE IF NOT EXISTS sectors (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL CHECK (type IN ('Loja','Interno','Externo')),
  active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS services (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sla_policies (
  priority TEXT PRIMARY KEY CHECK (priority IN ('Urgente','Alta','Normal','Baixa')),
  resp_min INTEGER NOT NULL CHECK (resp_min > 0),
  res_hours INTEGER NOT NULL CHECK (res_hours > 0)
);

CREATE TABLE IF NOT EXISTS fiscal_config (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  cnpj TEXT NOT NULL DEFAULT '',
  legal_name TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT '',
  zip TEXT NOT NULL DEFAULT '',
  municipal_registration TEXT NOT NULL DEFAULT '',
  iss_rate REAL NOT NULL DEFAULT 0 CHECK (iss_rate >= 0 AND iss_rate <= 5)
);

CREATE TABLE IF NOT EXISTS tickets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  client_company TEXT NOT NULL,
  category TEXT NOT NULL,
  priority TEXT NOT NULL CHECK (priority IN ('Urgente','Alta','Normal','Baixa')),
  status TEXT NOT NULL CHECK (status IN ('Novo','Em triagem','Em atendimento','Aguardando cliente','Resolvido')),
  agent TEXT NOT NULL DEFAULT 'Não atribuído',
  team TEXT NOT NULL DEFAULT '',
  sector_id TEXT,
  unit_id TEXT REFERENCES client_units(id),
  equipment_id TEXT REFERENCES client_equipment(id),
  sla TEXT NOT NULL DEFAULT 'ok' CHECK (sla IN ('ok','warning','late')),
  due_text TEXT NOT NULL DEFAULT '',
  created_text TEXT NOT NULL DEFAULT '',
  updated_text TEXT NOT NULL DEFAULT '',
  custom_json TEXT NOT NULL DEFAULT '{}',
  archived INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ticket_messages (
  id TEXT PRIMARY KEY,
  ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  author TEXT NOT NULL,
  body TEXT NOT NULL,
  time_text TEXT NOT NULL,
  internal INTEGER NOT NULL DEFAULT 0,
  system INTEGER NOT NULL DEFAULT 0,
  seq INTEGER NOT NULL
);

-- Relatórios de encerramento. ticket_category é um snapshot da categoria no envio.
CREATE TABLE IF NOT EXISTS closing_reports (
  id TEXT PRIMARY KEY,
  ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  ticket_category TEXT NOT NULL,
  author_id TEXT NOT NULL REFERENCES users(id),
  author_name TEXT NOT NULL,
  template_id TEXT NOT NULL,
  template_name TEXT NOT NULL,
  service_id TEXT NOT NULL,
  service_name TEXT NOT NULL,
  service_code TEXT NOT NULL,
  fields_json TEXT NOT NULL,
  values_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','returned')),
  reviewer_id TEXT REFERENCES users(id),
  reviewer_name TEXT,
  reviewed_at TEXT,
  feedback TEXT NOT NULL DEFAULT '',
  submitted_at TEXT NOT NULL
);
-- No máximo um relatório ativo (pendente ou aprovado) por chamado.
CREATE UNIQUE INDEX IF NOT EXISTS one_active_report_per_ticket
  ON closing_reports(ticket_id) WHERE status <> 'returned';

CREATE TABLE IF NOT EXISTS invoices (
  id TEXT PRIMARY KEY,
  number INTEGER NOT NULL UNIQUE,
  report_id TEXT NOT NULL UNIQUE REFERENCES closing_reports(id) ON DELETE CASCADE,
  ticket_id INTEGER NOT NULL,
  client TEXT NOT NULL,
  status TEXT NOT NULL,
  template_name TEXT NOT NULL,
  service_name TEXT NOT NULL,
  service_code TEXT NOT NULL,
  iss_rate REAL NOT NULL,
  base REAL NOT NULL,
  iss REAL NOT NULL,
  net REAL NOT NULL,
  items_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  omie_nfse_number TEXT,
  omie_nfse_status TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS omie_config (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  app_key TEXT NOT NULL DEFAULT '',
  app_secret TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 0,
  last_sync_text TEXT NOT NULL DEFAULT '',
  last_test_text TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  agent TEXT NOT NULL,
  due TEXT NOT NULL,
  priority TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  ticket_id INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0
);

-- Campos dos relatórios, editáveis pelo gestor. id é único dentro do tipo de relatório.
CREATE TABLE IF NOT EXISTS report_fields (
  template_id TEXT NOT NULL CHECK (template_id IN ('service','attendance','external','internal','afericao','atend_presencial','atend_remoto','aval_cameras_fuga','aval_pista_pesagem','calibracao','cameras_fuga','checklist_calibracao','checklist_sist_pesagem','checklist_geral','manut_perifericos','manut_pista','pista_pesagem_precisao','rel_manut_balanca_aprb','rel_visita','sem_foros','sist_pesagem_precisao_geral')),
  id TEXT NOT NULL,
  label TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('text','textarea','date','number','select','attachment')),
  required INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL,
  options_json TEXT NOT NULL DEFAULT '{}',
  PRIMARY KEY (template_id, id)
);
CREATE INDEX IF NOT EXISTS report_fields_by_template ON report_fields (template_id, position);

-- Campos personalizados do chamado (configurados pelo gestor, como no Auvo).
CREATE TABLE IF NOT EXISTS ticket_fields (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('text','textarea','date','number','select','attachment')),
  required INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL,
  options_json TEXT NOT NULL DEFAULT '{}'
);

-- Anexos (imagem ou PDF, até 5 MB), guardados em blocos base64 na tabela attachment_chunks.
CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  filename TEXT NOT NULL,
  mime TEXT NOT NULL,
  size INTEGER NOT NULL,
  uploaded_by TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS attachment_chunks (
  attachment_id TEXT NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
  seq INTEGER NOT NULL,
  data TEXT NOT NULL,
  PRIMARY KEY (attachment_id, seq)
);

-- Agenda: visitas e tarefas de campo geradas a partir de chamados.
CREATE TABLE IF NOT EXISTS agenda_items (
  id TEXT PRIMARY KEY,
  ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  task_type TEXT NOT NULL CHECK (task_type IN ('Manutenção Preventiva','Manutenção Corretiva','Instalação','Visita técnica')),
  scheduled_date TEXT NOT NULL,
  scheduled_time TEXT NOT NULL,
  technician TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'Aberta' CHECK (status IN ('Aberta','Em andamento','Concluída','Cancelada')),
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS agenda_by_date ON agenda_items (scheduled_date, scheduled_time);

-- Colaboradores (RH): cadastro, EPIs, exames periódicos e documentos.
CREATE TABLE IF NOT EXISTS employees (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  role_title TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS employee_epis (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  ca_number TEXT NOT NULL DEFAULT '',
  delivered_on TEXT NOT NULL DEFAULT '',
  expires_on TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS employee_exams (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  done_on TEXT NOT NULL,
  valid_months INTEGER NOT NULL DEFAULT 12,
  expires_on TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS employee_documents (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Pendente',
  expires_on TEXT NOT NULL DEFAULT '',
  attachment_id TEXT REFERENCES attachments(id) ON DELETE SET NULL,
  updated_at TEXT NOT NULL DEFAULT ''
);
-- Avisos no app. dedupe_key evita repetir o mesmo aviso (ex.: mesmo vencimento na mesma faixa).
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  link TEXT NOT NULL DEFAULT '',
  read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  dedupe_key TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS notifications_dedupe ON notifications (dedupe_key);
CREATE INDEX IF NOT EXISTS notifications_by_user ON notifications (user_id, read);

CREATE INDEX IF NOT EXISTS users_by_profile ON users (profile_id);
