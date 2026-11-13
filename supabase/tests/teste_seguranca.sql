-- =====================================================================
-- Protocolo Z - Teste automatizado de segurança e regras do jogo
--
-- Rode no SQL Editor do Supabase (como postgres). Ele:
--   1. cria dois jogadores de teste (A e B);
--   2. age como cada jogador (role authenticated + JWT simulado);
--   3. tenta trapacear e verifica se o banco recusa;
--   4. mostra um relatório OK/FALHOU;
--   5. NÃO deixa rastros: rode o bloco de limpeza no final.
-- =====================================================================

-- Executa um comando como o jogador indicado e registra o resultado.
create or replace function pg_temp.t(p_label text, p_user uuid, p_sql text, p_expect_ok boolean)
returns void
language plpgsql
as $$
declare
  v_ok boolean;
  v_msg text := '';
  v_prev text := current_user;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    execute p_sql;
    v_ok := true;
  exception when others then
    v_ok := false;
    v_msg := sqlerrm;
  end;
  perform set_config('role', v_prev, true);
  perform set_config('test.log',
    coalesce(current_setting('test.log', true), '') ||
    case when v_ok = p_expect_ok then 'OK      ' else 'FALHOU  ' end ||
    p_label || case when v_msg <> '' then '  ->  ' || v_msg else '' end || E'\n', true);
end;
$$;

create or replace function pg_temp.check(p_label text, p_cond boolean)
returns void
language plpgsql
as $$
begin
  perform set_config('test.log',
    coalesce(current_setting('test.log', true), '') ||
    case when p_cond then 'OK      ' else 'FALHOU  ' end || p_label || E'\n', true);
end;
$$;

-- Jogadores de teste
insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'teste_a@protocoloz.test', '{"nickname":"TesteA"}', now(), now()),
  ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'teste_b@protocoloz.test', '{"nickname":"TesteB"}', now(), now());

select pg_temp.check('Trigger criou os dois perfis',
  (select count(*) from public.profiles where id in
    ('aaaaaaaa-0000-0000-0000-00000000000a','bbbbbbbb-0000-0000-0000-00000000000b')) = 2);

-- ---------- Facção e kit inicial ----------
select pg_temp.t('A escolhe facção 1', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.choose_faction(1::smallint)', true);
select pg_temp.t('A tenta trocar de facção via RPC (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.choose_faction(2::smallint)', false);
select pg_temp.t('B escolhe facção 2', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.choose_faction(2::smallint)', true);
select pg_temp.check('A recebeu o kit inicial (5 itens)',
  (select count(*) from public.inventory where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 5);

-- ---------- TESTE DE TRAPAÇA ----------
select pg_temp.t('TRAPAÇA: UPDATE reputação direto (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'update public.profiles set reputation = 99999 where id = auth.uid()', false);
select pg_temp.t('TRAPAÇA: UPDATE facção direto (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'update public.profiles set faction_id = 2 where id = auth.uid()', false);
select pg_temp.t('TRAPAÇA: INSERT no inventário (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into public.inventory (user_id, item_id, quantity) values (auth.uid(), 6, 999)', false);
select pg_temp.t('TRAPAÇA: UPDATE no inventário (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'update public.inventory set quantity = 999 where user_id = auth.uid()', false);
select pg_temp.t('TRAPAÇA: DELETE no inventário (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'delete from public.inventory where user_id = auth.uid()', false);
select pg_temp.t('TRAPAÇA: chamar função interna _add_item (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public._add_item(auth.uid(), 6::smallint, 999)', false);
select pg_temp.t('TRAPAÇA: chamar _add_reputation (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public._add_reputation(auth.uid(), 999)', false);
select pg_temp.t('TRAPAÇA: inserir expedição já terminada (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into public.expeditions (user_id, expedition_type_id, started_at, ends_at) values (auth.uid(), 3, now() - interval ''1 hour'', now() - interval ''59 minutes'')', false);
select pg_temp.t('Apelido pode ser alterado (permitido)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'update public.profiles set nickname = ''TesteA2'' where id = auth.uid()', true);
select pg_temp.check('Reputação de A continua 0',
  (select reputation from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 0);

-- Quantidade negativa é barrada pela restrição CHECK (mesmo como admin)
do $$
begin
  begin
    update public.inventory set quantity = -1
     where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a' and item_id = 1;
    perform pg_temp.check('CHECK quantidade >= 0', false);
  exception when check_violation then
    perform pg_temp.check('CHECK quantidade >= 0 recusou valor negativo', true);
  end;
end $$;

-- ---------- Abrigos ----------
select pg_temp.t('A cadastra abrigo "da facção"', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.create_shelter(''Base Teste'', ''desc'', 10, null, -27.6, -48.5, ''faccao'')', true);
select pg_temp.check('A ganhou +15 de reputação',
  (select reputation from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 15);
select pg_temp.t('B NÃO enxerga abrigo da facção de A', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'do $x$ begin if (select count(*) from public.shelters where name = ''Base Teste'') <> 0 then raise exception ''vazou''; end if; end $x$', true);
select pg_temp.t('B tenta editar abrigo de A (0 linhas, não altera)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'do $x$ begin update public.shelters set name = ''Hackeado'' where name = ''Base Teste''; if found then raise exception ''alterou''; end if; end $x$', true);
select pg_temp.t('B tenta excluir abrigo de A (deve falhar)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.delete_shelter((select id from public.shelters where name = ''Base Teste''))', false);
select pg_temp.t('B tenta INSERT direto em shelters (deve falhar)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'insert into public.shelters (author_id, faction_id, name, capacity, lat, lng) values (auth.uid(), 1, ''Fake'', 5, 0, 0)', false);

-- ---------- Expedições ----------
select pg_temp.t('A inicia expedição', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.start_expedition(1::smallint)', true);
select pg_temp.t('A tenta 2ª expedição simultânea (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.start_expedition(2::smallint)', false);
select pg_temp.t('A tenta coletar antes do tempo (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.collect_expedition((select id from public.expeditions where user_id = auth.uid() and status = ''em_andamento''))', false);
-- Simula o tempo passando (como admin)
update public.expeditions set started_at = now() - interval '2 minutes', ends_at = now() - interval '1 minute'
 where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a' and status = 'em_andamento';
select pg_temp.t('A coleta após o tempo', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.collect_expedition((select id from public.expeditions where user_id = auth.uid() and status = ''em_andamento''))', true);
select pg_temp.check('A ganhou +10 (total 25)',
  (select reputation from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a') = 25);

-- ---------- Alertas ----------
select pg_temp.t('B emite alerta de horda', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.report_horde(-27.6, -48.5, ''alta'', ''Horda grande na ponte'')', true);
select pg_temp.t('B tenta confirmar o próprio alerta (deve falhar)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.confirm_alert((select id from public.horde_alerts where author_id = auth.uid() limit 1))', false);
select pg_temp.t('A confirma alerta de B', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.confirm_alert((select id from public.horde_alerts where description = ''Horda grande na ponte''))', true);
select pg_temp.t('A tenta confirmar 2x (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.confirm_alert((select id from public.horde_alerts where description = ''Horda grande na ponte''))', false);

-- ---------- Trocas ----------
select pg_temp.t('A propõe troca para si mesmo (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.create_trade(auth.uid(), ''[{"item_id":1,"quantity":1}]'', ''[{"item_id":3,"quantity":1}]'')', false);
select pg_temp.t('A propõe 1 água por 1 comida a B', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.create_trade(''bbbbbbbb-0000-0000-0000-00000000000b'', ''[{"item_id":1,"quantity":1}]'', ''[{"item_id":3,"quantity":1}]'')', true);
select pg_temp.t('A tenta aceitar a própria proposta (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.accept_trade((select id from public.trades where from_user = auth.uid() and status = ''pendente'' limit 1))', false);
select pg_temp.t('B aceita a troca', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.accept_trade((select id from public.trades where to_user = auth.uid() and status = ''pendente'' limit 1))', true);
select pg_temp.check('Inventários trocados (A: 2 águas e 4 comidas+, B: 4 águas e 2 comidas)',
  (select quantity from public.inventory where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b' and item_id = 1) = 4
  and (select quantity from public.inventory where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b' and item_id = 3) = 2);
select pg_temp.check('Os dois ganharam +20 (B = 20)',
  (select reputation from public.profiles where id = 'bbbbbbbb-0000-0000-0000-00000000000b') = 20);

-- Atomicidade: A oferece 1 lanterna, mas perde a lanterna antes do aceite
select pg_temp.t('A propõe 1 lanterna por 1 gasolina', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'select public.create_trade(''bbbbbbbb-0000-0000-0000-00000000000b'', ''[{"item_id":7,"quantity":1}]'', ''[{"item_id":9,"quantity":1}]'')', true);
update public.inventory set quantity = 0
 where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a' and item_id = 7;
select pg_temp.t('B aceita, mas A não tem mais o item (deve falhar)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'select public.accept_trade((select id from public.trades where to_user = auth.uid() and status = ''pendente'' limit 1))', false);
select pg_temp.check('Atomicidade: gasolina de B intacta (1) e troca ainda pendente',
  (select quantity from public.inventory where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b' and item_id = 9) = 1
  and exists (select 1 from public.trades where from_user = 'aaaaaaaa-0000-0000-0000-00000000000a' and status = 'pendente'));

-- ---------- Relatório ----------
select current_setting('test.log', true) as relatorio;

-- ---------- Limpeza (rode separadamente depois) ----------
-- delete from auth.users where email in ('teste_a@protocoloz.test', 'teste_b@protocoloz.test');
