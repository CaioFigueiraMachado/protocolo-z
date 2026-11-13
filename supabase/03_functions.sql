-- =====================================================================
-- Protocolo Z - 03: Triggers, funções internas e RPCs
--
-- Todas as ações que alteram inventário ou reputação passam por aqui.
-- As funções são SECURITY DEFINER: rodam com permissão do dono, mas
-- sempre usam auth.uid() (token do jogador), nunca um id vindo do cliente.
-- Cada chamada RPC roda em UMA transação: se qualquer passo falhar
-- (raise exception), tudo é desfeito.
--
-- Tabela de reputação (constantes abaixo):
--   Concluir expedição ............ +10
--   Cadastrar abrigo .............. +15  (excluir abrigo devolve -15)
--   Concluir troca (cada jogador) . +20
--   Alerta confirmado por 2 ....... +25
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger: cria o perfil automaticamente no cadastro
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nick text;
  v_suffix text := substr(replace(new.id::text, '-', ''), 1, 4);
begin
  v_nick := nullif(trim(new.raw_user_meta_data ->> 'nickname'), '');
  if v_nick is null or char_length(v_nick) < 3 then
    v_nick := 'sobrevivente_' || v_suffix;
  end if;
  v_nick := left(v_nick, 20);

  -- Se o apelido já existir, acrescenta um sufixo para não quebrar o cadastro.
  if exists (select 1 from public.profiles where lower(nickname) = lower(v_nick)) then
    v_nick := left(v_nick, 15) || '_' || v_suffix;
  end if;

  insert into public.profiles (id, nickname) values (new.id, v_nick);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Trigger: updated_at dos abrigos
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists shelters_touch on public.shelters;
create trigger shelters_touch
  before update on public.shelters
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Funções internas (NÃO expostas ao cliente)
-- ---------------------------------------------------------------------
create or replace function public._require_player()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sessão expirada. Entre novamente.';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and faction_id is not null) then
    raise exception 'Escolha uma facção antes de continuar.';
  end if;
  return v_uid;
end;
$$;

create or replace function public._add_reputation(p_user uuid, p_amount integer)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
     set reputation = greatest(0, reputation + p_amount)
   where id = p_user;
$$;

create or replace function public._add_item(p_user uuid, p_item smallint, p_qty integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_qty <= 0 then
    return;
  end if;
  insert into public.inventory (user_id, item_id, quantity)
  values (p_user, p_item, p_qty)
  on conflict (user_id, item_id)
  do update set quantity = public.inventory.quantity + excluded.quantity,
                updated_at = now();
end;
$$;

create or replace function public._remove_item(p_user uuid, p_item smallint, p_qty integer, p_error text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.inventory
     set quantity = quantity - p_qty,
         updated_at = now()
   where user_id = p_user
     and item_id = p_item
     and quantity >= p_qty;
  if not found then
    raise exception '%', p_error;
  end if;
end;
$$;

-- Converte [{"item_id":1,"quantity":2}, ...] em linhas agregadas e validadas.
create or replace function public._parse_items(p_items jsonb)
returns table (item_id smallint, quantity integer)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) e
    where coalesce((e ->> 'quantity')::integer, 0) <= 0
  ) then
    raise exception 'As quantidades devem ser maiores que zero.';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) e
    where not exists (select 1 from public.items i where i.id = (e ->> 'item_id')::smallint)
  ) then
    raise exception 'Item inválido na proposta.';
  end if;
  return query
    select (e ->> 'item_id')::smallint, sum((e ->> 'quantity')::integer)::integer
      from jsonb_array_elements(p_items) e
     group by 1;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: apelido disponível? (usado na tela de cadastro, antes de logar)
-- ---------------------------------------------------------------------
create or replace function public.nickname_available(p_nickname text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles where lower(nickname) = lower(trim(p_nickname))
  );
$$;

-- ---------------------------------------------------------------------
-- RPC: escolher facção (definitivo) + kit inicial
-- ---------------------------------------------------------------------
create or replace function public.choose_faction(p_faction_id smallint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_current smallint;
begin
  if v_uid is null then
    raise exception 'Sessão expirada. Entre novamente.';
  end if;

  select faction_id into v_current
    from public.profiles where id = v_uid
    for update;

  if not found then
    raise exception 'Perfil não encontrado.';
  end if;
  if v_current is not null then
    raise exception 'Você já escolheu uma facção. A escolha é definitiva.';
  end if;
  if not exists (select 1 from public.factions where id = p_faction_id) then
    raise exception 'Facção inválida.';
  end if;

  update public.profiles set faction_id = p_faction_id where id = v_uid;

  -- Kit inicial concedido pelo servidor
  perform public._add_item(v_uid, k.item_id, k.qty)
     from (values (1::smallint, 3), (3::smallint, 3), (5::smallint, 1),
                  (7::smallint, 1), (9::smallint, 1)) as k(item_id, qty);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: abrigos
-- ---------------------------------------------------------------------
create or replace function public.create_shelter(
  p_name text,
  p_description text,
  p_capacity integer,
  p_photo_url text,
  p_lat double precision,
  p_lng double precision,
  p_visibility text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_id uuid;
begin
  insert into public.shelters
    (author_id, faction_id, name, description, capacity, photo_url, lat, lng, visibility)
  values
    (v_uid, public.current_faction(), trim(p_name), coalesce(trim(p_description), ''),
     p_capacity, p_photo_url, p_lat, p_lng, p_visibility)
  returning id into v_id;

  perform public._add_reputation(v_uid, 15);
  return v_id;
end;
$$;

create or replace function public.delete_shelter(p_shelter_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
begin
  delete from public.shelters
   where id = p_shelter_id and author_id = v_uid;
  if not found then
    raise exception 'Apenas o autor pode excluir este abrigo.';
  end if;
  -- Evita "farmar" reputação criando e apagando abrigos.
  perform public._add_reputation(v_uid, -15);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: expedições (tempo e sorteio no servidor)
-- ---------------------------------------------------------------------
create or replace function public.start_expedition(p_type_id smallint)
returns public.expeditions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_type public.expedition_types;
  v_row public.expeditions;
begin
  select * into v_type from public.expedition_types where id = p_type_id;
  if not found then
    raise exception 'Tipo de expedição inválido.';
  end if;

  if exists (select 1 from public.expeditions where user_id = v_uid and status = 'em_andamento') then
    raise exception 'Você já tem uma expedição em andamento.';
  end if;

  insert into public.expeditions (user_id, expedition_type_id, started_at, ends_at)
  values (v_uid, p_type_id, now(), now() + make_interval(secs => v_type.duration_seconds))
  returning * into v_row;

  return v_row;
exception
  when unique_violation then
    raise exception 'Você já tem uma expedição em andamento.';
end;
$$;

create or replace function public.collect_expedition(p_expedition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_exp public.expeditions;
  v_type public.expedition_types;
  v_reward record;
  v_qty integer;
  v_items jsonb := '[]'::jsonb;
begin
  select * into v_exp
    from public.expeditions
   where id = p_expedition_id and user_id = v_uid
   for update;

  if not found then
    raise exception 'Expedição não encontrada.';
  end if;
  if v_exp.status <> 'em_andamento' then
    raise exception 'Esta expedição já foi finalizada.';
  end if;
  if now() < v_exp.ends_at then
    raise exception 'A expedição ainda não terminou.';
  end if;

  select * into v_type from public.expedition_types where id = v_exp.expedition_type_id;

  -- Risco: chance de o sobrevivente voltar de mãos vazias.
  if random() < v_type.failure_chance then
    update public.expeditions
       set status = 'fracassada', rewards = '[]'::jsonb, collected_at = now()
     where id = v_exp.id;
    return jsonb_build_object('success', false, 'reputation', 0, 'items', '[]'::jsonb);
  end if;

  for v_reward in
    select r.*, i.name, i.icon
      from public.expedition_rewards r
      join public.items i on i.id = r.item_id
     where r.expedition_type_id = v_type.id
     order by r.chance desc
  loop
    if random() < v_reward.chance then
      v_qty := v_reward.min_qty + floor(random() * (v_reward.max_qty - v_reward.min_qty + 1))::integer;
      perform public._add_item(v_uid, v_reward.item_id, v_qty);
      v_items := v_items || jsonb_build_object(
        'item_id', v_reward.item_id, 'name', v_reward.name,
        'icon', v_reward.icon, 'quantity', v_qty);
    end if;
  end loop;

  -- Garante pelo menos um item em caso de sucesso.
  if jsonb_array_length(v_items) = 0 then
    select r.item_id, r.min_qty, i.name, i.icon into v_reward
      from public.expedition_rewards r
      join public.items i on i.id = r.item_id
     where r.expedition_type_id = v_type.id
     order by r.chance desc
     limit 1;
    if found then
      perform public._add_item(v_uid, v_reward.item_id, v_reward.min_qty);
      v_items := jsonb_build_array(jsonb_build_object(
        'item_id', v_reward.item_id, 'name', v_reward.name,
        'icon', v_reward.icon, 'quantity', v_reward.min_qty));
    end if;
  end if;

  update public.expeditions
     set status = 'concluida', rewards = v_items, collected_at = now()
   where id = v_exp.id;

  perform public._add_reputation(v_uid, 10);

  return jsonb_build_object('success', true, 'reputation', 10, 'items', v_items);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: trocas
-- ---------------------------------------------------------------------
create or replace function public.expire_trades()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.trades
     set status = 'expirada', resolved_at = now()
   where status = 'pendente' and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.create_trade(
  p_to_user uuid,
  p_offered jsonb,
  p_requested jsonb,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_trade_id uuid;
  v_item record;
begin
  if p_to_user = v_uid then
    raise exception 'Você não pode propor uma troca para si mesmo.';
  end if;
  if not exists (select 1 from public.profiles where id = p_to_user and faction_id is not null) then
    raise exception 'Jogador de destino não encontrado.';
  end if;

  create temp table if not exists _offered (item_id smallint, quantity integer) on commit drop;
  create temp table if not exists _requested (item_id smallint, quantity integer) on commit drop;
  truncate _offered; truncate _requested;
  insert into _offered select * from public._parse_items(p_offered);
  insert into _requested select * from public._parse_items(p_requested);

  if not exists (select 1 from _offered) or not exists (select 1 from _requested) then
    raise exception 'Escolha pelo menos um item oferecido e um item pedido.';
  end if;

  -- Confere (já na criação) se o autor tem o que está oferecendo.
  for v_item in select * from _offered loop
    if not exists (
      select 1 from public.inventory
       where user_id = v_uid and item_id = v_item.item_id and quantity >= v_item.quantity
    ) then
      raise exception 'Você não possui itens suficientes para oferecer.';
    end if;
  end loop;

  if (select count(*) from public.trades where from_user = v_uid and status = 'pendente') >= 10 then
    raise exception 'Você já tem 10 propostas pendentes. Aguarde respostas ou cancele alguma.';
  end if;

  insert into public.trades (from_user, to_user, message)
  values (v_uid, p_to_user, nullif(trim(p_message), ''))
  returning id into v_trade_id;

  insert into public.trade_items (trade_id, item_id, side, quantity)
  select v_trade_id, item_id, 'oferecido', quantity from _offered
  union all
  select v_trade_id, item_id, 'pedido', quantity from _requested;

  return v_trade_id;
end;
$$;

-- Aceite ATÔMICO: tudo acontece numa única transação. Se qualquer
-- _remove_item falhar, o raise desfaz todas as alterações anteriores.
create or replace function public.accept_trade(p_trade_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_trade public.trades;
  v_item record;
begin
  -- Trava a proposta: impede dois aceites simultâneos.
  select * into v_trade from public.trades where id = p_trade_id for update;

  if not found or v_trade.to_user <> v_uid then
    raise exception 'Apenas o destinatário pode aceitar esta proposta.';
  end if;
  if v_trade.status <> 'pendente' then
    raise exception 'Esta proposta não está mais pendente.';
  end if;
  if v_trade.expires_at <= now() then
    update public.trades set status = 'expirada', resolved_at = now() where id = v_trade.id;
    return 'expirada';
  end if;

  -- Trava as linhas de inventário dos dois jogadores em ordem fixa (evita deadlock).
  perform 1 from public.inventory
   where user_id in (v_trade.from_user, v_trade.to_user)
   order by user_id, item_id
   for update;

  -- 1) Retira os itens de cada lado (falha se faltar qualquer item)
  for v_item in select * from public.trade_items where trade_id = v_trade.id loop
    if v_item.side = 'oferecido' then
      perform public._remove_item(v_trade.from_user, v_item.item_id, v_item.quantity,
        'O autor da proposta não possui mais os itens oferecidos.');
    else
      perform public._remove_item(v_trade.to_user, v_item.item_id, v_item.quantity,
        'Você não possui mais esses itens.');
    end if;
  end loop;

  -- 2) Entrega os itens ao outro lado
  for v_item in select * from public.trade_items where trade_id = v_trade.id loop
    if v_item.side = 'oferecido' then
      perform public._add_item(v_trade.to_user, v_item.item_id, v_item.quantity);
    else
      perform public._add_item(v_trade.from_user, v_item.item_id, v_item.quantity);
    end if;
  end loop;

  update public.trades set status = 'aceita', resolved_at = now() where id = v_trade.id;

  perform public._add_reputation(v_trade.from_user, 20);
  perform public._add_reputation(v_trade.to_user, 20);

  return 'aceita';
end;
$$;

create or replace function public.reject_trade(p_trade_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_trade public.trades;
begin
  select * into v_trade from public.trades where id = p_trade_id for update;
  if not found or v_trade.to_user <> v_uid then
    raise exception 'Apenas o destinatário pode recusar esta proposta.';
  end if;
  if v_trade.status <> 'pendente' then
    raise exception 'Esta proposta não está mais pendente.';
  end if;
  if v_trade.expires_at <= now() then
    update public.trades set status = 'expirada', resolved_at = now() where id = v_trade.id;
    return 'expirada';
  end if;
  update public.trades set status = 'recusada', resolved_at = now() where id = v_trade.id;
  return 'recusada';
end;
$$;

create or replace function public.cancel_trade(p_trade_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_trade public.trades;
begin
  select * into v_trade from public.trades where id = p_trade_id for update;
  if not found or v_trade.from_user <> v_uid then
    raise exception 'Apenas o autor pode cancelar esta proposta.';
  end if;
  if v_trade.status <> 'pendente' then
    raise exception 'Esta proposta não está mais pendente.';
  end if;
  if v_trade.expires_at <= now() then
    update public.trades set status = 'expirada', resolved_at = now() where id = v_trade.id;
    return 'expirada';
  end if;
  update public.trades set status = 'cancelada', resolved_at = now() where id = v_trade.id;
  return 'cancelada';
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: alertas de horda
-- ---------------------------------------------------------------------
create or replace function public.report_horde(
  p_lat double precision,
  p_lng double precision,
  p_intensity text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_id uuid;
begin
  if exists (
    select 1 from public.horde_alerts
     where author_id = v_uid and created_at > now() - interval '1 minute'
  ) then
    raise exception 'Aguarde um minuto antes de emitir outro alerta.';
  end if;

  insert into public.horde_alerts (author_id, lat, lng, intensity, description)
  values (v_uid, p_lat, p_lng, p_intensity, trim(p_description))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.confirm_alert(p_alert_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_player();
  v_alert public.horde_alerts;
  v_rewarded_now boolean := false;
begin
  select * into v_alert from public.horde_alerts where id = p_alert_id for update;
  if not found or v_alert.expires_at <= now() then
    raise exception 'Este alerta não está mais ativo.';
  end if;
  if v_alert.author_id = v_uid then
    raise exception 'Você não pode confirmar o próprio alerta.';
  end if;

  begin
    insert into public.alert_confirmations (alert_id, user_id) values (p_alert_id, v_uid);
  exception when unique_violation then
    raise exception 'Você já confirmou este alerta.';
  end;

  update public.horde_alerts
     set confirmations = confirmations + 1
   where id = p_alert_id
  returning * into v_alert;

  if v_alert.confirmations >= 2 and not v_alert.rewarded then
    update public.horde_alerts set rewarded = true where id = p_alert_id;
    perform public._add_reputation(v_alert.author_id, 25);
    v_rewarded_now := true;
  end if;

  return jsonb_build_object('confirmations', v_alert.confirmations, 'author_rewarded', v_rewarded_now);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: estatísticas do perfil
-- ---------------------------------------------------------------------
create or replace function public.get_profile_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'expeditions_completed',
      (select count(*) from public.expeditions where user_id = auth.uid() and status = 'concluida'),
    'trades_completed',
      (select count(*) from public.trades
        where status = 'aceita' and (from_user = auth.uid() or to_user = auth.uid())),
    'shelters_created',
      (select count(*) from public.shelters where author_id = auth.uid()),
    'alerts_confirmed',
      (select count(*) from public.alert_confirmations where user_id = auth.uid())
  );
$$;

-- ---------------------------------------------------------------------
-- RPC: horário do servidor (o app usa para sincronizar as contagens)
-- ---------------------------------------------------------------------
create or replace function public.server_now()
returns timestamptz
language sql
stable
set search_path = public
as $$ select now(); $$;

-- ---------------------------------------------------------------------
-- Rankings (views calculadas a partir dos dados persistidos)
-- ---------------------------------------------------------------------
create or replace view public.survivor_ranking
with (security_invoker = true) as
  select rank() over (order by p.reputation desc) as position,
         p.id, p.nickname, p.avatar_url, p.reputation, p.faction_id
    from public.profiles p
   where p.faction_id is not null;

create or replace view public.faction_ranking
with (security_invoker = true) as
  select f.id, f.name, f.symbol, f.color,
         coalesce(sum(p.reputation), 0)::integer as total_reputation,
         count(p.id)::integer as members
    from public.factions f
    left join public.profiles p on p.faction_id = f.id
   group by f.id
   order by total_reputation desc;

grant select on public.survivor_ranking, public.faction_ranking to authenticated;

-- ---------------------------------------------------------------------
-- Permissões de execução
-- ---------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.nickname_available(text) to anon, authenticated;
grant execute on function public.current_faction() to authenticated;
grant execute on function public.choose_faction(smallint) to authenticated;
grant execute on function public.create_shelter(text, text, integer, text, double precision, double precision, text) to authenticated;
grant execute on function public.delete_shelter(uuid) to authenticated;
grant execute on function public.start_expedition(smallint) to authenticated;
grant execute on function public.collect_expedition(uuid) to authenticated;
grant execute on function public.expire_trades() to authenticated;
grant execute on function public.create_trade(uuid, jsonb, jsonb, text) to authenticated;
grant execute on function public.accept_trade(uuid) to authenticated;
grant execute on function public.reject_trade(uuid) to authenticated;
grant execute on function public.cancel_trade(uuid) to authenticated;
grant execute on function public.report_horde(double precision, double precision, text, text) to authenticated;
grant execute on function public.confirm_alert(uuid) to authenticated;
grant execute on function public.get_profile_stats() to authenticated;
grant execute on function public.server_now() to authenticated;
