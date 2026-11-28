-- The company's reimbursement policy.
--
-- REMBO's rules stay the defaults: a limit per category, a declaration
-- deadline of 60 days, the project optional. A manager may import the
-- company's own policy (PDF, photo or text): the read-policy Edge Function
-- has it read by the receipt engine, which proposes rules. Nothing changes
-- until the manager applies them, here, after checking. What the engine
-- read but REMBO cannot check automatically is kept, for the manager to
-- see.

alter table public.companies
  add column deadline_days integer not null default 60
    check (deadline_days between 1 and 365),
  add column project_required boolean not null default false,
  -- { name, summary, not_applied: [text], applied_at, applied_by }
  add column policy_document jsonb;

-- Applies rules a manager checked: from an imported document (with its
-- "document" key) or typed by hand. Keys left out stay as they are.
--   { "deadline_days": 30, "project_required": true,
--     "rules": [{ "category": "Repas", "limit_cents": 15000,
--                 "receipt_required": true }],
--     "document": { "name": "...", "summary": "...",
--                   "not_applied": ["..."] } }
create function public.apply_policy(p_policy jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_company uuid := public.my_company_id();
  v_rule jsonb;
  v_days integer;
  v_limit bigint;
  v_name text;
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  if jsonb_typeof(p_policy) is distinct from 'object' then
    raise exception 'Règles illisibles.';
  end if;

  if jsonb_typeof(p_policy -> 'deadline_days') = 'number' then
    v_days := (p_policy ->> 'deadline_days')::numeric::integer;
    if v_days not between 1 and 365 then
      raise exception
        'Le délai de déclaration doit être compris entre 1 et 365 jours.';
    end if;
    update public.companies set deadline_days = v_days where id = v_company;
  end if;
  if jsonb_typeof(p_policy -> 'project_required') = 'boolean' then
    update public.companies
    set project_required = (p_policy ->> 'project_required')::boolean
    where id = v_company;
  end if;

  for v_rule in
    select r from jsonb_array_elements(
      case when jsonb_typeof(p_policy -> 'rules') = 'array'
        then p_policy -> 'rules' else '[]'::jsonb end) as r
  loop
    if coalesce(v_rule ->> 'category', '') not in
       ('Repas', 'Transport', 'Hébergement', 'Fournitures') then
      raise exception 'Catégorie inconnue : %.',
        coalesce(v_rule ->> 'category', '');
    end if;
    v_limit := (v_rule ->> 'limit_cents')::numeric::bigint;
    if v_limit is null or v_limit <= 0 or v_limit > 100000000 then
      raise exception 'Plafond invalide pour %.', v_rule ->> 'category';
    end if;
    insert into public.policies (company_id, category, limit_cents,
      receipt_required)
    values (v_company, v_rule ->> 'category', v_limit,
      coalesce((v_rule ->> 'receipt_required')::boolean, true))
    on conflict (company_id, category) do update
      set limit_cents = excluded.limit_cents,
          receipt_required = excluded.receipt_required;
  end loop;

  if jsonb_typeof(p_policy -> 'document') = 'object' then
    select full_name into v_name from public.profiles where id = auth.uid();
    update public.companies set policy_document = jsonb_build_object(
      'name', left(coalesce(p_policy -> 'document' ->> 'name', ''), 200),
      'summary', left(coalesce(p_policy -> 'document' ->> 'summary', ''), 1200),
      'not_applied', coalesce((
        select jsonb_agg(left(n #>> '{}', 300))
        from (
          select n from jsonb_array_elements(
            case when jsonb_typeof(p_policy -> 'document' -> 'not_applied')
              = 'array' then p_policy -> 'document' -> 'not_applied'
              else '[]'::jsonb end) as n
          where jsonb_typeof(n) = 'string'
          limit 20
        ) as kept
      ), '[]'::jsonb),
      'applied_at', now(),
      'applied_by', coalesce(v_name, ''))
    where id = v_company;
  end if;
end $$;

-- Back to REMBO's rules: limits, deadline and project as when the company
-- was created; the imported document is forgotten.
create function public.reset_policy() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_company uuid := public.my_company_id();
begin
  if public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  update public.companies
  set deadline_days = 60, project_required = false, policy_document = null
  where id = v_company;
  delete from public.policies where company_id = v_company;
  insert into public.policies (company_id, category, limit_cents,
    receipt_required)
  values
    (v_company, 'Repas', 20000, true),
    (v_company, 'Transport', 50000, false),
    (v_company, 'Hébergement', 120000, true),
    (v_company, 'Fournitures', 100000, false);
end $$;

-- The control now follows the company's deadline and, when it asks for
-- one, flags an expense without project or client. Otherwise unchanged
-- from 20261123020000.
create or replace function public.control_expense(p_id uuid, p_actor uuid)
returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := p_actor;
  e public.expenses;
  c public.companies;
  v_rule public.policies;
  v_flags jsonb := '[]'::jsonb;
  v_status public.expense_status;
  v_name text;
  v_expected numeric;
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
  if e.currency <> 'MAD' and e.foreign_amount_cents is null then
    raise exception 'Indiquez le montant payé en devise.';
  end if;
  select * into c from public.companies where id = e.company_id;

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
  if c.project_required and trim(e.project) = '' then
    v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
      'Projet ou client manquant');
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
  elsif exists (
    select 1 from public.expenses o
    where o.id <> e.id and o.employee_id = e.employee_id
      and o.amount_cents = e.amount_cents
      and abs(o.expense_date - e.expense_date) <= 3
      and lower(regexp_replace(trim(o.supplier_name), '\s+', ' ', 'g'))
        = lower(regexp_replace(trim(e.supplier_name), '\s+', ' ', 'g'))
      and o.status not in ('draft', 'rejected')
  ) then
    v_flags := v_flags || jsonb_build_object('kind', 'duplicate', 'message',
      'Même fournisseur et même montant à quelques jours d’intervalle');
  end if;
  if e.category = 'Autre' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Catégorie à préciser');
  end if;
  if current_date - e.expense_date > c.deadline_days then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense datée de plus de ' || c.deadline_days || ' jours');
  end if;
  if e.currency <> 'MAD' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense en devise : conversion en dirhams à vérifier');
  end if;
  if e.vat_rate > 0 and e.vat_cents > 0 then
    v_expected := e.amount_cents * e.vat_rate / (100.0 + e.vat_rate);
    if abs(e.vat_cents - v_expected) > greatest(100, v_expected * 0.02) then
      v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
        'TVA incohérente avec le taux indiqué');
    end if;
  end if;
  if e.supplier_ice <> '' and e.supplier_ice !~ '^\d{15}$' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'ICE du fournisseur invalide : 15 chiffres attendus');
  end if;

  v_status := case when v_flags = '[]'::jsonb and c.auto_approve
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

revoke execute on function public.apply_policy(jsonb), public.reset_policy()
  from public, anon;
grant execute on function public.apply_policy(jsonb), public.reset_policy()
  to authenticated;
