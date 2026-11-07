# ATENDA — versão gratuita

Sistema de atendimento com relatórios de encerramento, validação e NF-e demonstrativa.
Roda inteiro na **Cloudflare, no plano gratuito**: o Worker serve a API e as páginas, e o
banco é o **D1** (SQLite). Não usa Supabase.

## O que tem aqui

```
atenda-gratis/
├── public/index.html     # interface (single page)
├── public/abrir.html     # página pública para o cliente abrir chamado
├── public/favicon.svg    # símbolo Ω (favicon e ícone)
├── public/brand/         # arte do logo usada na tela de login
├── src/worker.js         # API: login, regras de negócio e permissões
├── schema.sql            # tabelas, índices e restrições (instalação nova)
├── seed.sql              # dados de demonstração (senha: Trocar123!)
├── migracao-v2.sql       # atualização de um banco já criado (rodar uma vez)
├── migracao-v3.sql       # campos de lista, campos do chamado e anexos (rodar uma vez)
├── migracao-v4.sql       # arquivar chamados e tarefas (rodar uma vez)
├── migracao-v5.sql       # link de abertura de chamado por cliente (rodar uma vez)
├── migracao-v6.sql       # colaboradores, vencimentos e avisos no app (rodar uma vez)
├── migracao-v7.sql       # perfis de acesso por tela (rodar uma vez)
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

No relatório, os campos obrigatórios aparecem sempre. Os opcionais entram pelo botão **+ Mais**, que também adiciona itens extras (texto livre ou anexo, com nome digitado na hora), como no Auvo. Até 5 itens extras por relatório.

Em **Configurações**, o gestor inclui ou exclui campos de cada tipo de relatório. Cada campo tem uma
**categoria**:

- **Texto** e **Texto longo**;
- **Data** e **Número**;
- **Lista de opções**: o gestor informa as opções uma a uma com **+ Adicionar opção**. Pode permitir
  **texto livre** (a opção "Outra" abre um campo para digitar). O botão **Opções** permite editar a lista depois;
- **Anexo (imagem ou PDF)**: o usuário envia um arquivo de até 5 MB (JPG, PNG, GIF, WEBP ou PDF).
  O tipo é conferido pelo conteúdo do arquivo, não só pela extensão.

O formulário de envio e o relatório passam a usar a lista atualizada. Relatórios já enviados mantêm os
campos que tinham. O campo **Valor (R$)** não pode ser excluído, porque é a base da NF-e demonstrativa.

## Campos do chamado

Em **Configurações → Campos do chamado**, o gestor inclui ou remove campos do formulário de abertura,
com as mesmas categorias acima (como no Auvo). Os valores aparecem em **Informações do chamado** e na
revisão do relatório. Campos marcados como obrigatórios precisam ser preenchidos ao abrir o chamado.

## Revisão e informações do chamado

A abertura do chamado mostra os dados de contato do cliente ao escolhê-lo. A tela de detalhe tem o bloco
**Informações do chamado** (cliente, contato, documento, endereço, setor, solicitação e campos extras).
A revisão do relatório mostra, além dos campos enviados, o contexto completo: dados do chamado, visitas
agendadas e as últimas mensagens (sem as notas internas).

## Arquivar

Só o gestor arquiva. Arquivar **não apaga nada**:

- **Chamados** saem da lista e do Kanban. Ficam na aba **Arquivados** de Chamados e podem ser restaurados. Chamado arquivado não recebe mensagens, mudanças de status nem agendamentos até ser restaurado. A NF-e emitida continua no histórico.
- **Tarefas** saem da lista e ficam em **Tarefas arquivadas**, com botão para restaurar.
- **Clientes** arquivados não aparecem na abertura de novos chamados. Podem ser reativados em Clientes.

## Link para o cliente abrir chamado

Cada cliente tem um link próprio, na tela **Clientes**:

- **Copiar link** copia o endereço (`/abrir?t=...`) para mandar ao cliente por WhatsApp ou email.
- Pelo link, o cliente abre chamado **só para a empresa dele**, sem login. Ele informa assunto, tipo, setor, descrição e os campos extras do chamado. Campos com anexo obrigatório deixam o formulário indisponível.
- **Novo link** gera outro endereço e invalida o antigo (use se o link vazar).
- Cliente arquivado não consegue abrir chamado pelo link até ser reativado.
- Em cada chamado aberto há o botão **Enviar aviso pelo WhatsApp**, com um texto pronto avisando que o chamado foi aberto. Ele usa o telefone cadastrado do cliente (cadastre o telefone para o botão aparecer).

## Visual e navegação

- **Identidade:** ATENDA · Soluções Omega, com o símbolo Ω e o balão de conversa, em fundo azul-marinho escuro e destaques em roxo e lilás. Verde indica sucesso, amarelo/laranja atenção e vermelho erro ou SLA vencido.
- **Menu lateral fixo** agrupado em Operação, Gestão, Equipe e Sistema, com contador de chamados não concluídos e de avisos. No celular, o menu abre pelo botão ☰.
- **Cabeçalho:** saudação, busca global (chamados e clientes; Enter abre a lista de chamados filtrada), sino de avisos, avatar com nome e nível de acesso, menu do perfil e botão Sair.
- **Dashboard:** 8 indicadores clicáveis, evolução dos chamados por dia (7, 30 ou 90 dias), gráficos por status, prioridade e tipo, ações rápidas, visão de SLA, próximos vencimentos, chamados prioritários e últimos chamados.
- **Chamados:** filtros rápidos (precisam de atenção, SLA vencido, atribuídos a mim…), busca, filtros por status, tipo, prioridade, responsável e período, linhas destacadas quando o SLA está em risco ou vencido e menu de ações em cada linha.
- **Novo chamado** em blocos (cliente, assunto, classificação e responsável, informações adicionais, anexos, prazo e SLA).
- **Chamado** no formato de help desk: conversa com notas internas destacadas, eventos de status na linha do tempo, painel de detalhes, SLA e dados do cliente.
- Confirmações e cadastros rápidos abrem em janelas na própria tela.

## Perfis de acesso

Em **Configurações → Perfis de acesso**, quem pode configurar cria perfis e marca, para cada um:

- **Telas que abre:** Dashboard, Chamados, Novo chamado, Agenda, Kanban, Tarefas, Clientes, NF-e, Relatórios, SLA, Colaboradores, Avisos e Configurações.
- **O que pode fazer:** receber e atender chamados, enviar relatórios, validar relatórios e gerenciar configurações.

Os perfis **Gestor**, **Atendente** e **Revisor** já vêm prontos, com o mesmo acesso que esses papéis tinham antes. O Gestor tem acesso total e não pode ser alterado nem excluído, para sempre haver alguém que administre o sistema. Atendente e Revisor podem ser ajustados.

O perfil de cada pessoa é escolhido em **Configurações → Usuários** (ao criar o usuário ou na lista). A mudança vale na hora, sem precisar sair e entrar de novo.

Regras:

- O bloqueio vale **no servidor**: uma tela fechada some do menu e a API também recusa as ações dela.
- Ninguém troca o próprio perfil nem tira de si a tela Configurações ou a permissão de configurar.
- Perfil com usuários não pode ser excluído; troque o perfil deles antes.
- Ver os dados de Colaboradores (exames e documentos) continua exigindo a permissão de configurar.

## Colaboradores, vencimentos e avisos

Na aba **Colaboradores** (só o gestor vê), cada colaborador tem:

- **EPIs:** nome, CA, data de entrega e validade.
- **Exames:** tipo (admissional, periódico, mudança de função, retorno ao trabalho, demissional), nome, data em que foi feito e validade em meses. O vencimento é calculado sozinho.
- **Documentos:** INSS, FGTS, nota fiscal ou outro. Cada documento começa como **Pendente** e recebe o arquivo anexado (imagem ou PDF, até 5 MB), que vira **Enviado**.

O bloco **Vencimentos** mostra o que está vencido ou perto de vencer. Os alertas são criados em 180, 90 e 60 dias antes e também quando vence, para o gestor e para o próprio colaborador (se ele tiver login).

Para o colaborador ter login, preencha email e senha (mínimo de 8 caracteres) ao cadastrá-lo. Ele entra no ATENDA como atendente e recebe os avisos de chamado.

**Avisos** (menu do app): chamados novos e vencimentos. Um aviso fica marcado como lido ao ser aberto, e há o botão **Marcar todas como lidas**.

Ao abrir um chamado, recebem aviso no app os usuários com a opção **Aviso de chamado** ligada em **Configurações → Usuários** (por padrão, gestores) e os colaboradores com login.

Email e WhatsApp para esses avisos **ainda não estão configurados**: por enquanto os avisos aparecem só dentro do app.

## Anexos

Os arquivos são guardados no próprio D1, em blocos (tabelas `attachments` e `attachment_chunks`).
Por isso o limite é de 5 MB por arquivo. Para armazenamento maior no futuro, o caminho é o R2 da Cloudflare.

## Atualizar um banco já criado

Se você já publicou uma versão anterior, **não rode `db:remote` de novo** (ele reaplica os dados de
demonstração). Rode apenas as migrações necessárias, cada uma **uma única vez** e na ordem:

- quem já aplicou a **v6** (colaboradores): rode só a **v7**;
- quem já aplicou a **v5** (link do cliente): rode a **v6** e depois a **v7**;
- quem já aplicou a **v4** (arquivar): rode a **v5**, a **v6** e depois a **v7**;
- quem já tem a versão com campos de lista e anexos (`migracao-v3.sql` aplicada): rode a **v4** e depois a **v5**;
- quem está com a versão anterior à v3: rode a **v3**, depois a **v4** e depois a **v5**.

```bash
npx wrangler d1 execute atenda --remote --file=migracao-v2.sql
npx wrangler d1 execute atenda --remote --file=migracao-v3.sql
npx wrangler d1 execute atenda --remote --file=migracao-v4.sql
npx wrangler d1 execute atenda --remote --file=migracao-v5.sql
npx wrangler d1 execute atenda --remote --file=migracao-v6.sql
npx wrangler d1 execute atenda --remote --file=migracao-v7.sql
```

No Cloudflare, pelo console do D1 (aba Console), cole o conteúdo de cada arquivo de migração (na ordem) e execute.
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
- **Sem recuperação de senha.** As contas são criadas pelo gestor em Configurações → Usuários.
- **Avisos só dentro do app.** Email e WhatsApp para avisos de chamado e de vencimento ainda não estão ligados.
- **Checklists e assinatura eletrônica** (checklist de execução de serviço, checklist do chamado preenchido pelo cliente e assinatura online) ainda não foram feitos.
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
