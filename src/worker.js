// ATENDA — API em Cloudflare Workers + D1.
// Todas as regras de negócio e de permissão são aplicadas aqui, no servidor.

/* ==================== Constantes ==================== */
const CATEGORIES = ['Acesso', 'Integração', 'Cadastro', 'Financeiro', 'Erro técnico', 'Comercial'];
const STATUSES = ['Novo', 'Em triagem', 'Em atendimento', 'Aguardando cliente', 'Resolvido'];
const PRIORITIES = ['Urgente', 'Alta', 'Normal', 'Baixa'];
const SECTOR_TYPES = ['Loja', 'Interno', 'Externo'];
const PERMS = {
  gestor: ['configure', 'receive', 'report', 'review'],
  atendente: ['receive', 'report'],
  revisor: ['receive', 'review']
};
const ROLE_LABEL = {gestor: 'Gestor', atendente: 'Atendente', revisor: 'Revisor'};
const AGENDA_TYPES = ['Manutenção Preventiva', 'Manutenção Corretiva', 'Instalação', 'Visita técnica'];
const AGENDA_STATUS = ['Aberta', 'Em andamento', 'Concluída', 'Cancelada'];
// Nomes dos tipos de relatório. Os campos ficam na tabela report_fields (editáveis pelo gestor).
const TEMPLATE_NAMES = {
  service: 'Relatório de serviço',
  attendance: 'Relatório de atendimento',
  external: 'Relatório externo',
  internal: 'Relatório interno'
};
const FIELD_KINDS = {text: 'Texto', textarea: 'Texto longo', date: 'Data', number: 'Número'};
const MAX_FIELDS = 20;
const toField = r => ({id: r.id, label: r.label, kind: r.kind, required: !!r.required});
function buildTemplates(rows) {
  const out = {};
  for (const id of Object.keys(TEMPLATE_NAMES)) out[id] = {name: TEMPLATE_NAMES[id], fields: []};
  for (const r of rows) if (out[r.template_id]) out[r.template_id].fields.push(toField(r));
  return out;
}
async function loadTemplate(env, id) {
  const rows = (await env.DB.prepare('SELECT * FROM report_fields WHERE template_id = ? ORDER BY position').bind(id).all()).results;
  return {name: TEMPLATE_NAMES[id], fields: rows.map(toField)};
}
async function addReportField(env, b) {
  const template = String(b.template || '');
  if (!TEMPLATE_NAMES[template]) fail(400, 'Selecione o tipo de relatório.');
  const label = reqStr(b.label, 'Nome do campo', 2, 80);
  const kind = String(b.kind || '');
  if (!FIELD_KINDS[kind]) fail(400, 'Selecione o tipo do campo.');
  const info = await env.DB.prepare('SELECT COUNT(*) AS n, COALESCE(MAX(position), 0) AS last FROM report_fields WHERE template_id = ?').bind(template).first();
  if (info.n >= MAX_FIELDS) fail(409, `Limite de ${MAX_FIELDS} campos por relatório.`);
  await env.DB.prepare('INSERT INTO report_fields (template_id, id, label, kind, required, position) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(template, uid(), label, kind, b.required ? 1 : 0, info.last + 1).run();
}
async function deleteReportField(env, templateId, fieldId) {
  if (!TEMPLATE_NAMES[templateId]) fail(404, 'Campo não encontrado.');
  // O valor do serviço alimenta a base da NF-e demonstrativa: não pode ser removido.
  if (fieldId === 'value') fail(409, 'O campo "Valor (R$)" é usado no cálculo da NF-e e não pode ser removido.');
  const row = await env.DB.prepare('SELECT id FROM report_fields WHERE template_id = ? AND id = ?').bind(templateId, fieldId).first();
  if (!row) fail(404, 'Campo não encontrado.');
  await env.DB.prepare('DELETE FROM report_fields WHERE template_id = ? AND id = ?').bind(templateId, fieldId).run();
}

const SESSION_MS = 7 * 24 * 3600 * 1000;
const COOKIE = 'atenda_session';
const enc = new TextEncoder();

/* ==================== Utilitários ==================== */
class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }
const fail = (status, message) => { throw new HttpError(status, message); };
const json = (data, status = 200, extra = {}) => new Response(JSON.stringify(data), {
  status, headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...extra}
});
const ok = (status = 200) => json({ok: true}, status);
const uid = () => crypto.randomUUID();
const r2 = n => Math.round(n * 100) / 100;
const digits = s => String(s || '').replace(/\D/g, '');
const nowText = () => new Date().toLocaleString('pt-BR', {timeZone: 'America/Sao_Paulo', dateStyle: 'short', timeStyle: 'short'});
const hex = buf => [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
const unhex = s => Uint8Array.from(s.match(/../g).map(x => parseInt(x, 16)));
const b64url = bytes => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const isDate = v => /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v;

async function sha256hex(s) { return hex(await crypto.subtle.digest('SHA-256', enc.encode(s))); }
async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  return hex(await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt, iterations}, key, 256));
}
async function verifyPassword(password, stored) {
  const [alg, iter, saltHex, expected] = String(stored).split('$');
  if (alg !== 'pbkdf2_sha256' || !iter || !saltHex || !expected) return false;
  const actual = await pbkdf2(password, unhex(saltHex), Number(iter));
  if (actual.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i++) diff |= actual.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}
function getCookie(req, name) {
  for (const part of (req.headers.get('cookie') || '').split(';')) {
    const [k, ...v] = part.trim().split('=');
    if (k === name) return v.join('=');
  }
  return null;
}
async function body(req) {
  if (!(req.headers.get('content-type') || '').includes('application/json')) fail(415, 'Requisição inválida.');
  try { return await req.json(); } catch { fail(400, 'JSON inválido.'); }
}
function reqStr(v, label, min, max) {
  const s = String(v ?? '').trim();
  if (s.length < min) fail(400, `${label}: informe pelo menos ${min} caracteres.`);
  if (s.length > max) fail(400, `${label}: limite de ${max} caracteres.`);
  return s;
}
function optStr(v, max, label = 'Texto') {
  const s = String(v ?? '').trim();
  if (s.length > max) fail(400, `${label}: limite de ${max} caracteres.`);
  return s;
}
function validateFields(fields, values) {
  const out = {};
  for (const f of fields) {
    const v = String(values[f.id] ?? '').trim();
    if (f.required && !v) fail(400, `${f.label} é obrigatório.`);
    if (v.length > (f.kind === 'textarea' ? 4000 : 255)) fail(400, `${f.label}: limite de caracteres excedido.`);
    if (f.kind === 'date' && v && !isDate(v)) fail(400, `${f.label}: data inválida.`);
    if (f.kind === 'number' && v && !/^\d+(\.\d+)?$/.test(v)) fail(400, `${f.label}: número inválido.`);
    out[f.id] = v;
  }
  return out;
}

/* ==================== Sessão e permissões ==================== */
async function login(req, env) {
  const b = await body(req);
  const email = String(b.email || '').trim().toLowerCase();
  const password = String(b.password || '');
  const user = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first();
  if (!user || !user.active || !(await verifyPassword(password, user.password_hash))) fail(401, 'Email ou senha inválidos.');
  const token = b64url(crypto.getRandomValues(new Uint8Array(32)));
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(Date.now()),
    env.DB.prepare('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)').bind(await sha256hex(token), user.id, Date.now() + SESSION_MS)
  ]);
  return json({ok: true, name: user.name}, 200, {
    'set-cookie': `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${SESSION_MS / 1000}`
  });
}
async function logout(req, env) {
  const tok = getCookie(req, COOKIE);
  if (tok) await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(await sha256hex(tok)).run();
  return json({ok: true}, 200, {'set-cookie': `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`});
}
async function currentUser(req, env) {
  const tok = getCookie(req, COOKIE);
  if (!tok) fail(401, 'Entre para continuar.');
  const row = await env.DB.prepare(
    'SELECT u.id, u.name, u.role, u.active, s.expires_at FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?'
  ).bind(await sha256hex(tok)).first();
  if (!row || !row.active || row.expires_at < Date.now()) fail(401, 'Sessão expirada. Entre novamente.');
  return {id: row.id, name: row.name, role: row.role, perms: PERMS[row.role]};
}
const need = (user, perm) => { if (!user.perms.includes(perm)) fail(403, 'Este perfil não tem permissão para esta ação.'); };

/* ==================== Estado para o frontend ==================== */
async function loadState(env, user) {
  const db = env.DB;
  const res = await db.batch([
    db.prepare('SELECT id, name, email, role, active FROM users ORDER BY name'),
    db.prepare('SELECT * FROM tickets ORDER BY id DESC'),
    db.prepare('SELECT * FROM ticket_messages ORDER BY ticket_id, seq'),
    db.prepare('SELECT * FROM clients ORDER BY company'),
    db.prepare('SELECT * FROM tasks ORDER BY rowid DESC'),
    db.prepare('SELECT * FROM sectors ORDER BY name'),
    db.prepare('SELECT * FROM services ORDER BY code'),
    db.prepare('SELECT * FROM sla_policies'),
    db.prepare('SELECT * FROM fiscal_config WHERE id = 1'),
    db.prepare('SELECT * FROM closing_reports ORDER BY submitted_at DESC'),
    db.prepare('SELECT * FROM invoices ORDER BY number DESC'),
    db.prepare(`SELECT a.*, t.title AS ticket_title, t.client_company, t.priority AS ticket_priority
                FROM agenda_items a JOIN tickets t ON t.id = a.ticket_id ORDER BY a.scheduled_date, a.scheduled_time`),
    db.prepare('SELECT * FROM report_fields ORDER BY template_id, position')
  ]);
  const [users, tickets, msgs, clients, tasks, sectors, services, slas, fiscal, reports, invoices, agenda, reportFields] = res.map(r => r.results);
  const byTicket = {};
  for (const m of msgs) (byTicket[m.ticket_id] ||= []).push({id: m.id, author: m.author, body: m.body, time: m.time_text, internal: !!m.internal, system: !!m.system});
  const sla = {};
  for (const s of slas) sla[s.priority] = {resp: s.resp_min, res: s.res_hours};
  const f = fiscal[0] || {};
  return {
    me: user,
    roleLabels: ROLE_LABEL,
    templates: buildTemplates(reportFields),
    categories: CATEGORIES,
    statuses: STATUSES,
    priorities: PRIORITIES,
    sectorTypes: SECTOR_TYPES,
    users: users.map(u => ({id: u.id, name: u.name, email: u.email, role: u.role, active: !!u.active, perms: PERMS[u.role]})),
    tickets: tickets.map(t => ({
      id: t.id, title: t.title, client: t.client_company, category: t.category, priority: t.priority, status: t.status,
      agent: t.agent, team: t.team, sectorId: t.sector_id || '', sla: t.sla, due: t.due_text, created: t.created_text,
      updated: t.updated_text, attachments: [], messages: byTicket[t.id] || []
    })),
    clients: clients.map(c => ({id: c.id, name: c.name, company: c.company, email: c.email, phone: c.phone, doc: c.doc, address: c.address, initials: c.initials, active: !!c.active})),
    agenda: agenda.map(a => ({
      id: a.id, ticketId: a.ticket_id, ticketTitle: a.ticket_title, client: a.client_company, priority: a.ticket_priority,
      taskType: a.task_type, date: a.scheduled_date, time: a.scheduled_time, technician: a.technician,
      address: a.address, status: a.status, createdBy: a.created_by
    })),
    tasks: tasks.map(t => ({id: t.id, title: t.title, agent: t.agent, due: t.due, priority: t.priority, done: !!t.done, ticket: t.ticket_id})),
    sectors: sectors.map(s => ({id: s.id, name: s.name, type: s.type, active: !!s.active})),
    services: services.map(s => ({id: s.id, name: s.name, code: s.code, active: !!s.active})),
    sla,
    fiscal: {cnpj: f.cnpj || '', legalName: f.legal_name || '', address: f.address || '', city: f.city || '', state: f.state || '', zip: f.zip || '', municipalRegistration: f.municipal_registration || '', issRate: f.iss_rate || 0},
    reports: reports.map(r => ({
      id: r.id, ticketId: r.ticket_id, ticketCategory: r.ticket_category, authorId: r.author_id, authorName: r.author_name,
      submittedAt: r.submitted_at, fields: JSON.parse(r.fields_json), values: JSON.parse(r.values_json), status: r.status,
      reviewerId: r.reviewer_id, reviewerName: r.reviewer_name, reviewedAt: r.reviewed_at, feedback: r.feedback,
      templateId: r.template_id, templateName: r.template_name, serviceId: r.service_id, serviceName: r.service_name, serviceCode: r.service_code
    })),
    invoices: invoices.map(n => ({
      id: n.id, number: n.number, reportId: n.report_id, ticketId: n.ticket_id, createdAt: n.created_at, client: n.client,
      status: n.status, templateName: n.template_name, serviceName: n.service_name, serviceCode: n.service_code,
      issRate: n.iss_rate, base: n.base, iss: n.iss, net: n.net, items: JSON.parse(n.items_json)
    }))
  };
}

/* ==================== Chamados ==================== */
async function getTicket(env, id) {
  const t = await env.DB.prepare('SELECT * FROM tickets WHERE id = ?').bind(id).first();
  if (!t) fail(404, 'Chamado não encontrado.');
  return t;
}
async function postMessage(env, ticketId, author, text, {internal = false, system = false} = {}) {
  await env.DB.prepare(
    'INSERT INTO ticket_messages (id, ticket_id, author, body, time_text, internal, system, seq) VALUES (?, ?, ?, ?, ?, ?, ?, (SELECT COALESCE(MAX(seq), 0) + 1 FROM ticket_messages WHERE ticket_id = ?))'
  ).bind(uid(), ticketId, author, text, nowText(), internal ? 1 : 0, system ? 1 : 0, ticketId).run();
}
/* ==================== Agenda ==================== */
async function validateAgenda(env, a) {
  if (!AGENDA_TYPES.includes(a.taskType)) fail(400, 'Selecione o tipo de tarefa.');
  const date = String(a.date || '');
  if (!isDate(date)) fail(400, 'Informe a data da visita.');
  const time = String(a.time || '');
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) fail(400, 'Informe a hora da visita (HH:MM).');
  const technician = String(a.technician || '');
  const u = await env.DB.prepare('SELECT id FROM users WHERE name = ? AND active = 1').bind(technician).first();
  if (!u) fail(400, 'Selecione um técnico ativo.');
  const address = optStr(a.address, 255, 'Endereço');
  return {taskType: a.taskType, date, time, technician, address};
}
async function addAgenda(env, user, ticketId, a) {
  const t = await getTicket(env, ticketId);
  const v = await validateAgenda(env, a);
  let address = v.address;
  if (!address) {
    const c = await env.DB.prepare('SELECT address FROM clients WHERE company = ?').bind(t.client_company).first();
    address = c ? c.address : '';
  }
  const id = uid();
  await env.DB.prepare(
    `INSERT INTO agenda_items (id, ticket_id, task_type, scheduled_date, scheduled_time, technician, address, status, created_by, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'Aberta', ?, ?)`
  ).bind(id, ticketId, v.taskType, v.date, v.time, v.technician, address, user.name, new Date().toISOString()).run();
  await postMessage(env, ticketId, 'Sistema', `${v.taskType} agendada para ${v.date.split('-').reverse().join('/')} às ${v.time} com ${v.technician} (por ${user.name}).`, {system: true});
  return id;
}
async function patchAgenda(env, user, id, b) {
  const item = await env.DB.prepare('SELECT * FROM agenda_items WHERE id = ?').bind(id).first();
  if (!item) fail(404, 'Agendamento não encontrado.');
  if (b.status !== undefined) {
    if (!AGENDA_STATUS.includes(b.status)) fail(400, 'Status de agendamento inválido.');
    await env.DB.prepare('UPDATE agenda_items SET status = ? WHERE id = ?').bind(b.status, id).run();
    await postMessage(env, item.ticket_id, 'Sistema', `Agendamento de ${item.scheduled_date.split('-').reverse().join('/')} ${item.scheduled_time}: status "${b.status}" por ${user.name}.`, {system: true});
  }
}

async function createTicket(env, user, b) {
  const subject = reqStr(b.title, 'Assunto', 5, 160);
  const client = await env.DB.prepare('SELECT * FROM clients WHERE id = ? AND active = 1').bind(String(b.client || '')).first();
  if (!client) fail(400, 'Selecione um cliente ativo.');
  if (!CATEGORIES.includes(b.category)) fail(400, 'Selecione o tipo de chamado.');
  const sector = await env.DB.prepare('SELECT * FROM sectors WHERE id = ? AND active = 1').bind(String(b.sector || '')).first();
  if (!sector) fail(400, 'Selecione um setor ativo.');
  if (!PRIORITIES.includes(b.priority)) fail(400, 'Selecione a prioridade.');
  const description = reqStr(b.description, 'Descrição', 1, 4000);
  // Valida a visita antes de criar o chamado, para não deixar chamado sem agenda por erro de preenchimento.
  if (b.visit) await validateAgenda(env, b.visit);
  const sla = await env.DB.prepare('SELECT res_hours FROM sla_policies WHERE priority = ?').bind(b.priority).first();
  const now = nowText();
  const res = await env.DB.prepare(
    `INSERT INTO tickets (title, client_company, category, priority, status, agent, team, sector_id, sla, due_text, created_text, updated_text)
     VALUES (?, ?, ?, ?, 'Novo', 'Não atribuído', ?, ?, 'ok', ?, ?, 'Agora')`
  ).bind(subject, client.company, b.category, b.priority, sector.name, sector.id, `Vence em ${sla ? sla.res_hours : 24}h`, now).run();
  const id = res.meta.last_row_id;
  await env.DB.prepare(
    'INSERT INTO ticket_messages (id, ticket_id, author, body, time_text, internal, system, seq) VALUES (?, ?, ?, ?, ?, 0, 0, 1)'
  ).bind(uid(), id, client.name, description, now).run();
  if (b.visit) await addAgenda(env, user, id, b.visit);
  return id;
}
async function patchTicket(env, user, id, b) {
  await getTicket(env, id);
  if (b.status !== undefined) {
    if (!STATUSES.includes(b.status)) fail(400, 'Status inválido.');
    await env.DB.prepare("UPDATE tickets SET status = ?, updated_text = 'Agora' WHERE id = ?").bind(b.status, id).run();
    await postMessage(env, id, 'Sistema', `Status alterado para "${b.status}" por ${user.name}.`, {system: true});
  }
  if (b.agent !== undefined) {
    const agent = b.agent ? String(b.agent) : 'Não atribuído';
    if (agent !== 'Não atribuído') {
      const u = await env.DB.prepare('SELECT id FROM users WHERE name = ? AND active = 1').bind(agent).first();
      if (!u) fail(400, 'Responsável inválido.');
    }
    await env.DB.prepare("UPDATE tickets SET agent = ?, updated_text = 'Agora' WHERE id = ?").bind(agent, id).run();
    await postMessage(env, id, 'Sistema', `Responsável alterado para ${agent} por ${user.name}.`, {system: true});
  }
}
async function postTicketMessage(env, user, id, b) {
  await getTicket(env, id);
  const text = reqStr(b.body, 'Mensagem', 1, 4000);
  await postMessage(env, id, user.name, text, {internal: !!b.internal});
  await env.DB.prepare("UPDATE tickets SET updated_text = 'Agora' WHERE id = ?").bind(id).run();
}

/* ==================== Relatórios e NF-e ==================== */
async function submitReport(env, user, ticketId, b) {
  const t = await getTicket(env, ticketId);
  if (t.status === 'Resolvido') fail(409, 'Chamado indisponível para encerramento.');
  const active = await env.DB.prepare("SELECT id FROM closing_reports WHERE ticket_id = ? AND status <> 'returned'").bind(ticketId).first();
  if (active) fail(409, 'Já existe um relatório aguardando revisão ou aprovado.');
  if (!TEMPLATE_NAMES[b.template]) fail(400, 'Selecione o tipo de relatório.');
  const tpl = await loadTemplate(env, b.template);
  const svc = await env.DB.prepare('SELECT * FROM services WHERE id = ? AND active = 1').bind(String(b.service || '')).first();
  if (!svc) fail(400, 'Selecione um tipo de serviço ativo.');
  const values = validateFields(tpl.fields, b.values || {});
  if (tpl.fields.some(f => f.id === 'value') && Number(values.value) <= 0) fail(400, 'O valor deve ser maior que zero.');
  const reportId = uid();
  try {
    await env.DB.prepare(
      `INSERT INTO closing_reports (id, ticket_id, ticket_category, author_id, author_name, template_id, template_name,
        service_id, service_name, service_code, fields_json, values_json, status, submitted_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`
    ).bind(reportId, ticketId, t.category, user.id, user.name, b.template, tpl.name, svc.id, svc.name, svc.code,
      JSON.stringify(tpl.fields), JSON.stringify(values), new Date().toISOString()).run();
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) fail(409, 'Já existe um relatório aguardando revisão ou aprovado.');
    throw e;
  }
  await postMessage(env, ticketId, 'Sistema', `${tpl.name} enviado por ${user.name}. Aguardando validação.`, {system: true});
}

async function invoiceIssues(env, r) {
  const fields = JSON.parse(r.fields_json), values = JSON.parse(r.values_json);
  const issues = fields.filter(f => f.required && !String(values[f.id] || '').trim()).map(f => `Campo obrigatório vazio: ${f.label}.`);
  if (!(Number(values.value) > 0)) issues.push('O relatório precisa de um "Valor (R$)" maior que zero.');
  const f = await env.DB.prepare('SELECT * FROM fiscal_config WHERE id = 1').first();
  if (!f || digits(f.cnpj).length !== 14 || !f.legal_name.trim() || !(f.iss_rate > 0)) {
    issues.push('Dados fiscais incompletos ou CNPJ inválido (Configurações → Dados fiscais).');
  }
  return {issues, fiscal: f, values};
}

async function reviewReport(env, user, reportId, b) {
  const r = await env.DB.prepare('SELECT * FROM closing_reports WHERE id = ?').bind(reportId).first();
  if (!r) fail(404, 'Relatório não encontrado.');
  if (r.status !== 'pending') fail(409, 'Este relatório já foi revisado.');
  if (r.author_id === user.id) fail(403, 'O autor não pode validar o próprio relatório.');
  const approve = b.approve === true;
  const feedback = optStr(b.feedback, 2000, 'Observação');
  const now = new Date().toISOString();
  const update = env.DB.prepare(
    "UPDATE closing_reports SET status = ?, reviewer_id = ?, reviewer_name = ?, reviewed_at = ?, feedback = ? WHERE id = ? AND status = 'pending'"
  ).bind(approve ? 'approved' : 'returned', user.id, user.name, now, feedback, reportId);
  if (!approve) {
    await env.DB.batch([update]);
    await postMessage(env, r.ticket_id, 'Sistema', `${r.template_name} devolvido por ${user.name} para correção.`, {system: true});
    return;
  }
  const {issues, fiscal, values} = await invoiceIssues(env, r);
  if (issues.length) fail(400, issues[0]);
  const base = Number(values.value);
  const iss = r2(base * fiscal.iss_rate / 100);
  const ticket = await env.DB.prepare('SELECT client_company FROM tickets WHERE id = ?').bind(r.ticket_id).first();
  const items = JSON.parse(r.fields_json).map(f => ({label: f.label, value: values[f.id] || '—'}));
  await env.DB.batch([
    update,
    env.DB.prepare(
      `INSERT INTO invoices (id, number, report_id, ticket_id, client, status, template_name, service_name, service_code,
        iss_rate, base, iss, net, items_json, created_at)
       VALUES (?, (SELECT COALESCE(MAX(number), 0) + 1 FROM invoices), ?, ?, ?, 'Simulação — sem validade fiscal', ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(uid(), reportId, r.ticket_id, ticket ? ticket.client_company : '—', r.template_name, r.service_name, r.service_code,
      fiscal.iss_rate, base, iss, r2(base - iss), JSON.stringify(items), now),
    env.DB.prepare(
      'INSERT INTO ticket_messages (id, ticket_id, author, body, time_text, internal, system, seq) VALUES (?, ?, ?, ?, ?, 0, 1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM ticket_messages WHERE ticket_id = ?))'
    ).bind(uid(), r.ticket_id, 'Sistema', `${r.template_name} validado por ${user.name}. NF-e demonstrativa gerada.`, nowText(), r.ticket_id)
  ]);
}

/* ==================== Cadastros e configurações ==================== */
async function createClient(env, b) {
  const name = reqStr(b.name, 'Nome', 2, 100);
  const company = reqStr(b.company, 'Empresa', 2, 100);
  const email = optStr(b.email, 255, 'Email');
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail(400, 'Email inválido.');
  const initials = company.split(/\s+/).map(w => w[0]).join('').slice(0, 2).toUpperCase();
  await env.DB.prepare('INSERT INTO clients (id, name, company, email, phone, doc, address, initials, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)')
    .bind(uid(), name, company, email, optStr(b.phone, 30), optStr(b.doc, 20), optStr(b.address, 255, 'Endereço'), initials).run();
}
async function createTask(env, b) {
  const title = reqStr(b.title, 'Título', 3, 160);
  const agent = String(b.agent || '');
  const u = await env.DB.prepare('SELECT id FROM users WHERE name = ? AND active = 1').bind(agent).first();
  if (!u) fail(400, 'Responsável inválido.');
  if (!isDate(String(b.due || ''))) fail(400, 'Informe um prazo válido.');
  if (!PRIORITIES.includes(b.priority)) fail(400, 'Prioridade inválida.');
  const ticketId = Number(b.ticket);
  await getTicket(env, ticketId);
  await env.DB.prepare('INSERT INTO tasks (id, title, agent, due, priority, done, ticket_id) VALUES (?, ?, ?, ?, ?, 0, ?)')
    .bind(uid(), title, agent, b.due, b.priority, ticketId).run();
}
async function createSector(env, b) {
  const name = reqStr(b.name, 'Nome', 2, 80);
  if (!SECTOR_TYPES.includes(b.type)) fail(400, 'Tipo de setor inválido.');
  try {
    await env.DB.prepare('INSERT INTO sectors (id, name, type, active) VALUES (?, ?, ?, 1)').bind(uid(), name, b.type).run();
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) fail(409, 'Setor já existente.');
    throw e;
  }
}
async function createService(env, b) {
  const name = reqStr(b.name, 'Nome do serviço', 2, 120);
  const code = String(b.code || '').trim();
  if (!/^\d{1,2}\.\d{2}$/.test(code)) fail(400, 'Código LC 116 no formato 1.07.');
  await env.DB.prepare('INSERT INTO services (id, name, code, active) VALUES (?, ?, ?, 1)').bind(uid(), name, code).run();
}
async function putSla(env, b) {
  const stmts = PRIORITIES.map(p => {
    const v = b[p] || {};
    const resp = Number(v.resp), res = Number(v.res);
    if (!Number.isInteger(resp) || resp < 1 || !Number.isInteger(res) || res < 1 || resp > 10080 || res > 8760) {
      fail(400, 'Os prazos precisam ser números inteiros positivos.');
    }
    return env.DB.prepare(
      'INSERT INTO sla_policies (priority, resp_min, res_hours) VALUES (?, ?, ?) ON CONFLICT(priority) DO UPDATE SET resp_min = excluded.resp_min, res_hours = excluded.res_hours'
    ).bind(p, resp, res);
  });
  await env.DB.batch(stmts);
}
async function putFiscal(env, b) {
  const cnpj = String(b.cnpj || '').trim();
  if (digits(cnpj).length !== 14) fail(400, 'CNPJ deve ter 14 dígitos.');
  const legal = reqStr(b.legalName, 'Razão social', 2, 150);
  const rate = Number(b.issRate);
  if (!(rate > 0 && rate <= 5)) fail(400, 'Alíquota ISS deve estar entre 0 e 5%.');
  await env.DB.prepare(
    `INSERT INTO fiscal_config (id, cnpj, legal_name, address, city, state, zip, municipal_registration, iss_rate)
     VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET cnpj = excluded.cnpj, legal_name = excluded.legal_name, address = excluded.address,
       city = excluded.city, state = excluded.state, zip = excluded.zip,
       municipal_registration = excluded.municipal_registration, iss_rate = excluded.iss_rate`
  ).bind(cnpj, legal, optStr(b.address, 200), optStr(b.city, 100), optStr(b.state, 2).toUpperCase(), optStr(b.zip, 12),
    optStr(b.municipalRegistration, 40), rate).run();
}

/* ==================== Roteamento ==================== */
async function route(req, env, url) {
  const method = req.method, path = url.pathname;
  if (method === 'POST' && path === '/api/login') return login(req, env);
  if (method === 'POST' && path === '/api/logout') return logout(req, env);

  const user = await currentUser(req, env);
  if (method === 'GET' && path === '/api/state') return json(await loadState(env, user));
  if (method === 'GET') fail(404, 'Não encontrado.');

  const seg = path.split('/').filter(Boolean).slice(1); // sem "api"
  const b = await body(req);

  if (seg[0] === 'tickets' && !seg[1] && method === 'POST') { need(user, 'receive'); return json({id: await createTicket(env, user, b)}, 201); }
  if (seg[0] === 'tickets' && seg[1] && !seg[2] && method === 'PATCH') { need(user, 'receive'); await patchTicket(env, user, Number(seg[1]), b); return ok(); }
  if (seg[0] === 'tickets' && seg[2] === 'messages' && method === 'POST') { need(user, 'receive'); await postTicketMessage(env, user, Number(seg[1]), b); return ok(201); }
  if (seg[0] === 'tickets' && seg[2] === 'reports' && method === 'POST') { need(user, 'report'); await submitReport(env, user, Number(seg[1]), b); return ok(201); }
  if (seg[0] === 'tickets' && seg[2] === 'agenda' && method === 'POST') { need(user, 'receive'); return json({id: await addAgenda(env, user, Number(seg[1]), b)}, 201); }
  if (seg[0] === 'agenda' && seg[1] && method === 'PATCH') { need(user, 'receive'); await patchAgenda(env, user, seg[1], b); return ok(); }
  if (seg[0] === 'reports' && seg[2] === 'review' && method === 'POST') { need(user, 'review'); await reviewReport(env, user, seg[1], b); return ok(); }
  if (seg[0] === 'clients' && method === 'POST') { need(user, 'receive'); await createClient(env, b); return ok(201); }
  if (seg[0] === 'tasks' && !seg[1] && method === 'POST') { need(user, 'receive'); await createTask(env, b); return ok(201); }
  if (seg[0] === 'tasks' && seg[1] && method === 'PATCH') {
    need(user, 'receive');
    const res = await env.DB.prepare('UPDATE tasks SET done = ? WHERE id = ?').bind(b.done ? 1 : 0, seg[1]).run();
    if (!res.meta.changes) fail(404, 'Tarefa não encontrada.');
    return ok();
  }
  if (seg[0] === 'sectors' && method === 'POST') { need(user, 'configure'); await createSector(env, b); return ok(201); }
  if (seg[0] === 'services' && !seg[1] && method === 'POST') { need(user, 'configure'); await createService(env, b); return ok(201); }
  if (seg[0] === 'services' && seg[1] && method === 'PATCH') {
    need(user, 'configure');
    const res = await env.DB.prepare('UPDATE services SET active = ? WHERE id = ?').bind(b.active ? 1 : 0, seg[1]).run();
    if (!res.meta.changes) fail(404, 'Serviço não encontrado.');
    return ok();
  }
  if (seg[0] === 'report-fields' && !seg[1] && method === 'POST') { need(user, 'configure'); await addReportField(env, b); return ok(201); }
  if (seg[0] === 'report-fields' && seg[1] && seg[2] && method === 'DELETE') { need(user, 'configure'); await deleteReportField(env, seg[1], seg[2]); return ok(); }
  if (path === '/api/fiscal' && method === 'PUT') { need(user, 'configure'); await putFiscal(env, b); return ok(); }
  if (path === '/api/sla' && method === 'PUT') { need(user, 'configure'); await putSla(env, b); return ok(); }
  fail(404, 'Não encontrado.');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);
    try {
      return await route(request, env, url);
    } catch (err) {
      if (err instanceof HttpError) return json({error: err.message}, err.status);
      console.error(err);
      return json({error: 'Erro interno. Tente novamente.'}, 500);
    }
  }
};
