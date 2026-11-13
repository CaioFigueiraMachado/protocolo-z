-- =====================================================================
-- Protocolo Z - 01: Tabelas e restrições
-- Execute os scripts na ordem: 01, 02, 03, 04, 05.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Facções
-- ---------------------------------------------------------------------
create table if not exists public.factions (
  id          smallint primary key,
  name        text not null unique,
  symbol      text not null,          -- slug do emblema (assets/factions/<symbol>.svg)
  color       text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  description text not null,
  motto       text not null default '',
  specialty   text not null default ''
);

-- ---------------------------------------------------------------------
-- Perfis (1:1 com auth.users, criado pela trigger handle_new_user)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nickname    text not null check (char_length(nickname) between 3 and 20),
  avatar_url  text,
  faction_id  smallint references public.factions(id),
  reputation  integer not null default 0 check (reputation >= 0),
  created_at  timestamptz not null default now()
);
create unique index if not exists profiles_nickname_unique on public.profiles (lower(nickname));
create index if not exists profiles_faction_idx on public.profiles (faction_id);

-- ---------------------------------------------------------------------
-- Catálogo de itens
-- ---------------------------------------------------------------------
create table if not exists public.items (
  id        smallint primary key,
  name      text not null unique,
  category  text not null check (category in ('agua','comida','medicamentos','ferramentas','combustivel')),
  icon      text not null
);

-- ---------------------------------------------------------------------
-- Inventário (só alterado por funções RPC)
-- ---------------------------------------------------------------------
create table if not exists public.inventory (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  item_id   smallint not null references public.items(id),
  quantity  integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- ---------------------------------------------------------------------
-- Abrigos
-- ---------------------------------------------------------------------
create table if not exists public.shelters (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references public.profiles(id) on delete cascade,
  faction_id  smallint not null references public.factions(id),
  name        text not null check (char_length(name) between 3 and 60),
  description text not null default '' check (char_length(description) <= 500),
  capacity    integer not null check (capacity between 1 and 500),
  photo_url   text,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  visibility  text not null default 'publico' check (visibility in ('publico','faccao')),
  status      text not null default 'seguro' check (status in ('seguro','comprometido')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists shelters_author_idx on public.shelters (author_id);
create index if not exists shelters_faction_idx on public.shelters (faction_id);

-- ---------------------------------------------------------------------
-- Expedições
-- ---------------------------------------------------------------------
create table if not exists public.expedition_types (
  id                smallint primary key,
  name              text not null unique,
  description       text not null,
  icon              text not null,
  duration_seconds  integer not null check (duration_seconds > 0),
  risk              text not null check (risk in ('baixo','medio','alto')),
  failure_chance    numeric(3,2) not null default 0 check (failure_chance between 0 and 1)
);

create table if not exists public.expedition_rewards (
  expedition_type_id smallint not null references public.expedition_types(id) on delete cascade,
  item_id            smallint not null references public.items(id),
  min_qty            integer not null check (min_qty >= 1),
  max_qty            integer not null,
  chance             numeric(3,2) not null check (chance > 0 and chance <= 1),
  primary key (expedition_type_id, item_id),
  check (max_qty >= min_qty)
);

create table if not exists public.expeditions (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  expedition_type_id smallint not null references public.expedition_types(id),
  started_at         timestamptz not null default now(),
  ends_at            timestamptz not null,
  status             text not null default 'em_andamento'
                     check (status in ('em_andamento','concluida','fracassada')),
  rewards            jsonb,
  collected_at       timestamptz,
  check (ends_at > started_at)
);
-- Apenas uma expedição em andamento por jogador.
create unique index if not exists expeditions_one_active
  on public.expeditions (user_id) where status = 'em_andamento';

-- ---------------------------------------------------------------------
-- Trocas
-- ---------------------------------------------------------------------
create table if not exists public.trades (
  id           uuid primary key default gen_random_uuid(),
  from_user    uuid not null references public.profiles(id) on delete cascade,
  to_user      uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pendente'
               check (status in ('pendente','aceita','recusada','cancelada','expirada')),
  message      text check (char_length(message) <= 200),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '24 hours'),
  resolved_at  timestamptz,
  check (from_user <> to_user)
);
create index if not exists trades_from_idx on public.trades (from_user, status);
create index if not exists trades_to_idx on public.trades (to_user, status);

create table if not exists public.trade_items (
  trade_id  uuid not null references public.trades(id) on delete cascade,
  item_id   smallint not null references public.items(id),
  side      text not null check (side in ('oferecido','pedido')),
  quantity  integer not null check (quantity > 0),
  primary key (trade_id, item_id, side)
);

-- ---------------------------------------------------------------------
-- Alertas de horda
-- ---------------------------------------------------------------------
create table if not exists public.horde_alerts (
  id             uuid primary key default gen_random_uuid(),
  author_id      uuid not null references public.profiles(id) on delete cascade,
  lat            double precision not null check (lat between -90 and 90),
  lng            double precision not null check (lng between -180 and 180),
  intensity      text not null check (intensity in ('baixa','media','alta')),
  description    text not null check (char_length(description) between 3 and 140),
  confirmations  integer not null default 0 check (confirmations >= 0),
  rewarded       boolean not null default false,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null default (now() + interval '30 minutes')
);
create index if not exists horde_alerts_expires_idx on public.horde_alerts (expires_at);

create table if not exists public.alert_confirmations (
  alert_id    uuid not null references public.horde_alerts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  -- Impede confirmar o mesmo alerta duas vezes.
  constraint alert_confirmations_unique unique (alert_id, user_id)
);
create index if not exists alert_confirmations_user_idx on public.alert_confirmations (user_id);
