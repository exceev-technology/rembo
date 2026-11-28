-- Who approves an expense that complies with every rule.
--
-- Exceev's rule is that no agent approves or rejects an expense: by
-- default the control only marks a compliant expense as such and a
-- manager confirms it, all the compliant ones in one gesture. A company
-- that wants the control to approve them itself turns `auto_approve` on.

alter table public.companies
  add column auto_approve boolean not null default false;

-- Same control as before; only the last step changes: a compliant expense
-- is approved by the agent only when the company asked for it.
create or replace function public.control_expense(p_id uuid, p_actor uuid)
returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := p_actor;
  e public.expenses;
  v_rule public.policies;
  v_flags jsonb := '[]'::jsonb;
  v_status public.expense_status;
  v_auto boolean;
  v_name text;
begin
  select * into e from public.expenses where id = p_id for update;
  if not found or e.employee_id is distinct from v_uid then
    raise exception 'Vous ne pouvez soumettre que vos dépenses.';
  end if;
  if e.status not in ('draft', 'rejected') then
    return e;
  end if;
  if trim(e.supplier_name) = '' or e.expense_date is null
     or e.amount_cents <= 0 or e.category = '' or trim(e.reason) = '' then
    raise exception
      'Complétez le fournisseur, la date, le montant, la catégorie et le motif.';
  end if;
  if e.expense_date > current_date then
    raise exception 'La date de la dépense est dans le futur.';
  end if;

  select * into v_rule from public.policies
  where company_id = e.company_id and category = e.category;
  if found then
    if e.amount_cents > v_rule.limit_cents then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Plafond ' || e.category || ' dépassé de '
        || public.format_mad(e.amount_cents - v_rule.limit_cents));
    end if;
    if v_rule.receipt_required and coalesce(e.receipt_path, '') = '' then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Justificatif manquant');
    end if;
  end if;
  if exists (
    select 1 from public.expenses o
    where o.id <> e.id and o.employee_id = e.employee_id
      and o.expense_date = e.expense_date
      and o.amount_cents = e.amount_cents
      and o.status not in ('draft', 'rejected')
  ) then
    v_flags := v_flags || jsonb_build_object('kind', 'duplicate', 'message',
      'Même date et même montant qu’une dépense déjà déclarée');
  end if;
  if e.category = 'Autre' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Catégorie à préciser');
  end if;
  if current_date - e.expense_date > 60 then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense datée de plus de 60 jours');
  end if;

  select auto_approve into v_auto from public.companies
  where id = e.company_id;
  v_status := case when v_flags = '[]'::jsonb and v_auto
    then 'approved' else 'needs_review' end;
  select full_name into v_name from public.profiles where id = v_uid;

  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     created_at)
  values
    (e.id, e.status, 'submitted', v_uid, 'human', coalesce(v_name, ''),
     clock_timestamp());
  insert into public.status_events
    (expense_id, from_status, to_status, actor_kind, actor_name, reason,
     created_at)
  values
    (e.id, 'submitted', v_status, 'agent', 'Contrôle automatique',
     case when v_flags = '[]'::jsonb and v_status = 'needs_review'
       then 'Conforme aux règles' end,
     clock_timestamp());
  update public.expenses set status = v_status, flags = v_flags
  where id = e.id returning * into e;
  return e;
end $$;

-- A manager chooses whether the control approves compliant expenses.
create function public.set_auto_approve(p_on boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  update public.companies set auto_approve = coalesce(p_on, false)
  where id = public.my_company_id();
  return coalesce(p_on, false);
end $$;

-- Confirms, in one gesture, expenses the control found compliant. Only
-- those: an expense with a flag needs its own decision. Never one's own.
-- Returns how many were approved; the others are left as they were.
create function public.approve_compliant(p_ids uuid[]) returns integer
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

revoke execute on function public.set_auto_approve(boolean),
  public.approve_compliant(uuid[]) from public, anon;
grant execute on function public.set_auto_approve(boolean),
  public.approve_compliant(uuid[]) to authenticated;
