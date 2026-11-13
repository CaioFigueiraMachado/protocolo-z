# Protocolo Z

> Sobreviver é um trabalho em equipe.

App mobile em **Flutter + Supabase** em que sobreviventes de um apocalipse zumbi pertencem a facções, cadastram abrigos no mapa, saem em expedições, trocam suprimentos e emitem alertas de horda em tempo real.

**A regra principal do projeto: o app é tratado como não confiável.** Inventário, reputação, facção, expedições, trocas e alertas só mudam por **funções RPC no banco**, protegidas por **RLS**. Mesmo que alguém altere o código do app, o banco recusa a trapaça.

---

## Sumário

1. [Tecnologias](#tecnologias)
2. [Como rodar](#como-rodar)
3. [Tabela de reputação](#tabela-de-reputação)
4. [Facções](#facções)
5. [Arquitetura (camadas)](#arquitetura-camadas)
6. [Widgets personalizados](#widgets-personalizados)
7. [Gerenciamento de estado (Riverpod)](#gerenciamento-de-estado-riverpod)
8. [Rotas (GoRouter) e redirect com 3 estados](#rotas-gorouter-e-redirect-com-3-estados)
9. [Segurança: RLS e RPC](#segurança-rls-e-rpc)
10. [Troca atômica](#troca-atômica)
11. [Teste de trapaça](#teste-de-trapaça)
12. [Roteiro do desafio final](#roteiro-do-desafio-final)

---

## Tecnologias

| Recurso | Pacote / serviço |
|---|---|
| Estado | `flutter_riverpod` 3 |
| Rotas | `go_router` (StatefulShellRoute + redirect) |
| Backend | `supabase_flutter` (Auth, PostgreSQL, RPC, Realtime, Storage) |
| Mapa | `flutter_map` + OpenStreetMap (sem chave de API) |
| Localização | `geolocator` (com tratamento de permissão negada) |
| Câmera/galeria | `image_picker` |
| Logos e emblemas | `flutter_svg` |
| Fontes | `google_fonts` (Archivo + Instrument Sans) |

---

## Como rodar

### 1. Criar o banco no Supabase

1. Crie um projeto em <https://supabase.com>.
2. No **SQL Editor**, rode os scripts da pasta `supabase/` **nesta ordem**:

   | Arquivo | Conteúdo |
   |---|---|
   | `01_schema.sql` | Tabelas, `check` e `unique` |
   | `02_rls.sql` | Privilégios e policies de RLS |
   | `03_functions.sql` | Trigger de perfil, RPCs e views de ranking |
   | `04_storage_realtime.sql` | Buckets, policies do Storage, Realtime e pg_cron |
   | `05_seed.sql` | Facções, itens e tipos de expedição |

3. **Authentication → Sign In / Providers → Email**: desative **"Confirm email"** para a demonstração. Se ficar ativado, o jogador precisa clicar no link do e-mail antes de entrar, e o servidor de e-mail gratuito do Supabase só envia poucos e-mails por hora.
4. (Opcional) Rode `supabase/tests/teste_seguranca.sql` para conferir as regras. Ele mostra um relatório OK/FALHOU. No fim, apague os usuários de teste com a linha de limpeza indicada no arquivo.

### 2. Configurar as chaves

As chaves ficam em `lib/core/env.dart`. Use **somente a chave pública** (`anon` / publishable). Para usar outro projeto sem editar o código:

```bash
flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_PUBLICA
```

> ⚠️ A chave `service_role` **nunca** deve aparecer no app nem no repositório.

### 3. Executar

```bash
flutter pub get
flutter run
```

> **Windows:** se a compilação falhar com `OS error 122` / `Failed to canonicalize path`, o caminho da pasta do projeto está longo demais. Mova o projeto para um caminho curto (ex.: `C:\dev\protocolo_z`).

---

## Tabela de reputação

A reputação só é concedida pelo **servidor**, dentro das funções RPC (`supabase/03_functions.sql`).

| Ação | Reputação | Onde é concedida |
|---|---|---|
| Concluir uma expedição | **+10** | `collect_expedition` |
| Cadastrar um abrigo | **+15** | `create_shelter` |
| Excluir um abrigo próprio | **−15** | `delete_shelter` (impede "farmar" criando e apagando) |
| Concluir uma troca (cada jogador) | **+20** | `accept_trade` |
| Ter um alerta confirmado por 2 jogadores | **+25** | `confirm_alert` (apenas uma vez por alerta) |

A reputação nunca fica negativa (`check (reputation >= 0)`).

---

## Facções

| Facção | Cor | Especialidade | Símbolo |
|---|---|---|---|
| **Bastião** | `#3A9A5B` Verde muralha | Abrigos | Muralha com portão |
| **Sentinela** | `#168AA0` Ciano rádio | Alertas de horda | Antena transmitindo |
| **Sucata** | `#D2602A` Ferrugem | Expedições | Chave inglesa |
| **Caravana** | `#B83A78` Amaranto | Trocas | Setas de troca |

Os emblemas estão em `assets/factions/` (emblema, versão para fundo escuro, símbolo e marcador do mapa). A coluna `factions.symbol` guarda o nome do arquivo.

**Kit inicial** (concedido pelo servidor em `choose_faction`): 3 garrafas de água, 3 comidas enlatadas, 1 kit de primeiros socorros, 1 lanterna e 1 gasolina.

**Expedições:**

| Destino | Duração | Risco | Chance de voltar sem nada |
|---|---|---|---|
| Mercado abandonado | 1 min | baixo | 0% |
| Posto de gasolina | 2 min | médio | 10% |
| Hospital | 3 min | alto | 25% |
| Loja de ferragens | 5 min | médio | 10% |

---

## Arquitetura (camadas)

```
lib/
├── core/          tema, cores da marca, env, erros amigáveis, relógio do servidor
├── models/        classes de dados com fromJson/toJson
├── repositories/  TODO acesso ao Supabase (e ao GPS)
├── providers/     estado (Riverpod) + GameActions (ações do jogo)
├── router/        GoRouter (rotas, shell, redirect)
├── screens/       telas (só interface)
└── widgets/       widgets reutilizáveis
```

**As telas nunca chamam o Supabase.** O fluxo é sempre:

```
Tela → GameActions (provider) → Repository → Supabase (RPC / select)
                    ↓
          ref.invalidate(...)  →  todas as telas afetadas se atualizam
```

O único lugar que conhece o `SupabaseClient` é `providers/repository_providers.dart`.

---

## Widgets personalizados

Todos estão em `lib/widgets/` e são usados em mais de uma tela:

| Widget | Onde é usado |
|---|---|
| `FactionBadge` / `FactionEmblem` | Central, Perfil, Ranking, detalhe do abrigo, escolha de facção, nova troca |
| `ItemTile` | Inventário, Expedições (recompensas), nova troca, detalhe da troca |
| `ShelterCard` | Lista do Mapa, Perfil ("Meus abrigos") |
| `TradeCard` | Trocas (recebidas e enviadas) |
| `HordeAlertBanner` | Banner em tempo real (qualquer aba), Central, Mapa |
| `CountdownTimer` | Central, Expedições, detalhe da troca (expiração) |
| `LocationPicker` | Cadastro de abrigo, alerta de horda |
| `AsyncValueView` / `EmptyState` / `ErrorState` | Todas as telas (carregando, vazio, erro, sem conexão) |
| `PlayerAvatar` | AppBar, Ranking, Perfil, nova troca |

---

## Gerenciamento de estado (Riverpod)

Escolhemos o **Riverpod** porque:

- os dados vêm quase todos do servidor, e o `FutureProvider` já trata *carregando / erro / dados*;
- `ref.invalidate(provider)` faz **todas** as telas que observam aquele dado recarregarem sozinhas;
- os providers dependem uns dos outros. Por exemplo, todos dependem de `currentUserIdProvider`, então trocar de conta limpa tudo automaticamente.

Principais providers (`lib/providers/game_providers.dart`):

- `currentProfileProvider`: perfil + facção (base do redirect);
- `inventoryProvider`, `activeExpeditionProvider`, `tradesProvider`, `activeAlertsProvider`, `sheltersProvider`;
- `survivorRankingProvider`, `factionRankingProvider`, `profileStatsProvider`.

**Depois de uma ação**, `GameActions` (`lib/providers/game_actions.dart`) invalida tudo que mudou. Exemplo: coletar uma expedição invalida expedição ativa, inventário, perfil, estatísticas e rankings. A Central, o Inventário, o Perfil e o Ranking se atualizam sem reiniciar o app.

**Tempo real** (`lib/providers/realtime_providers.dart`): o `realtimeSyncProvider` assina o Supabase Realtime em `horde_alerts` e `trades`.

- Novo alerta de outro jogador → banner animado no topo de **qualquer** aba.
- Nova proposta recebida → SnackBar "Nova proposta de troca recebida!" e contador na barra inferior.
- Proposta aceita pelo outro jogador → o inventário e a reputação de quem propôs atualizam sozinhos.

---

## Rotas (GoRouter) e redirect com 3 estados

Arquivo: `lib/router/app_router.dart`.

- **Barra inferior persistente** com `StatefulShellRoute.indexedStack`: Central, Mapa, Expedições, Inventário e Trocas.
- **Rotas com parâmetros:** `/abrigos/:id`, `/abrigos/:id/editar`, `/trocas/:id`, além de `/abrigos/novo?lat=&lng=` e `/alertas/novo?lat=&lng=`.
- Ranking e Perfil abrem pelo AppBar de todas as abas.
- O `refreshListenable` reavalia o redirect quando muda o login, o perfil ou o fim da splash.

```dart
if (!splashDone)            return '/splash';
if (uid == null)            return '/login';    // 1) não autenticado
if (!profile.hasFaction)    return '/faccao';   // 2) autenticado sem facção
if (rota de entrada)        return '/central';  // 3) cadastro completo
```

Toda rota interna passa por esse redirect, então ninguém acessa `/central`, `/trocas/:id` etc. sem login e facção.

---

## Segurança: RLS e RPC

### Privilégios (`02_rls.sql`)

Primeiro **todos** os privilégios do cliente são revogados. Depois só é concedido:

| Tabela | O cliente pode |
|---|---|
| `inventory` | **apenas SELECT** das próprias linhas |
| `profiles` | SELECT de todos; **UPDATE só de `nickname` e `avatar_url`** (`reputation` e `faction_id` ficam de fora) |
| `shelters` | SELECT (com RLS); UPDATE de colunas de conteúdo, só o autor |
| `expeditions`, `trades`, `trade_items`, `horde_alerts`, `alert_confirmations` | apenas SELECT |
| catálogos (`factions`, `items`, `expedition_types`, `expedition_rewards`) | apenas SELECT |

**RLS está ativada em todas as tabelas.**

| Policy | Regra |
|---|---|
| `inventory_select_own` | `user_id = auth.uid()` |
| `shelters_select` | público **ou** autor **ou** `faction_id = current_faction()`; abrigos "da facção" ficam invisíveis para as outras |
| `shelters_update_author` | só o autor edita |
| `trades_select_participant` | só quem enviou ou recebeu |
| `horde_alerts_select_active` | `expires_at > now()`; o alerta some depois de 30 min |
| Storage `pz_storage_*` | só grava em `avatars/<uid>/...` e `shelters/<uid>/...` |

### Restrições no banco (`01_schema.sql`)

- `inventory.quantity >= 0`: a quantidade nunca fica negativa.
- `unique (alert_id, user_id)` em `alert_confirmations`: ninguém confirma o mesmo alerta duas vezes.
- Índice único parcial `expeditions(user_id) where status = 'em_andamento'`: só uma expedição por vez.
- `check (from_user <> to_user)` em `trades`: ninguém troca consigo mesmo.

### Funções RPC (`03_functions.sql`)

Todas usam `auth.uid()` (o token do jogador), nunca um id enviado pelo app.

| RPC | O que garante |
|---|---|
| `choose_faction` | Escolha única e definitiva + kit inicial |
| `start_expedition` | Início e fim definidos por `now()` do servidor |
| `collect_expedition` | Só depois do fim; itens e quantidades sorteados com `random()` no banco |
| `create_shelter` / `delete_shelter` | Autor e facção definidos pelo servidor; reputação ±15 |
| `create_trade` | Não deixa propor para si mesmo; confere se o autor tem os itens |
| `accept_trade` / `reject_trade` / `cancel_trade` | Só o destinatário aceita/recusa; só o autor cancela; expira após 24 h |
| `report_horde` / `confirm_alert` | Não confirma o próprio alerta nem duas vezes; +25 ao chegar a 2 confirmações |
| `expire_trades` | Expira propostas pendentes (também roda a cada minuto via **pg_cron**) |

As funções auxiliares (`_add_item`, `_remove_item`, `_add_reputation`) **não** podem ser chamadas pelo app (`revoke execute`).

---

## Troca atômica

`accept_trade` roda inteira **numa única transação** do PostgreSQL:

1. `select ... for update` trava a proposta, o que impede dois aceites ao mesmo tempo.
2. Trava as linhas de inventário dos dois jogadores em ordem fixa, para evitar deadlock.
3. Retira **todos** os itens dos dois lados com `update ... where quantity >= q`. Se faltar qualquer item, `raise exception`.
4. Entrega os itens ao outro lado, marca a proposta como `aceita` e dá +20 de reputação para cada um.

Se o passo 3 falhar, o `raise exception` **desfaz tudo** (rollback): nenhum item muda e a proposta continua pendente. O teste automatizado confirma isso.

---

## Teste de trapaça

Com a chave pública e o token de um jogador logado, tente alterar o inventário direto pela API REST. O PowerShell pode ser usado no Windows:

```powershell
$URL   = "https://guewwoaocvenroujloch.supabase.co"
$ANON  = "<chave pública anon>"
$TOKEN = "<access_token do jogador>"   # ex.: Supabase.instance.client.auth.currentSession!.accessToken

# 1) Tentar dar 999 itens a si mesmo
curl.exe -X PATCH "$URL/rest/v1/inventory?item_id=eq.1" `
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" -d '{\"quantity\": 999}'
# -> {"code":"42501","message":"permission denied for table inventory"}

# 2) Tentar subir a própria reputação
curl.exe -X PATCH "$URL/rest/v1/profiles?id=eq.<SEU_USER_ID>" `
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" -d '{\"reputation\": 99999}'
# -> {"code":"42501","message":"permission denied for table profiles"}

# 3) Tentar chamar a função interna que dá itens
curl.exe -X POST "$URL/rest/v1/rpc/_add_item" `
  -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" -d '{\"p_user\":\"<SEU_USER_ID>\",\"p_item\":6,\"p_qty\":999}'
# -> permission denied for function _add_item
```

O script `supabase/tests/teste_seguranca.sql` faz esses e outros testes (40 verificações) direto no banco.

---

## Roteiro do desafio final

| # | Passo | Onde no app |
|---|---|---|
| 1 | A se cadastra, escolhe facção e recebe o kit | Cadastro → Escolha seu lado → Inventário |
| 2 | A cadastra abrigo "Só da facção" com foto e localização | Mapa → **+ Abrigo** |
| 3 | A inicia expedição, fecha/reabre o app, coleta | Expedições → Mercado abandonado (1 min) |
| 4 | B (outra facção) não vê o abrigo de A | Mapa de B |
| 5 | B emite alerta; aparece em A sem recarregar | Mapa de B → **Horda**; banner no topo do A |
| 6 | A propõe troca; aparece em tempo real para B; B aceita | Trocas → **Nova proposta** / detalhe → **Aceitar** |
| 7 | Teste de trapaça | Seção acima |
| 8 | Rankings e perfil atualizados | AppBar → Ranking / Perfil |
| 9 | Logout e login: dados mantidos | Perfil → **Sair** |
