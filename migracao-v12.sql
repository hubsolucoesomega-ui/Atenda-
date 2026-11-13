CREATE TABLE IF NOT EXISTS omie_config (id INTEGER PRIMARY KEY CHECK (id = 1), app_key TEXT NOT NULL DEFAULT '', app_secret TEXT NOT NULL DEFAULT '', enabled INTEGER NOT NULL DEFAULT 0, last_sync_text TEXT NOT NULL DEFAULT '', last_test_text TEXT NOT NULL DEFAULT '');
INSERT OR IGNORE INTO omie_config (id, app_key, app_secret, enabled, last_sync_text, last_test_text) VALUES (1, '', '', 0, '', '');
ALTER TABLE clients ADD COLUMN omie_code TEXT;
ALTER TABLE products ADD COLUMN omie_code TEXT;
ALTER TABLE catalog_services ADD COLUMN omie_code TEXT;
ALTER TABLE invoices ADD COLUMN omie_nfse_number TEXT;
ALTER TABLE invoices ADD COLUMN omie_nfse_status TEXT NOT NULL DEFAULT '';
