-- A manager's own expense is decided by another manager or by the company's
-- accountant: a company with one manager no longer leaves it waiting for
-- ever. The accountant decides only on managers' expenses, never on the
-- employees' ones, and nobody decides on their own expense.

-- True when the person is a manager of the reader's company.
create function public.is_manager_of_my_company(p_profile uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships
    where profile_id = p_profile
      and company_id = public.my_company_id()
      and role = 'manager'
  )
$$;
revoke execute on function public.is_manager_of_my_company(uuid)
  from public, anon;
grant execute on function public.is_manager_of_my_company(uuid)
  to authenticated;

-- The accountant also sees the managers' expenses waiting for a decision,
-- and the ones rejected (their history). The rest is unchanged.
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
        or (public.my_role() = 'accountant'
            and status in ('needs_review', 'rejected')
            and public.is_manager_of_my_company(employee_id))
      )
    )
  );

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
     or not (
       public.my_role() = 'manager'
       or (public.my_role() = 'accountant'
           and public.is_manager_of_my_company(e.employee_id))
     ) then
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
