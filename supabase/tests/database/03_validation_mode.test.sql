-- Sprint 5 · Who approves a compliant expense.
-- Run with: supabase test db
--
-- By default the control only marks a compliant expense; a manager
-- confirms the compliant ones in one gesture. A company may let the
-- control approve them itself.

begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, now(), json_build_object('full_name', p.name),
  now(), now()
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'sara@exemple.ma', 'Sara Manager'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'omar@exemple.ma', 'Omar Employee'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'karim@exemple.ma', 'Karim Manager'),
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

-- Omar submits as his own employee would.
create function pg_temp.draft(p_id uuid, p_amount int, p_category text)
returns void language sql as $$
  insert into public.expenses (id, company_id, employee_id, supplier_name,
    expense_date, amount_cents, category, reason)
  values (p_id, public.my_company_id(), auth.uid(), 'Taxi Bleu',
    current_date - 1, p_amount, p_category, 'Course client');
$$;

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.create_company('Atelier Sara', '', 'Casablanca');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select public.create_company('Autre SARL', '', 'Rabat');
select pg_temp.as_admin();
insert into public.memberships (company_id, profile_id, role)
select id, '22222222-2222-2222-2222-222222222222'::uuid, 'employee'::public.member_role
from public.companies where name = 'Atelier Sara'
union all
select id, '66666666-6666-6666-6666-666666666666'::uuid, 'manager'::public.member_role
from public.companies where name = 'Atelier Sara';

-- Default: a manager confirms -----------------------------------------------
select is((select auto_approve from public.companies
  where name = 'Atelier Sara'), false,
  'a new company lets a manager confirm compliant expenses');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select pg_temp.draft('cccccccc-0000-0000-0000-000000000001', 4500, 'Transport');
select pg_temp.draft('cccccccc-0000-0000-0000-000000000002', 3000, 'Transport');
select pg_temp.draft('cccccccc-0000-0000-0000-000000000003', 2500, 'Autre');
select is((public.submit_expense('cccccccc-0000-0000-0000-000000000001')).status,
  'needs_review'::public.expense_status,
  'a compliant expense waits for a manager');
select is((select flags from public.expenses
  where id = 'cccccccc-0000-0000-0000-000000000001'), '[]'::jsonb,
  'it carries no flag');
select is((select reason from public.status_events
  where expense_id = 'cccccccc-0000-0000-0000-000000000001'
    and actor_kind = 'agent'), 'Conforme aux règles',
  'the agent says it is compliant, it does not approve');
select public.submit_expense('cccccccc-0000-0000-0000-000000000002');
select public.submit_expense('cccccccc-0000-0000-0000-000000000003');

-- Who may confirm --------------------------------------------------------------
select throws_ok($$select public.approve_compliant(
    array['cccccccc-0000-0000-0000-000000000001'::uuid])$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'an employee cannot confirm');
select throws_ok($$select public.set_auto_approve(true)$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'an employee cannot change the mode');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select pg_temp.draft('cccccccc-0000-0000-0000-000000000004', 2000, 'Transport');
select public.submit_expense('cccccccc-0000-0000-0000-000000000004');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is(public.approve_compliant(
    array['cccccccc-0000-0000-0000-000000000001'::uuid]), 0,
  'a manager of another company confirms nothing');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(public.approve_compliant(array[
    'cccccccc-0000-0000-0000-000000000001',
    'cccccccc-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000003',
    'cccccccc-0000-0000-0000-000000000004']::uuid[]), 2,
  'the manager confirms the two compliant expenses of her team');
select is((select status from public.expenses
  where id = 'cccccccc-0000-0000-0000-000000000003'),
  'needs_review'::public.expense_status,
  'an expense with a flag keeps waiting for its own decision');
select is((select status from public.expenses
  where id = 'cccccccc-0000-0000-0000-000000000004'),
  'needs_review'::public.expense_status,
  'her own expense is never confirmed by herself');
select is((select actor_kind || ' · ' || actor_name || ' · ' || reason
  from public.status_events
  where expense_id = 'cccccccc-0000-0000-0000-000000000001'
    and to_status = 'approved'),
  'human · Sara Manager · Validation groupée des dépenses conformes',
  'the history names the person who confirmed');
select is(public.approve_compliant(
    array['cccccccc-0000-0000-0000-000000000001'::uuid]), 0,
  'confirming again changes nothing');

select pg_temp.as_user('66666666-6666-6666-6666-666666666666');
select is(public.approve_compliant(
    array['cccccccc-0000-0000-0000-000000000004'::uuid]), 1,
  'another manager confirms Sara''s compliant expense');

-- A company may let the control approve ---------------------------------------
select is(public.set_auto_approve(true), true,
  'a manager lets the control approve compliant expenses');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select pg_temp.draft('cccccccc-0000-0000-0000-000000000005', 1500, 'Transport');
select is((public.submit_expense('cccccccc-0000-0000-0000-000000000005')).status,
  'approved'::public.expense_status,
  'then a compliant expense is approved by the control');
select is((select actor_kind from public.status_events
  where expense_id = 'cccccccc-0000-0000-0000-000000000005'
    and to_status = 'approved'), 'agent',
  'and the history says it was the agent');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select auto_approve from public.companies), false,
  'the setting of one company never changes another');

select pg_temp.as_admin();
select * from finish();
rollback;
