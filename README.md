# ATENDA — versão gratuita

Sistema de atendimento com relatórios de encerramento, validação e NF-e demonstrativa.
Roda inteiro na **Cloudflare, no plano gratuito**: o Worker serve a API e as páginas, e o
banco é o **D1** (SQLite). Não usa Supabase.

## O que tem aqui

```
atenda-gratis/
├── public/index.html     # interface (single page)
├── src/worker.js         # API: login, regras de negócio e permissões
├── schema.sql            # tabelas, índices e restrições (instalação nova)
├── seed.sql              # dados de demonstração (senha: Trocar123!)
├── migracao-v2.sql       # atualização de um banco já criado (rodar uma vez)
├── scripts/hash-password.mjs  # gera hash para trocar senhas
├── wrangler.toml         # configuração do Worker e do banco
└── package.json
```

## Pré-requisitos

- Node.js 18 ou mais novo
- Conta gratuita na Cloudflare (https://dash.cloudflare.com)

## 1. Rodar no seu computador

```bash
npm install
npm run db:local      # cria as tabelas e os dados de demonstração no banco local
npm run dev           # abre em http://localhost:8787
```

Entre com `ana@atenda.com.br` e senha `Trocar123!`.

Contas de demonstração (todas com a mesma senha):

| Email | Perfil | Pode |
|---|---|---|
| ana@atenda.com.br | Gestor | tudo |
| lucas@atenda.com.br | Atendente | atender chamados e enviar relatórios |
| paula@atenda.com.br | Revisor | atender chamados e validar relatórios |

## 2. Publicar gratuitamente

```bash
npx wrangler login            # abre o navegador para autorizar sua conta
npx wrangler d1 create atenda
```

O comando `d1 create` mostra um `database_id`. Cole-o em `wrangler.toml`, no lugar de
`COLE_O_ID_DO_D1_AQUI`. Depois:

```bash
npm run db:remote     # cria as tabelas e os dados no banco da Cloudflare
npm run deploy        # publica; o comando mostra o endereço (https://atenda.SEU-USUARIO.workers.dev)
```

## 3. Antes de usar com a equipe

**Troque as senhas de demonstração.** Gere o hash e atualize o usuário:

```bash
npm run hash -- "senha-forte-aqui"
npx wrangler d1 execute atenda --remote --command "UPDATE users SET password_hash='COLE_O_HASH' WHERE email='ana@atenda.com.br'"
```

Para contas novas, insira em `users` (com `id`, `name`, `email`, `role`, `active` e `password_hash`).
Papéis válidos: `gestor`, `atendente`, `revisor`.

## Agenda

Ao abrir um chamado, marque **Gerar agendamento na agenda** e informe tipo de tarefa
(manutenção preventiva, corretiva, instalação ou visita técnica), data, hora, técnico e endereço.
Em branco, o endereço é o do cliente. Também é possível agendar depois, na própria página do chamado.

- A página **Agenda** mostra o mês em calendário ou em lista, com filtro por técnico.
- Cada visita tem status: Aberta, Em andamento, Concluída ou Cancelada. Cada mudança entra no histórico do chamado.
- Quem pode atender chamados (atendente, revisor e gestor) cria e atualiza agendamentos.

## Campos dos relatórios

Em **Configurações**, o gestor inclui ou exclui campos de cada tipo de relatório
(texto, texto longo, data ou número, obrigatório ou não). O formulário de envio e o relatório
passam a usar a lista atualizada. Relatórios já enviados mantêm os campos que tinham.

O campo **Valor (R$)** não pode ser excluído, porque é a base da NF-e demonstrativa.

## Atualizar um banco já criado

Se você já publicou uma versão anterior, **não rode `db:remote` de novo** (ele reaplica os dados de
demonstração). Rode apenas a migração, uma única vez:

```bash
npx wrangler d1 execute atenda --remote --file=migracao-v2.sql
```

Para o banco local, use `--local` no lugar de `--remote`.

## Regras aplicadas no servidor

- **Permissões:** cada ação exige o perfil certo, mesmo que a tela esconda o botão.
- **Autor não valida o próprio relatório** (verificado na API).
- **Um relatório ativo por chamado:** garantido pelo banco (índice único), não só pela tela.
- **Tipo de chamado gravado no relatório** no momento do envio, para os relatórios por tipo ficarem corretos mesmo se o chamado mudar depois.
- **NF-e é simulação:** numeração sequencial e ISS calculado, sem validade fiscal.
- **Sessão:** cookie `HttpOnly`, `Secure` e `SameSite=Lax`, válido por 7 dias. A senha é guardada como PBKDF2-SHA256 (100 mil iterações).
- **Proteção contra envio entre sites:** a API só aceita requisições em JSON.

## Limitações conhecidas

- **Sem limite de tentativas de login.** Antes de expor na internet pública, convém adicionar
  limitação (por exemplo, com as regras de limitação de taxa da Cloudflare).
- **Sem recuperação de senha nem cadastro pela tela.** Contas são criadas pelo banco.
- **Sem trilha de auditoria** além das mensagens do próprio chamado.
- **NF-e não é emitida de verdade.** A emissão fiscal exige integração com um serviço autorizado.
- **Limites do plano gratuito:** o plano tem cotas diárias de requisições e de operações no banco.
  Confira os valores atuais no painel da Cloudflare. Para uma equipe pequena, costumam ser suficientes.

## Comandos úteis

| Comando | O que faz |
|---|---|
| `npm run dev` | roda localmente |
| `npm run db:local` | cria tabelas e dados no banco local (para zerar, apague a pasta `.wrangler` e rode de novo) |
| `npm run db:remote` | aplica esquema e dados no banco publicado |
| `npm run deploy` | publica a versão atual |
| `npm run hash -- "senha"` | gera hash de senha |
