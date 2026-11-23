-- The manager decides on their own expenses too, as on the others: the
-- accountant does not (this undoes 20261123080000). Every decision stays in
-- the history with the name of who took it, so a manager's approval of
-- their own expense remains visible.

drop policy expenses_read on public.expenses;
create policy expenses_read on public.expenses for select to authenticated
  using (
    employee_id = auth.uid()
    or (
      company_id = public.my_company_id()
      and (
        (public.my_role() = 'manager' and status <> 'draft')
        or (public.my_role() = 'accountant'
            and status in ('approved', 'exported'))
      )
    )
  );

drop function public.is_manager_of_my_company(uuid);

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

-- Confirms, in one gesture, expenses the control found compliant, the
-- manager's own included. An expense with a flag needs its own decision.
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
