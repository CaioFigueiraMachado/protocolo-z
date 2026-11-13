-- =====================================================================
-- Protocolo Z - 04: Storage, Realtime e agendamento
-- =====================================================================

-- ---------------------------------------------------------------------
-- Storage: buckets públicos para leitura; escrita só na própria pasta
--   avatars/<uid>/arquivo.jpg
--   shelters/<uid>/arquivo.jpg
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',  'avatars',  true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('shelters', 'shelters', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "pz_storage_select_own" on storage.objects;
create policy "pz_storage_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('avatars','shelters')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "pz_storage_insert_own" on storage.objects;
create policy "pz_storage_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('avatars','shelters')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "pz_storage_update_own" on storage.objects;
create policy "pz_storage_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('avatars','shelters')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('avatars','shelters')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "pz_storage_delete_own" on storage.objects;
create policy "pz_storage_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('avatars','shelters')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ---------------------------------------------------------------------
-- Realtime: alertas de horda e trocas (respeita a RLS de cada tabela)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'horde_alerts') then
    alter publication supabase_realtime add table public.horde_alerts;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'trades') then
    alter publication supabase_realtime add table public.trades;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- pg_cron: expira propostas pendentes a cada minuto (horário do servidor).
-- As RPCs de troca também verificam expires_at, então isto é um reforço.
-- ---------------------------------------------------------------------
create extension if not exists pg_cron;

select cron.unschedule('pz-expire-trades')
 where exists (select 1 from cron.job where jobname = 'pz-expire-trades');

select cron.schedule('pz-expire-trades', '* * * * *', $$select public.expire_trades()$$);
