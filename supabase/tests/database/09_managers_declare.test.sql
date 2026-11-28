-- Managers and their own expenses (20261127000000_managers_declare):
-- by default a manager only decides; when the company lets managers
-- declare, another manager decides on their expenses, never themselves.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, now(), json_build_object('full_name', p.name),
  now(), now()
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'sara@exemple.ma', 'Sara Manager'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'omar@exemple.ma', 'Omar Employee'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'karim@exemple.ma', 'Karim Manager')
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

-- A new company: Sara is its only manager, Omar an employee.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.create_company('Atelier Sara', '', 'Casablanca');
select pg_temp.as_admin();
insert into public.memberships (company_id, profile_id, role)
select c.id, '22222222-2222-2222-2222-222222222222', 'employee'
from public.companies c where c.name = 'Atelier Sara';

-- By default a manager only decides ------------------------------------------
select is((select managers_declare from public.companies
  where name = 'Atelier Sara'), false,
  'a new company: managers do not declare');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select throws_ok($$insert into public.expenses (company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason)
  values (public.my_company_id(), auth.uid(), 'Café', current_date, 4500,
    'Repas', 'Déjeuner')$$,
  'P0001', 'Dans votre entreprise, les responsables ne déclarent pas de dépenses.',
  'the manager cannot create an expense');
select is(public.can_declare('22222222-2222-2222-2222-222222222222'), true,
  'an employee declares as before');

select pg_temp.as_admin();
select throws_ok($$insert into public.expenses (company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason, source)
  select company_id, '11111111-1111-1111-1111-111111111111', 'Taxi',
    current_date, 4500, 'Transport', 'Course', 'whatsapp'
  from public.memberships
  where profile_id = '11111111-1111-1111-1111-111111111111'$$,
  'P0001', 'Dans votre entreprise, les responsables ne déclarent pas de dépenses.',
  'nor through WhatsApp (the webhook writes as service_role)');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$select public.set_managers_declare(true)$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'only a manager changes the setting');

-- The company lets managers declare ------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(public.set_managers_declare(true), true,
  'the manager lets managers declare');
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason)
  values ('eeeeeeee-0000-0000-0000-000000000001', public.my_company_id(),
    auth.uid(), 'Imprimerie', current_date - 1, 9900, 'Autre',
    'Cartes de visite')$$,
  'Sara now declares her own expense');
select is((public.submit_expense('eeeeeeee-0000-0000-0000-000000000001')).status,
  'needs_review'::public.expense_status, 'it waits for a manager');
select throws_ok($$select public.decide_expense(
    'eeeeeeee-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Vous ne pouvez pas décider de votre propre dépense.',
  'alone, she cannot decide on it: it waits for a second manager');
select is(public.approve_compliant(
    array['eeeeeeee-0000-0000-0000-000000000001'::uuid]), 0,
  'nor confirm it in a batch');

-- A second manager decides ---------------------------------------------------
select pg_temp.as_admin();
insert into public.memberships (company_id, profile_id, role)
select c.id, '66666666-6666-6666-6666-666666666666', 'manager'
from public.companies c where c.name = 'Atelier Sara';
select pg_temp.as_user('66666666-6666-6666-6666-666666666666');
select is((public.decide_expense('eeeeeeee-0000-0000-0000-000000000001',
    true, 'Validé')).status,
  'approved'::public.expense_status, 'the second manager approves it');
select is((select actor_name from public.status_events
  where expense_id = 'eeeeeeee-0000-0000-0000-000000000001'
    and to_status = 'approved'),
  'Karim Manager', 'the history names who decided');

select * from finish();
rollback;
