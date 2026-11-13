CREATE TABLE IF NOT EXISTS report_fields_new (template_id TEXT NOT NULL CHECK (template_id IN ('service','attendance','external','internal')), id TEXT NOT NULL, label TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN ('text','textarea','date','number','select','attachment')), required INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL, options_json TEXT NOT NULL DEFAULT '{}', PRIMARY KEY (template_id, id));
INSERT INTO report_fields_new (template_id, id, label, kind, required, position) SELECT template_id, id, label, kind, required, position FROM report_fields;
DROP TABLE report_fields;
ALTER TABLE report_fields_new RENAME TO report_fields;
CREATE INDEX IF NOT EXISTS report_fields_by_template ON report_fields (template_id, position);
ALTER TABLE tickets ADD COLUMN custom_json TEXT NOT NULL DEFAULT '{}';
CREATE TABLE IF NOT EXISTS ticket_fields (id TEXT PRIMARY KEY, label TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN ('text','textarea','date','number','select','attachment')), required INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL, options_json TEXT NOT NULL DEFAULT '{}');
CREATE TABLE IF NOT EXISTS attachments (id TEXT PRIMARY KEY, filename TEXT NOT NULL, mime TEXT NOT NULL, size INTEGER NOT NULL, uploaded_by TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS attachment_chunks (attachment_id TEXT NOT NULL REFERENCES attachments(id) ON DELETE CASCADE, seq INTEGER NOT NULL, data TEXT NOT NULL, PRIMARY KEY (attachment_id, seq));
