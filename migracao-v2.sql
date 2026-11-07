-- Migração para quem já tem o banco criado (versão anterior). Rode UMA vez.
-- Adiciona endereço de cliente, agenda e campos editáveis dos relatórios.

ALTER TABLE clients ADD COLUMN address TEXT NOT NULL DEFAULT '';

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

CREATE TABLE IF NOT EXISTS report_fields (
  template_id TEXT NOT NULL CHECK (template_id IN ('service','attendance','external','internal')),
  id TEXT NOT NULL,
  label TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('text','textarea','date','number')),
  required INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL,
  PRIMARY KEY (template_id, id)
);
CREATE INDEX IF NOT EXISTS report_fields_by_template ON report_fields (template_id, position);

INSERT OR IGNORE INTO report_fields (template_id, id, label, kind, required, position) VALUES
  ('service', 'name', 'Nome', 'text', 1, 1),
  ('service', 'problem', 'Problema e solução', 'textarea', 1, 2),
  ('service', 'date', 'Data', 'date', 1, 3),
  ('service', 'value', 'Valor (R$)', 'number', 1, 4),
  ('service', 'notes', 'Observações', 'textarea', 0, 5),
  ('attendance', 'name', 'Nome', 'text', 1, 1),
  ('attendance', 'summary', 'Resumo do atendimento', 'textarea', 1, 2),
  ('attendance', 'date', 'Data', 'date', 1, 3),
  ('attendance', 'value', 'Valor (R$)', 'number', 1, 4),
  ('external', 'company', 'Empresa/fornecedor', 'text', 1, 1),
  ('external', 'description', 'Descrição', 'textarea', 1, 2),
  ('external', 'date', 'Data', 'date', 1, 3),
  ('external', 'value', 'Valor (R$)', 'number', 1, 4),
  ('internal', 'sector', 'Setor responsável', 'text', 1, 1),
  ('internal', 'description', 'Descrição', 'textarea', 1, 2),
  ('internal', 'date', 'Data', 'date', 1, 3),
  ('internal', 'value', 'Valor (R$)', 'number', 1, 4);
