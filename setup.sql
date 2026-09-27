-- Surgical Logbook production migration for the existing Supabase project.
-- Run in Supabase SQL Editor. Safe to run more than once.

create extension if not exists pgcrypto;

alter table public.cases add column if not exists id uuid default gen_random_uuid();
alter table public.cases add column if not exists case_number text;
alter table public.cases add column if not exists operative_steps text;
alter table public.cases add column if not exists conversion_reexploration text;
alter table public.cases add column if not exists case_status text default 'Completed';
alter table public.cases add column if not exists incision_time time;
alter table public.cases add column if not exists closure_time time;
alter table public.cases add column if not exists operative_duration_minutes integer;
alter table public.cases add column if not exists estimated_blood_loss integer;
alter table public.cases add column if not exists drain_placed text default 'None';
alter table public.cases add column if not exists drain_type text;
alter table public.cases add column if not exists followup_date date;
alter table public.cases add column if not exists followup_outcome text;
alter table public.cases add column if not exists hpe_status text default 'not_sent';
alter table public.cases add column if not exists sync_status text default 'synced';
alter table public.cases add column if not exists sync_error text;
alter table public.cases add column if not exists is_deleted boolean default false;
alter table public.cases add column if not exists deleted_at timestamptz;
alter table public.cases add column if not exists created_at timestamptz default now();
alter table public.cases add column if not exists updated_at timestamptz default now();

update public.cases set id=gen_random_uuid() where id is null;
update public.cases set created_at=coalesce(created_at,now()),updated_at=coalesce(updated_at,now()),is_deleted=coalesce(is_deleted,false),sync_status=coalesce(sync_status,'synced');

create unique index if not exists cases_id_uidx on public.cases(id);
create unique index if not exists cases_user_case_number_idx on public.cases(user_id,case_number) where case_number is not null;
create index if not exists cases_user_updated_idx on public.cases(user_id,updated_at desc);
create index if not exists cases_user_surgery_idx on public.cases(user_id,surgery_date desc);
create index if not exists cases_user_procedure_idx on public.cases(user_id,procedure_name);

create table if not exists public.case_attachments (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 case_id uuid not null references public.cases(id) on delete cascade,
 file_name text not null,
 file_path text not null,
 category text default 'Other',
 mime_type text,
 file_size bigint,
 created_at timestamptz default now(),
 updated_at timestamptz default now()
);
create index if not exists case_attachments_case_idx on public.case_attachments(case_id,created_at);

create table if not exists public.user_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 doctor_name text,
 hospital text,
 department text,
 unit text,
 preferences jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);

alter table public.cases enable row level security;
alter table public.case_attachments enable row level security;
alter table public.user_profiles enable row level security;

drop policy if exists cases_select_own on public.cases;
drop policy if exists cases_insert_own on public.cases;
drop policy if exists cases_update_own on public.cases;
drop policy if exists cases_delete_own on public.cases;
create policy cases_select_own on public.cases for select using (auth.uid()=user_id);
create policy cases_insert_own on public.cases for insert with check (auth.uid()=user_id);
create policy cases_update_own on public.cases for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy cases_delete_own on public.cases for delete using (auth.uid()=user_id);

drop policy if exists attachments_select_own on public.case_attachments;
drop policy if exists attachments_insert_own on public.case_attachments;
drop policy if exists attachments_update_own on public.case_attachments;
drop policy if exists attachments_delete_own on public.case_attachments;
create policy attachments_select_own on public.case_attachments for select using (auth.uid()=user_id);
create policy attachments_insert_own on public.case_attachments for insert with check (auth.uid()=user_id);
create policy attachments_update_own on public.case_attachments for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy attachments_delete_own on public.case_attachments for delete using (auth.uid()=user_id);

drop policy if exists profiles_select_own on public.user_profiles;
drop policy if exists profiles_insert_own on public.user_profiles;
drop policy if exists profiles_update_own on public.user_profiles;
create policy profiles_select_own on public.user_profiles for select using (auth.uid()=user_id);
create policy profiles_insert_own on public.user_profiles for insert with check (auth.uid()=user_id);
create policy profiles_update_own on public.user_profiles for update using (auth.uid()=user_id) with check (auth.uid()=user_id);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists cases_set_updated_at on public.cases;
create trigger cases_set_updated_at before update on public.cases for each row execute function public.set_updated_at();

create or replace function public.next_case_number() returns text language plpgsql security invoker set search_path=public as $$
declare y text:=to_char(current_date,'YYYY'); n integer;
begin
 if auth.uid() is null then raise exception 'Not authenticated'; end if;
 select coalesce(max((substring(case_number from 6))::integer),0)+1 into n from public.cases where user_id=auth.uid() and case_number like y||'-%';
 return y||'-'||lpad(n::text,3,'0');
end; $$;
grant execute on function public.next_case_number() to authenticated;

-- Private storage bucket. If it already exists, this does nothing.
insert into storage.buckets(id,name,public) values('case-files','case-files',false) on conflict(id) do update set public=false;

drop policy if exists case_files_select_own on storage.objects;
drop policy if exists case_files_insert_own on storage.objects;
drop policy if exists case_files_update_own on storage.objects;
drop policy if exists case_files_delete_own on storage.objects;
create policy case_files_select_own on storage.objects for select to authenticated using (bucket_id='case-files' and (storage.foldername(name))[1]=auth.uid()::text);
create policy case_files_insert_own on storage.objects for insert to authenticated with check (bucket_id='case-files' and (storage.foldername(name))[1]=auth.uid()::text);
create policy case_files_update_own on storage.objects for update to authenticated using (bucket_id='case-files' and (storage.foldername(name))[1]=auth.uid()::text);
create policy case_files_delete_own on storage.objects for delete to authenticated using (bucket_id='case-files' and (storage.foldername(name))[1]=auth.uid()::text);

-- Realtime publication; add only if not already present.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='cases') then
    alter publication supabase_realtime add table public.cases;
  end if;
end $$;
