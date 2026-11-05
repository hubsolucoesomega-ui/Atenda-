ALTER TABLE clients ADD COLUMN link_token TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS clients_link_token ON clients (link_token);
