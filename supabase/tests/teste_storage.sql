-- =====================================================================
-- Protocolo Z - Teste das regras do Storage (fotos de abrigos e avatares)
--
-- Rode no SQL Editor do Supabase. Ele cria dois jogadores de teste,
-- tenta gravar/editar/apagar arquivos como cada um e, no final, mostra
-- o relatório como uma MENSAGEM DE ERRO de propósito: o erro desfaz a
-- transação inteira, então nenhum usuário ou arquivo de teste fica no banco.
--
-- Regra testada: cada jogador só grava na própria pasta
--   avatars/<id do usuário>/...   e   shelters/<id do usuário>/...
-- =====================================================================

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

insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'storage_a@protocoloz.test', '{"nickname":"StorageA"}', now(), now()),
  ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'storage_b@protocoloz.test', '{"nickname":"StorageB"}', now(), now());

-- ---------- Configuração dos buckets ----------
select pg_temp.check('Buckets avatars e shelters existem e são públicos para leitura',
  (select count(*) from storage.buckets where id in ('avatars','shelters') and public) = 2);
select pg_temp.check('Limite de 5 MB por arquivo',
  (select bool_and(file_size_limit = 5242880) from storage.buckets where id in ('avatars','shelters')));
select pg_temp.check('Só aceita imagens (jpeg, png, webp)',
  (select bool_and(allowed_mime_types @> array['image/jpeg','image/png','image/webp']
                   and array_length(allowed_mime_types, 1) = 3)
     from storage.buckets where id in ('avatars','shelters')));

-- ---------- Gravação ----------
select pg_temp.t('A envia avatar na própria pasta', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into storage.objects (bucket_id, name) values (''avatars'', ''aaaaaaaa-0000-0000-0000-00000000000a/avatar.jpg'')', true);
select pg_temp.t('A envia foto de abrigo na própria pasta', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into storage.objects (bucket_id, name) values (''shelters'', ''aaaaaaaa-0000-0000-0000-00000000000a/abrigo.jpg'')', true);
select pg_temp.t('TRAPAÇA: A grava avatar na pasta de B (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into storage.objects (bucket_id, name) values (''avatars'', ''bbbbbbbb-0000-0000-0000-00000000000b/hack.jpg'')', false);
select pg_temp.t('TRAPAÇA: A grava foto de abrigo na pasta de B (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into storage.objects (bucket_id, name) values (''shelters'', ''bbbbbbbb-0000-0000-0000-00000000000b/hack.jpg'')', false);
select pg_temp.t('TRAPAÇA: A grava na raiz do bucket, fora de qualquer pasta (deve falhar)', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'insert into storage.objects (bucket_id, name) values (''avatars'', ''solto.jpg'')', false);
select pg_temp.t('TRAPAÇA: B grava na pasta de A (deve falhar)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'insert into storage.objects (bucket_id, name) values (''avatars'', ''aaaaaaaa-0000-0000-0000-00000000000a/troca.jpg'')', false);

-- ---------- Edição e exclusão de arquivos alheios ----------
select pg_temp.t('TRAPAÇA: B tenta sobrescrever o avatar de A (0 linhas alteradas)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'do $x$ begin
     update storage.objects set name = ''bbbbbbbb-0000-0000-0000-00000000000b/roubado.jpg''
      where bucket_id = ''avatars'' and name = ''aaaaaaaa-0000-0000-0000-00000000000a/avatar.jpg'';
     if found then raise exception ''alterou o arquivo de outro jogador''; end if;
   end $x$', true);
-- O Supabase bloqueia DELETE direto por SQL em storage.objects (só pela Storage API).
-- Pela API, a policy pz_storage_delete_own só deixa apagar arquivos da própria pasta.
select pg_temp.t('TRAPAÇA: B tenta apagar o avatar de A (bloqueado)', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'delete from storage.objects where bucket_id = ''avatars'' and name = ''aaaaaaaa-0000-0000-0000-00000000000a/avatar.jpg''', false);
select pg_temp.check('Policy de exclusão só permite a própria pasta',
  exists (select 1 from pg_policies
           where schemaname = 'storage' and tablename = 'objects'
             and policyname = 'pz_storage_delete_own' and cmd = 'DELETE'
             and qual like '%foldername%' and qual like '%auth.uid()%'));
select pg_temp.check('Avatar de A continua no lugar depois das tentativas de B',
  exists (select 1 from storage.objects
           where bucket_id = 'avatars' and name = 'aaaaaaaa-0000-0000-0000-00000000000a/avatar.jpg'));
select pg_temp.t('B não lista os arquivos de A pela API', 'bbbbbbbb-0000-0000-0000-00000000000b',
  'do $x$ begin
     if exists (select 1 from storage.objects where name like ''aaaaaaaa-0000-0000-0000-00000000000a/%'') then
       raise exception ''B consegue listar arquivos de A'';
     end if;
   end $x$', true);
select pg_temp.t('A edita o próprio arquivo', 'aaaaaaaa-0000-0000-0000-00000000000a',
  'do $x$ begin
     update storage.objects set metadata = ''{"teste": true}''
      where bucket_id = ''avatars'' and name = ''aaaaaaaa-0000-0000-0000-00000000000a/avatar.jpg'';
     if not found then raise exception ''não conseguiu editar o próprio arquivo''; end if;
   end $x$', true);

-- ---------- Relatório (como erro, para desfazer tudo) ----------
do $$
begin
  raise exception E'RELATÓRIO (nada foi gravado no banco)\n%', current_setting('test.log', true);
end $$;
