-- Dados de demonstração. Senha de todas as contas: Trocar123!
-- Troque as senhas antes de publicar (veja o README).

INSERT OR IGNORE INTO users (id, name, email, role, active, password_hash) VALUES
  ('ana',    'Ana Martins',   'ana@atenda.com.br',    'gestor',    1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb'),
  ('lucas',  'Lucas Silva',   'lucas@atenda.com.br',  'atendente', 1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb'),
  ('mariana','Mariana Costa', 'mariana@atenda.com.br', 'atendente', 1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb'),
  ('pedro',  'Pedro Santos',  'pedro@atenda.com.br',  'atendente', 1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb'),
  ('julia',  'Julia Oliveira','julia@atenda.com.br',  'atendente', 1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb'),
  ('paula',  'Paula Souza',   'paula@atenda.com.br',  'revisor',   1, 'pbkdf2_sha256$100000$b462157124656a5f414de308db9c8775$e0cf75b7b2b10b920d6d5a116fc2e52b2bd4cfde59021bb6b510cb8cabc84dfb');

INSERT OR IGNORE INTO clients (id, name, company, email, phone, doc, address, initials, active) VALUES
  ('alpha',  'Carolina Almeida', 'Empresa Alpha',  'carolina@alpha.com.br',  '(11) 99984-2030', '12.345.678/0001-90', 'Av. Paulista, 1200 — São Paulo, SP', 'EA', 1),
  ('beta',   'Rafael Mendes',    'Empresa Beta',   'rafael@beta.com.br',     '(21) 99871-4520', '23.456.789/0001-01', 'Rua do Ouvidor, 90 — Rio de Janeiro, RJ', 'EB', 1),
  ('gamma',  'Fernanda Lima',    'Empresa Gamma',  'fernanda@gamma.com.br',  '(31) 98712-3400', '34.567.890/0001-12', 'Av. Afonso Pena, 800 — Belo Horizonte, MG', 'EG', 1),
  ('delta',  'Bruno Rocha',      'Delta Soluções', 'bruno@delta.com.br',     '(41) 99912-7860', '45.678.901/0001-23', 'Rua XV de Novembro, 500 — Curitiba, PR', 'DS', 1),
  ('nexus',  'Juliana Souza',    'Nexus Digital',  'juliana@nexus.com.br',   '(11) 99821-5600', '56.789.012/0001-34', 'Rua Augusta, 200 — São Paulo, SP', 'ND', 0);

INSERT OR IGNORE INTO sectors (id, name, type, active) VALUES
  ('store',    'Loja',                 'Loja',    1),
  ('internal', 'Departamento interno', 'Interno', 1),
  ('external', 'Departamento externo', 'Externo', 1);

INSERT OR IGNORE INTO services (id, name, code, active) VALUES
  ('s1', 'Suporte técnico em informática',          '1.07', 1),
  ('s2', 'Análise e desenvolvimento de sistemas',   '1.01', 1),
  ('s3', 'Assessoria e consultoria em informática', '1.06', 1);

INSERT OR IGNORE INTO sla_policies (priority, resp_min, res_hours) VALUES
  ('Urgente', 15, 4), ('Alta', 30, 8), ('Normal', 60, 24), ('Baixa', 120, 72);

INSERT OR IGNORE INTO fiscal_config (id, cnpj, legal_name, address, city, state, zip, municipal_registration, iss_rate) VALUES
  (1, '00.000.000/0001-00', 'ATENDA Demonstração Ltda', 'Av. Exemplo, 100', 'São Paulo', 'SP', '01000-000', '123456', 2);

INSERT OR IGNORE INTO tickets (id, title, client_company, category, priority, status, agent, team, sector_id, sla, due_text, created_text, updated_text) VALUES
  (1024, 'Problema no acesso ao sistema',        'Empresa Alpha',  'Acesso',       'Urgente', 'Em atendimento',     'Ana Martins',   'Suporte',        NULL, 'late',    'Vencido há 2h',     '08/10/2026, 09:20', 'Há 15 minutos'),
  (1025, 'Dúvida sobre integração da API',       'Empresa Beta',   'Integração',   'Alta',    'Em triagem',         'Lucas Silva',   'Tecnologia',     NULL, 'warning', 'Vence em 45min',    '08/10/2026, 09:20', 'Há 15 minutos'),
  (1026, 'Atualização de dados cadastrais',      'Empresa Gamma',  'Cadastro',     'Normal',  'Aguardando cliente', 'Mariana Costa', 'Administrativo', NULL, 'ok',      'Vence em 6h',       '08/10/2026, 09:20', 'Há 15 minutos'),
  (1027, 'Segunda via de boleto',                'Empresa Alpha',  'Financeiro',   'Baixa',   'Resolvido',          'Pedro Santos',  'Financeiro',     NULL, 'ok',      'SLA cumprido',      '08/10/2026, 09:20', 'Há 15 minutos'),
  (1028, 'Erro ao exportar relatório mensal',    'Delta Soluções', 'Erro técnico', 'Alta',    'Novo',               'Julia Oliveira','Suporte',        NULL, 'warning', 'Vence em 1h',       '08/10/2026, 09:20', 'Há 15 minutos'),
  (1029, 'Solicitação de proposta comercial',    'Empresa Beta',   'Comercial',    'Normal',  'Novo',               'Lucas Silva',   'Comercial',      NULL, 'ok',      'Vence em 8h',       '08/10/2026, 09:20', 'Há 15 minutos'),
  (1030, 'Falha na sincronização de dados',      'Empresa Gamma',  'Integração',   'Urgente', 'Em atendimento',     'Ana Martins',   'Tecnologia',     NULL, 'late',    'Vencido há 30min',  '08/10/2026, 09:20', 'Há 15 minutos'),
  (1031, 'Configuração de novos usuários',       'Delta Soluções', 'Acesso',       'Normal',  'Em atendimento',     'Mariana Costa', 'Suporte',        NULL, 'ok',      'Vence em 4h',       '08/10/2026, 09:20', 'Há 15 minutos');

-- Mensagens iniciais: a solicitação do cliente e a resposta do atendente.
INSERT OR IGNORE INTO ticket_messages (id, ticket_id, author, body, time_text, internal, system, seq)
  SELECT 'c-' || id, id, client_company, 'Olá, preciso de ajuda com: ' || lower(title) || '. Poderiam verificar, por favor?', '09:20', 0, 0, 1 FROM tickets;
INSERT OR IGNORE INTO ticket_messages (id, ticket_id, author, body, time_text, internal, system, seq)
  SELECT 'a-' || id, id, agent, 'Olá! Recebemos sua solicitação e já estamos verificando. Retornaremos com uma atualização em breve.', '09:35', 0, 0, 2 FROM tickets;

INSERT OR IGNORE INTO tasks (id, title, agent, due, priority, done, ticket_id) VALUES
  ('t1', 'Investigar erro de autenticação', 'Ana Martins',   '2026-10-08', 'Urgente', 0, 1024),
  ('t2', 'Revisar documentação da API',     'Lucas Silva',   '2026-10-09', 'Alta',    0, 1025),
  ('t3', 'Validar dados do cliente',        'Mariana Costa', '2026-10-10', 'Normal',  0, 1026),
  ('t4', 'Enviar boleto atualizado',        'Pedro Santos',  '2026-10-08', 'Baixa',   1, 1027);

-- Agenda de demonstração (datas relativas à semana de 26/10/2026).
INSERT OR IGNORE INTO agenda_items (id, ticket_id, task_type, scheduled_date, scheduled_time, technician, address, status, created_by, created_at) VALUES
  ('ag-1', 1024, 'Manutenção Corretiva', '2026-10-27', '09:00', 'Lucas Silva', 'Av. Paulista, 1200 — São Paulo, SP', 'Aberta', 'Ana Martins', '2026-10-21 08:00'),
  ('ag-2', 1030, 'Visita técnica', '2026-10-27', '14:30', 'Mariana Costa', 'Av. Afonso Pena, 800 — Belo Horizonte, MG', 'Em andamento', 'Ana Martins', '2026-10-21 08:05');

-- Campos padrão dos relatórios (o gestor pode incluir ou excluir campos pela tela de Configurações).
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

UPDATE users SET notify_chamados = 1 WHERE role = 'gestor';
UPDATE users SET profile_id = 'p_' || role WHERE profile_id IS NULL;
