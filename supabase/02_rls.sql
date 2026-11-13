-- =====================================================================
-- Protocolo Z - 02: Privilégios e Row Level Security
--
-- Ideia central: o app cliente NÃO é confiável.
--  * O cliente só recebe SELECT nas tabelas e UPDATE em colunas inofensivas.
--  * Inventário, reputação, facção, expedições, trocas e alertas só mudam
--    via funções RPC (security definer) definidas em 03_functions.sql.
-- =====================================================================

-- Função auxiliar: facção do usuário autenticado (usada nas policies).
create or replace function public.current_faction()
returns smallint
language sql
stable
security definer
set search_path = public
as $$
  select faction_id from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- 1) Remove todos os privilégios padrão e concede apenas o necessário
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;

grant select on public.factions, public.items,
                public.expedition_types, public.expedition_rewards
  to authenticated;

grant select on public.profiles to authenticated;
-- Apenas apelido e avatar podem ser alterados pelo próprio jogador.
-- reputation e faction_id NÃO estão na lista: o banco recusa o UPDATE.
grant update (nickname, avatar_url) on public.profiles to authenticated;

grant select on public.inventory to authenticated;           -- sem insert/update/delete

grant select on public.shelters to authenticated;
grant update (name, description, capacity, photo_url, lat, lng, visibility, status)
  on public.shelters to authenticated;                        -- criar/excluir só via RPC

grant select on public.expeditions to authenticated;
grant select on public.trades, public.trade_items to authenticated;
grant select on public.horde_alerts, public.alert_confirmations to authenticated;

-- ---------------------------------------------------------------------
-- 2) RLS ativada em TODAS as tabelas
-- ---------------------------------------------------------------------
alter table public.factions            enable row level security;
alter table public.profiles            enable row level security;
alter table public.items               enable row level security;
alter table public.inventory           enable row level security;
alter table public.shelters            enable row level security;
alter table public.expedition_types    enable row level security;
alter table public.expedition_rewards  enable row level security;
alter table public.expeditions         enable row level security;
alter table public.trades              enable row level security;
alter table public.trade_items         enable row level security;
alter table public.horde_alerts        enable row level security;
alter table public.alert_confirmations enable row level security;

-- Catálogos: leitura para qualquer jogador autenticado
drop policy if exists "factions_select" on public.factions;
create policy "factions_select" on public.factions
  for select to authenticated using (true);

drop policy if exists "items_select" on public.items;
create policy "items_select" on public.items
  for select to authenticated using (true);

drop policy if exists "expedition_types_select" on public.expedition_types;
create policy "expedition_types_select" on public.expedition_types
  for select to authenticated using (true);

drop policy if exists "expedition_rewards_select" on public.expedition_rewards;
create policy "expedition_rewards_select" on public.expedition_rewards
  for select to authenticated using (true);

-- Perfis: todos leem (ranking, trocas); cada um edita só o próprio
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Inventário: cada um vê apenas o próprio
drop policy if exists "inventory_select_own" on public.inventory;
create policy "inventory_select_own" on public.inventory
  for select to authenticated using (user_id = (select auth.uid()));

-- Abrigos: públicos para todos; "da facção" só para a mesma facção
drop policy if exists "shelters_select" on public.shelters;
create policy "shelters_select" on public.shelters
  for select to authenticated
  using (
    visibility = 'publico'
    or author_id = (select auth.uid())
    or faction_id = (select public.current_faction())
  );

drop policy if exists "shelters_update_author" on public.shelters;
create policy "shelters_update_author" on public.shelters
  for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

-- Expedições: só as próprias
drop policy if exists "expeditions_select_own" on public.expeditions;
create policy "expeditions_select_own" on public.expeditions
  for select to authenticated using (user_id = (select auth.uid()));

-- Trocas: só quem enviou ou recebeu
drop policy if exists "trades_select_participant" on public.trades;
create policy "trades_select_participant" on public.trades
  for select to authenticated
  using (from_user = (select auth.uid()) or to_user = (select auth.uid()));

drop policy if exists "trade_items_select_participant" on public.trade_items;
create policy "trade_items_select_participant" on public.trade_items
  for select to authenticated
  using (exists (
    select 1 from public.trades t
    where t.id = trade_id
      and (t.from_user = (select auth.uid()) or t.to_user = (select auth.uid()))
  ));

-- Alertas: todos veem os ativos (não expirados)
drop policy if exists "horde_alerts_select_active" on public.horde_alerts;
create policy "horde_alerts_select_active" on public.horde_alerts
  for select to authenticated using (expires_at > now());

drop policy if exists "alert_confirmations_select_own" on public.alert_confirmations;
create policy "alert_confirmations_select_own" on public.alert_confirmations
  for select to authenticated using (user_id = (select auth.uid()));
