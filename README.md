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
├── migracao-v8.sql       # novos modelos de relatório técnico (rodar uma vez)
├── migracao-v9.sql       # unidades/equipamentos por cliente e novos campos do chamado (rodar uma vez)
├── migracao-v10.sql      # corrige 7 modelos de relatório para bater com o questionário oficial (rodar uma vez)
├── limpeza-dados-ficticios.sql  # remove clientes/colaboradores de demonstração (rodar quando quiser)
├── cadastro-clientes-auvodesk.sql              # importa os clientes reais (rodar uma vez)
├── migracao-v11.sql      # catálogo de produtos e serviços comerciais (rodar uma vez)
├── cadastro-equipamentos-auvodesk.sql   # todos os equipamentos, já associados a cada cliente (rodar uma vez)
├── cadastro-produtos-auvodesk.sql       # catálogo de produtos (rodar uma vez)
├── cadastro-servicos-auvodesk.sql       # catálogo de serviços comerciais (rodar uma vez)
├── migracao-v12.sql      # integração com o Omie: config, rastreio de sincronização e NF-e (rodar uma vez)
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
campos que tinham. O campo **Valor (R$)** (quando existir no modelo) não pode ser excluído, porque é a
base da NF-e demonstrativa.

### Modelos de relatório técnico (migração v8)

Além dos 4 modelos originais (serviço, atendimento, externo, interno), a **migracao-v8.sql** adiciona 17
modelos importados dos formulários já usados pela equipe: Aferição, Atendimento Presencial, Atendimento
Remoto, Avaliação Câmeras do Vídeo/Fuga, Avaliação de Pista de Pesagem - Precisão, Calibração, Câmeras de
Fuga, Checklist - Calibração, Checklist - Sistema de Pesagem Geral, Checklist Geral, Manutenção de
Periféricos, Manutenção de Pista, Pista de Pesagem - Precisão, Relatório de Manutenção - Balança de
Pesagem Veicular (Modelo APRB), Relatório de Visita, Sem Foros e Sistema de Pesagem - Precisão Geral.

Os campos de cada modelo foram classificados automaticamente a partir dos cabeçalhos originais (texto,
texto longo, data, anexo ou lista de opções) e já aparecem na tela **Configurações → Relatórios**, onde o
gestor pode **editar, reordenar, marcar como obrigatório, trocar as opções de lista ou excluir** qualquer
campo — exatamente como já funcionava para os 4 modelos antigos. Como muitos desses formulários têm
dezenas de campos (o maior chega a 96), o limite por relatório subiu de 20 para 150 campos.

Como a lista de modelos passou a ser maior, a migração reconstrói a tabela `report_fields` sem perder os
dados existentes (ela só amplia a restrição que antes travava em 4 tipos fixos).

### Unidades, equipamentos e novos campos do chamado (migração v9)

A **migracao-v9.sql** adiciona dois cadastros por cliente — **Unidade PGF** (`client_units`) e
**Equipamento** (`client_equipment`) — espelhando o que a equipe já usa no AuvoDesk. Em **Novo chamado**,
depois de escolher o cliente aparecem os seletores **Unidade PGF** e **Equipamento** com o que já está
cadastrado para aquele cliente; se faltar algo na lista, os botões **+ Unidade não cadastrada** e
**+ Equipamento não cadastrado** cadastram na hora, sem sair do formulário. Hoje o chamado guarda **um**
equipamento por chamado (`tickets.equipment_id`) — se no futuro for preciso vincular vários equipamentos
ao mesmo chamado, isso exigirá uma tabela de associação (N-para-N) e uma nova migração.

A mesma migração adiciona ao formulário de Novo Chamado os campos **Prioridade**, **Departamento**,
**Motivo da solicitação**, **Qual tipo de atendimento?**, **Contato de cliente**, **Tipo de solicitação**,
**Entrada de equipamento**, **Cidade**, **Quantidade de itens**, uma segunda **Descrição**, **Observação**,
**Frete** e **NF Entrada/Saída Nº** — todos editáveis depois em **Configurações → Campos do chamado**,
igual a qualquer outro campo. As opções de **Motivo da solicitação** são as mesmas para todos os clientes
(só o equipamento disponível muda por cliente); todo campo de lista aqui foi marcado com **texto livre**,
então sempre existe a opção **"Outra"** para adicionar ou corrigir algo que não estiver na lista.

### Correção de 7 modelos pelo questionário oficial (migração v10)

A **migracao-v10.sql** substitui os campos de 7 modelos (Aferição, Atendimento Presencial, Atendimento
Remoto, Calibração, Manutenção de Periféricos, Manutenção de Pista e Relatório de Manutenção - Balança
APRB) pelos campos exatos de uma planilha de questionários enviada pela equipe, corrigindo o que a
importação automática da v8 tinha classificado errado:

- **Selo reparado**, **Situação Balança** e **Situação Periférico** eram lista (OK/Não OK/N/A) e viraram
  **texto livre**, como no questionário original;
- **Data e Horário de ida/volta à balança** eram campo de **data** e viraram **texto** (o questionário
  pede data e hora juntas, em texto livre);
- **obrigatório** foi corrigido campo a campo conforme o questionário (vários campos que estavam
  opcionais são, na verdade, obrigatórios);
- 4 campos que eu tinha adicionado por conta própria em cada modelo (**Nome/Documento de quem assinou**,
  duplicado para os dois signatários) foram **removidos** — não existem no questionário oficial;
- os campos de lista (como **Status do serviço**) continuam com **texto livre** habilitado, para sempre
  dar a opção de adicionar ou corrigir algo fora da lista.

Os outros 10 modelos importados na v8 (Avaliação de Câmeras, Avaliação de Pista, Câmeras de Fuga, os 3
Checklists, Pista de Pesagem - Precisão, Relatório de Visita, Sem Foros e Sistema de Pesagem - Precisão
Geral) não tinham planilha oficial equivalente até agora e continuam como foram classificados
automaticamente — mande a planilha oficial deles se também precisar corrigir.

`cadastro-clientes-auvodesk.sql` cadastra os **42 clientes reais** exportados do AuvoDesk (nome, CNPJ/CPF,
endereço, telefone, email e status ativo/inativo) e `cadastro-equipamentos-auvodesk.sql` cadastra os
**155 equipamentos** já associados ao cliente certo, a partir da mesma exportação oficial — substituindo
qualquer cadastro parcial feito antes manualmente pelas telas uma a uma.

## Cadastro (clientes, equipamentos, produtos e serviços)

A migração **v11** cria duas tabelas novas — `products` (catálogo de produtos/estoque) e
`catalog_services` (catálogo comercial de serviços, com preço) — e o sistema ganha uma tela **Cadastro**
no fim do menu, com 4 abas:

- **Clientes**: a mesma lista de **Clientes**, com a contagem de equipamentos de cada um; clicar nela abre
  a aba Equipamentos já filtrada por aquele cliente;
- **Equipamentos**: lista de todos os equipamentos, com filtro por cliente (o mesmo comportamento de
  "escolher o cliente e já aparecem os equipamentos dele" que existe em **Novo chamado** continua
  funcionando igual, sem mudança);
- **Produtos**: catálogo de produtos com categoria, custo, preço e estoque;
- **Serviços**: catálogo comercial de serviços com preço e código externo — **diferente** da lista de
  códigos LC 116 usada na emissão de NF-e (essa continua em Configurações → Serviços, sem mudança).

Cada aba tem um botão para cadastrar um novo item na hora. `cadastro-produtos-auvodesk.sql` e
`cadastro-servicos-auvodesk.sql` importam o catálogo real exportado do AuvoDesk (548 produtos e 61
serviços).

## Integração com o Omie

A migração **v12** acrescenta a integração com o **Omie** (ERP), em **Configurações → Integrações**:

- **Configuração**: App Key e App Secret do Omie (o App Secret, depois de salvo, nunca é mostrado de
  volta ao navegador — só o backend o guarda) e um interruptor para ativar/desativar a integração.
- **Testar conexão**: faz uma chamada real ao Omie (`ListarClientes`) só para confirmar que as
  credenciais funcionam, e grava a data/hora do último teste.
- **Sincronizar clientes / produtos / serviços**: envia (`IncluirCliente` / `IncluirProduto` /
  `IncluirCadastroServico`) os clientes, produtos e serviços cadastrados aqui para o Omie, um a um,
  registrando o código que o Omie devolve (`omie_code`) em cada registro e mostrando quantos itens
  foram enviados e quantos falharam, com o motivo da falha.
- **Emitir NF-e pelo Omie**: na tela **NF-e**, cada nota demonstrativa que ainda não foi enviada ganha um
  botão **Emitir pelo Omie**. Isso chama `IncluirNfse` no Omie e grava o número/protocolo devolvido na
  própria nota. É uma ação **manual, item por item** — nunca automática — porque a emissão fiscal real
  tem consequência e deve ser confirmada pessoa a pessoa.

**Importante — integração ainda não testada contra uma conta real:** os nomes de chamada e de campos
usados (`geral/clientes`, `geral/produtos`, `servicos/servico`, `servicos/nfse`, e os campos de cada
`param`) seguem a documentação pública do Omie, mas foram implementados sem credenciais disponíveis para
testar de fato. Qualquer erro do Omie é mostrado para quem está usando, com a mensagem original
(`faultstring`) — assim, no primeiro uso com credenciais reais, qualquer ajuste de nome de campo ou de
chamada fica fácil de identificar e corrigir. Antes de depender da sincronização ou da emissão de NF-e
pelo Omie em produção, use **Testar conexão** e sincronize um item de cada vez para confirmar que está
tudo certo.

## Módulos ocultos

A constante `HIDDEN_SCREENS`, no topo do `public/index.html`, controla quais telas ficam fora do menu,
dos atalhos do dashboard e do acesso direto por link — sem apagar nada do banco. Hoje estão ocultos
**Kanban, Tarefas, NF-e e SLA**. Para reexibir um módulo, basta tirar a chave dele dessa lista e publicar
de novo; nada mais no sistema muda.

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

## Limpar clientes e colaboradores de demonstração

O arquivo **limpeza-dados-ficticios.sql** remove os clientes e colaboradores de demonstração do `seed.sql`
(julia, lucas, mariana, pedro e paula), mantendo **apenas a conta `ana@atenda.com.br`** como login. Rode
quando quiser, pelo console do D1 ou por `wrangler d1 execute atenda --remote --file=limpeza-dados-ficticios.sql`.
Ele:

- apaga todos os registros da tabela **Clientes** (não há vínculo de chave estrangeira entre chamados e
  clientes — os chamados já abertos continuam intactos, com o nome do cliente gravado no próprio chamado);
- apaga todos os registros de **Colaboradores** (e os EPIs, exames e documentos ligados a eles);
- apaga os relatórios de encerramento que porventura tenham sido enviados ou revisados pelos usuários
  removidos (para não deixar referência quebrada);
- apaga as contas de usuário de login, exceto a da Ana Martins.

Chamados, tarefas e agendamentos antigos **não são apagados** — eles só não têm mais o cadastro de cliente
associado na tela de Clientes. Depois, crie os clientes e colaboradores reais pelas telas normais.

## Atualizar um banco já criado

Se você já publicou uma versão anterior, **não rode `db:remote` de novo** (ele reaplica os dados de
demonstração). Rode apenas as migrações necessárias, cada uma **uma única vez** e na ordem:

- quem já aplicou a **v10** (modelos corrigidos): rode só a **v11**;
- quem já aplicou a **v9** (unidades/equipamentos): rode a **v10** e depois a **v11**;
- quem já aplicou a **v8** (modelos de relatório técnico): rode a **v9**, a **v10** e depois a **v11**;
- quem já aplicou a **v7** (perfis de acesso): rode a **v8**, a **v9**, a **v10** e depois a **v11**;
- quem já aplicou a **v6** (colaboradores): rode a **v7** e depois a **v8**;
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
npx wrangler d1 execute atenda --remote --file=migracao-v8.sql
npx wrangler d1 execute atenda --remote --file=migracao-v9.sql
npx wrangler d1 execute atenda --remote --file=migracao-v10.sql
npx wrangler d1 execute atenda --remote --file=migracao-v11.sql
npx wrangler d1 execute atenda --remote --file=migracao-v12.sql
```

No Cloudflare, pelo console do D1 (aba Console), cole o conteúdo de cada arquivo de migração (na ordem) e execute.
Para o banco local, use `--local` no lugar de `--remote`.

Depois da **v9/v10**, para importar os clientes e equipamentos reais (opcional, uma única vez e na ordem):

```bash
npx wrangler d1 execute atenda --remote --file=cadastro-clientes-auvodesk.sql
npx wrangler d1 execute atenda --remote --file=cadastro-equipamentos-auvodesk.sql
npx wrangler d1 execute atenda --remote --file=cadastro-produtos-auvodesk.sql
npx wrangler d1 execute atenda --remote --file=cadastro-servicos-auvodesk.sql
```

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
