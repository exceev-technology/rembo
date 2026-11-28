-- The company's reimbursement policy (20261128000000_company_policy):
-- REMBO's rules by default; the rules a manager applies after checking
-- what the engine read in the company's document; back to the defaults.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, now(), json_build_object('full_name', p.name),
  now(), now()
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'sara@exemple.ma', 'Sara Manager'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'omar@exemple.ma', 'Omar Employee')
) as p (id, email, name);

create function pg_temp.as_user(p_uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

create function pg_temp.as_admin() returns void
language sql as $$
  select set_config('role', 'postgres', true);
  select set_config('request.jwt.claims', '', true);
$$;

-- Omar declares an expense dated `p_days` ago, with or without project,
-- and submits it: the flags the control raised.
create function pg_temp.flags_of(p_days integer, p_project text)
returns jsonb language plpgsql as $$
declare
  v_id uuid;
begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.expenses (company_id, employee_id, supplier_name,
    expense_date, amount_cents, category, reason, project)
  values (public.my_company_id(), auth.uid(), 'Imprimerie ' || p_days,
    current_date - p_days, 5000 + p_days * 10 + length(p_project),
    'Fournitures', 'Cartes',
    p_project)
  returning id into v_id;
  return (public.submit_expense(v_id)).flags;
end $$;

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.create_company('Atelier Sara', '', 'Casablanca');
select pg_temp.as_admin();
insert into public.memberships (company_id, profile_id, role)
select c.id, '22222222-2222-2222-2222-222222222222', 'employee'
from public.companies c where c.name = 'Atelier Sara';

-- REMBO's rules by default ----------------------------------------------------
select is((select deadline_days from public.companies
  where name = 'Atelier Sara'), 60, 'the deadline is 60 days by default');
select is((select project_required from public.companies
  where name = 'Atelier Sara'), false, 'the project is optional by default');
select is(pg_temp.flags_of(40, ''), '[]'::jsonb,
  'an expense of 40 days without project is compliant by default');

-- Only a manager applies rules -----------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$select public.apply_policy('{"deadline_days": 5}')$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'an employee cannot change the rules');

-- The manager applies what was read in the company's document ---------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select lives_ok($$select public.apply_policy('{
    "deadline_days": 30,
    "project_required": true,
    "rules": [{"category": "Repas", "limit_cents": 15000,
               "receipt_required": true}],
    "document": {"name": "politique.pdf", "summary": "Notes de frais",
                 "not_applied": ["Pas d''alcool"]}
  }')$$, 'the manager applies the rules read in the document');
select is((select deadline_days from public.companies
  where name = 'Atelier Sara'), 30, 'the deadline is now 30 days');
select is((select limit_cents from public.policies
  where category = 'Repas'), 15000::bigint, 'the meal limit is 150 MAD');
select is((select policy_document ->> 'name' from public.companies
  where name = 'Atelier Sara'), 'politique.pdf', 'the document is named');
select is((select policy_document -> 'not_applied' from public.companies
  where name = 'Atelier Sara'), '["Pas d''alcool"]'::jsonb,
  'what REMBO cannot check is kept for the manager');
select is((select policy_document ->> 'applied_by' from public.companies
  where name = 'Atelier Sara'), 'Sara Manager', 'and who applied it');

select throws_ok($$select public.apply_policy('{"deadline_days": 0}')$$,
  'P0001', 'Le délai de déclaration doit être compris entre 1 et 365 jours.',
  'a deadline of 0 days is refused');
select throws_ok($$select public.apply_policy(
    '{"rules": [{"category": "Alcool", "limit_cents": 100}]}')$$,
  'P0001', 'Catégorie inconnue : Alcool.',
  'an unknown category is refused');

-- The control follows the company's rules ------------------------------------
select is(pg_temp.flags_of(40, 'Chantier Anfa'),
  '[{"kind": "ambiguity", "message": "Dépense datée de plus de 30 jours"}]'::jsonb,
  'after 30 days the expense is flagged');
select is(pg_temp.flags_of(2, ''),
  '[{"kind": "policy", "message": "Projet ou client manquant"}]'::jsonb,
  'without project or client it is flagged');

-- Back to REMBO's rules ------------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.reset_policy();
select is((select deadline_days || '/' || project_required || '/'
    || (policy_document is null)
  from public.companies where name = 'Atelier Sara'),
  '60/false/true', 'the defaults are back, the document forgotten');
select is((select limit_cents from public.policies
  where category = 'Repas'), 20000::bigint, 'the meal limit is 200 MAD again');

select * from finish();
rollback;
