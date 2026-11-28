-- Testing Protocol · controls C1, C2 and C4, in one place.
-- (C3 export totals: 06_export_agent; C5 no secret on the client:
-- tool/check_no_secrets.sh in the CI.)
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, now(), json_build_object('full_name', p.name),
  now(), now()
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'sara@exemple.ma', 'Sara Manager'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'omar@exemple.ma', 'Omar Employee'),
  ('77777777-7777-7777-7777-777777777777'::uuid, 'salma@exemple.ma', 'Salma Employee'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'zed@autre.ma', 'Zed Other')
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

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.create_company('Atelier Sara', '', 'Casablanca');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select public.create_company('Autre SARL', '', 'Rabat');
select pg_temp.as_admin();
-- These tests are about managers who declare their own expenses too.
update public.companies set managers_declare = true;
insert into public.memberships (company_id, profile_id, role)
select c.id, m.id, 'employee'::public.member_role
from public.companies c, (values
  ('22222222-2222-2222-2222-222222222222'::uuid),
  ('77777777-7777-7777-7777-777777777777'::uuid)) as m (id)
where c.name = 'Atelier Sara';

-- Omar declares two meals with their receipt: one over the limit (C4),
-- one compliant.
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
insert into storage.objects (bucket_id, name, owner_id) values
  ('receipts', '22222222-2222-2222-2222-222222222222/c2-a', auth.uid()::text),
  ('receipts', '22222222-2222-2222-2222-222222222222/c2-b', auth.uid()::text);
insert into public.expenses (id, company_id, employee_id, supplier_name,
  expense_date, amount_cents, category, reason, receipt_path)
values
  ('c0000000-0000-0000-0000-000000000001', public.my_company_id(), auth.uid(),
   'Restaurant Le Jardin', current_date - 1, 32000, 'Repas', 'Client',
   '22222222-2222-2222-2222-222222222222/c2-a'),
  ('c0000000-0000-0000-0000-000000000002', public.my_company_id(), auth.uid(),
   'Café Atlas', current_date - 2, 9000, 'Repas', 'Client',
   '22222222-2222-2222-2222-222222222222/c2-b');

-- C2 · receipt isolation ------------------------------------------------------
select pg_temp.as_user('77777777-7777-7777-7777-777777777777');
select is((select count(*)::int from storage.objects
  where bucket_id = 'receipts'), 0,
  'C2: a colleague cannot read Omar''s receipts, even by their name');
select is((select count(*)::int from public.expenses), 0,
  'C2: nor his expenses');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select count(*)::int from storage.objects
  where bucket_id = 'receipts'), 0,
  'C2: the manager cannot read a draft''s receipt either');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.submit_expense('c0000000-0000-0000-0000-000000000001');
select public.submit_expense('c0000000-0000-0000-0000-000000000002');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select count(*)::int from storage.objects
  where bucket_id = 'receipts'), 2,
  'C2: once submitted, the manager reads the receipts to decide');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from storage.objects
  where bucket_id = 'receipts'), 0,
  'C2: another company never reads them');

-- C4 · escalation with the reason shown ----------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is((select status from public.expenses
  where id = 'c0000000-0000-0000-0000-000000000001'),
  'needs_review'::public.expense_status,
  'C4: an expense over the limit goes to a manager');
select is((select flags -> 0 ->> 'message' from public.expenses
  where id = 'c0000000-0000-0000-0000-000000000001'),
  'Plafond Repas dépassé de 120,00 MAD',
  'C4: with the reason written for the manager');

-- C1 · no self-approval, by any path -------------------------------------------
select throws_ok($$select public.decide_expense(
    'c0000000-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'C1: an employee cannot approve');
select pg_temp.as_admin();
update public.memberships set role = 'manager'
where profile_id = '22222222-2222-2222-2222-222222222222';
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$select public.decide_expense(
    'c0000000-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Vous ne pouvez pas décider de votre propre dépense.',
  'C1: promoted manager, Omar still cannot approve his own expense');
select is(public.approve_compliant(
    array['c0000000-0000-0000-0000-000000000002'::uuid]), 0,
  'C1: nor confirm his own compliant expense in a batch');

select pg_temp.as_admin();
select * from finish();
rollback;
