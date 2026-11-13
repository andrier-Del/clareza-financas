-- Clareza: estrutura mínima para um orçamento familiar compartilhado.
-- Execute no SQL Editor do projeto Supabase.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Orçamento da família',
  invite_code text not null unique default upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 12)),
  data jsonb not null default '{"name":"","budgets":[],"recurring":[],"transactions":[],"installments":[],"investments":[]}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists household_members_household_id_idx on public.household_members(household_id);

create or replace function public.is_household_member(target_household uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.household_members m where m.household_id = target_household and m.user_id = auth.uid()); $$;

create or replace function public.create_household(household_name text, member_name text)
returns table (household_id uuid, invite_code text)
language plpgsql security definer set search_path = public, extensions
as $$
declare new_id uuid; new_code text;
begin
  if auth.uid() is null then raise exception 'É necessário entrar na conta.'; end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then raise exception 'Esta conta já pertence a um orçamento.'; end if;
  insert into public.households(name) values (coalesce(nullif(trim(household_name), ''), 'Orçamento da família')) returning id, households.invite_code into new_id, new_code;
  insert into public.household_members(user_id, household_id, display_name) values (auth.uid(), new_id, coalesce(nullif(trim(member_name), ''), ''));
  return query select new_id, new_code;
end; $$;

create or replace function public.join_household(code text, member_name text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare target_id uuid; current_id uuid;
begin
  if auth.uid() is null then raise exception 'É necessário entrar na conta.'; end if;
  select h.id into target_id from public.households h where h.invite_code = upper(trim(code));
  if target_id is null then raise exception 'Código de convite inválido.'; end if;
  select m.household_id into current_id from public.household_members m where m.user_id = auth.uid() for update;
  if current_id = target_id then return target_id; end if;
  if current_id is null then
    insert into public.household_members(user_id, household_id, display_name) values (auth.uid(), target_id, coalesce(nullif(trim(member_name), ''), ''));
  else
    update public.household_members set household_id = target_id, display_name = coalesce(nullif(trim(member_name), ''), display_name) where user_id = auth.uid();
  end if;
  return target_id;
end; $$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;

drop policy if exists "Members can view their household" on public.households;
create policy "Members can view their household" on public.households for select to authenticated using (public.is_household_member(id));
drop policy if exists "Members can update their household data" on public.households;
create policy "Members can update their household data" on public.households for update to authenticated using (public.is_household_member(id)) with check (public.is_household_member(id));
drop policy if exists "Members can view household membership" on public.household_members;
create policy "Members can view household membership" on public.household_members for select to authenticated using (public.is_household_member(household_id));
drop policy if exists "Members can update their own display name" on public.household_members;
create policy "Members can update their own display name" on public.household_members for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.households from anon, authenticated;
grant select on public.households to authenticated;
grant update(data) on public.households to authenticated;
revoke all on public.household_members from anon, authenticated;
grant select on public.household_members to authenticated;
grant update(display_name) on public.household_members to authenticated;
revoke all on function public.create_household(text, text) from public, anon;
grant execute on function public.create_household(text, text) to authenticated;
revoke all on function public.join_household(text, text) from public, anon;
grant execute on function public.join_household(text, text) to authenticated;
revoke all on function public.is_household_member(uuid) from public, anon;
grant execute on function public.is_household_member(uuid) to authenticated;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'households') then
    alter publication supabase_realtime add table public.households;
  end if;
end $$;
