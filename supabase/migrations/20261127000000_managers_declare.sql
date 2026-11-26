-- Managers and their own expenses.
--
-- By default a manager only decides: they do not declare expenses in REMBO,
-- which keeps their space light. A company that needs it turns
-- `managers_declare` on. Even then nobody decides on their own expense
-- (this undoes 20261123090000): another manager does, and a manager alone
-- in the company waits until a second one is invited.

alter table public.companies
  add column managers_declare boolean not null default false;

-- True when this person may declare expenses: a manager only when the
-- company allows it; the other roles as before.
create function public.can_declare(p_profile uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select m.role <> 'manager' or c.managers_declare
    from public.memberships m
    join public.companies c on c.id = m.company_id
    where m.profile_id = p_profile
  ), false)
$$;

-- Every way in (the app, the WhatsApp webhook running as service_role)
-- goes through this check.
create function public.check_can_declare() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- An insert in someone else's name is refused by row level security.
  if auth.uid() is not null and new.employee_id is distinct from auth.uid() then
    return new;
  end if;
  if not public.can_declare(new.employee_id) then
    raise exception
      'Dans votre entreprise, les responsables ne déclarent pas de dépenses.';
  end if;
  return new;
end $$;

create trigger expenses_can_declare
  before insert on public.expenses
  for each row execute function public.check_can_declare();

-- A manager chooses whether managers declare their own expenses.
create function public.set_managers_declare(p_on boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  update public.companies set managers_declare = coalesce(p_on, false)
  where id = public.my_company_id();
  return coalesce(p_on, false);
end $$;

-- Never on one's own expense.
create or replace function public.decide_expense(
  p_id uuid, p_approve boolean, p_reason text
) returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  e public.expenses;
  v_status public.expense_status;
  v_name text;
begin
  select * into e from public.expenses where id = p_id for update;
  if not found
     or e.company_id is distinct from public.my_company_id()
     or public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  if e.employee_id = v_uid then
    raise exception 'Vous ne pouvez pas décider de votre propre dépense.';
  end if;
  if e.status <> 'needs_review' then
    raise exception 'Cette dépense a déjà été traitée.';
  end if;
  if not p_approve and trim(coalesce(p_reason, '')) = '' then
    raise exception 'Le motif du rejet est obligatoire.';
  end if;
  v_status := case when p_approve then 'approved' else 'rejected' end;
  select full_name into v_name from public.profiles where id = v_uid;
  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     reason)
  values
    (e.id, e.status, v_status, v_uid, 'human', coalesce(v_name, ''),
     nullif(left(trim(coalesce(p_reason, '')), 200), ''));
  update public.expenses set status = v_status
  where id = e.id returning * into e;
  return e;
end $$;

-- The batch of compliant expenses leaves the manager's own ones out.
create or replace function public.approve_compliant(p_ids uuid[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_name text;
  v_ids uuid[];
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  select array_agg(id) into v_ids from (
    select id from public.expenses
    where id = any (p_ids)
      and company_id = public.my_company_id()
      and status = 'needs_review'
      and flags = '[]'::jsonb
      and employee_id <> v_uid
    for update
  ) as compliant;
  if v_ids is null then
    return 0;
  end if;
  select full_name into v_name from public.profiles where id = v_uid;
  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     reason)
  select id, 'needs_review', 'approved', v_uid, 'human', coalesce(v_name, ''),
    'Validation groupée des dépenses conformes'
  from unnest(v_ids) as id;
  update public.expenses set status = 'approved' where id = any (v_ids);
  return cardinality(v_ids);
end $$;

revoke execute on function public.can_declare(uuid),
  public.check_can_declare(), public.set_managers_declare(boolean)
  from public, anon;
grant execute on function public.can_declare(uuid),
  public.set_managers_declare(boolean) to authenticated;
grant execute on function public.can_declare(uuid) to service_role;
