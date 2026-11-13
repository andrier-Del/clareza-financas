-- Atualiza a entrada por convite para contas já ligadas a um orçamento individual.
-- Execute uma vez no SQL Editor do projeto Supabase.
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

