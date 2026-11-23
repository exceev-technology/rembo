-- Sprint 4 · Approval workflow: who may decide, on what, and what the
-- history keeps. Run with: supabase test db
--
-- « Atelier Sara »: Sara and Karim managers, Omar employee, Lina accountant.
-- « Autre SARL »: Zed manager. Each step signs in as one person.

begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

-- People -------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'sara@exemple.ma', now(),
   '{"full_name":"Sara Manager"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'omar@exemple.ma', now(),
   '{"full_name":"Omar Employee"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'lina@exemple.ma', now(),
   '{"full_name":"Lina Accountant"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444',
   'authenticated', 'authenticated', 'zed@autre.ma', now(),
   '{"full_name":"Zed Other"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '66666666-6666-6666-6666-666666666666',
   'authenticated', 'authenticated', 'karim@exemple.ma', now(),
   '{"full_name":"Karim Manager"}', now(), now());

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

-- Companies ----------------------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select isnt(public.create_company('Atelier Sara', '', 'Casablanca'), null,
  'Sara creates her company');
select lives_ok($$insert into public.invitations (company_id, email, role)
  values (public.my_company_id(), 'karim@exemple.ma', 'manager'),
         (public.my_company_id(), 'omar@exemple.ma', 'employee'),
         (public.my_company_id(), 'lina@exemple.ma', 'accountant')$$,
  'Sara invites a second manager, an employee and an accountant');

select pg_temp.as_user('66666666-6666-6666-6666-666666666666');
select ok(public.accept_invitation(), 'Karim joins as manager');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select ok(public.accept_invitation(), 'Omar joins as employee');
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select ok(public.accept_invitation(), 'Lina joins as accountant');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select isnt(public.create_company('Autre SARL', '', 'Rabat'), null,
  'Zed creates another company');

-- These steps check the control itself: the companies let it approve the
-- compliant expenses (by default a manager confirms them, see
-- 03_validation_mode).
select pg_temp.as_admin();
update public.companies set auto_approve = true;

-- An expense that needs a manager ------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason)
  values ('bbbbbbbb-0000-0000-0000-000000000001', public.my_company_id(),
    auth.uid(), 'Librairie Centrale', current_date - 1, 4500, 'Autre',
    'Livres pour le client')$$,
  'Omar creates a draft');
select is((public.submit_expense('bbbbbbbb-0000-0000-0000-000000000001')).status,
  'needs_review'::public.expense_status,
  'an expense to clarify waits for a manager');

-- Who may decide -------------------------------------------------------------
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'an employee cannot decide');

select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'an accountant cannot decide');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Cette action est réservée aux responsables.',
  'a manager of another company cannot decide');

-- A rejection needs a reason -------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', false, null)$$,
  'P0001', 'Le motif du rejet est obligatoire.',
  'a rejection without a reason is refused');
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', false, '   ')$$,
  'P0001', 'Le motif du rejet est obligatoire.',
  'a blank reason is not a reason');
select is((public.decide_expense('bbbbbbbb-0000-0000-0000-000000000001',
    false, '  Ticket illisible  ')).status,
  'rejected'::public.expense_status,
  'the manager rejects with a reason');
select is((select reason from public.status_events
  where expense_id = 'bbbbbbbb-0000-0000-0000-000000000001'
    and to_status = 'rejected'),
  'Ticket illisible', 'the history keeps the reason, trimmed');
select is((select actor_name from public.status_events
  where expense_id = 'bbbbbbbb-0000-0000-0000-000000000001'
    and to_status = 'rejected'),
  'Sara Manager', 'the history names who decided');
select throws_ok($$select public.decide_expense(
    'bbbbbbbb-0000-0000-0000-000000000001', true, '')$$,
  'P0001', 'Cette dépense a déjà été traitée.',
  'an expense is decided once');
select throws_ok($$insert into public.status_events
    (expense_id, to_status, actor_kind, actor_name)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'approved', 'human', 'X')$$,
  '42501', null, 'the app can never write the history');

-- The employee corrects and sends again --------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select lives_ok($$update public.expenses set category = 'Transport'
  where id = 'bbbbbbbb-0000-0000-0000-000000000001'$$,
  'the owner corrects a rejected expense');
select is((public.submit_expense('bbbbbbbb-0000-0000-0000-000000000001')).status,
  'approved'::public.expense_status,
  'the corrected expense goes through the control again');
select is((select count(*)::int from public.status_events
  where expense_id = 'bbbbbbbb-0000-0000-0000-000000000001'), 5,
  'the history keeps every step: submitted, review, rejected, submitted, approved');

-- A manager decides on her own expense too ------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason)
  values ('bbbbbbbb-0000-0000-0000-000000000002', public.my_company_id(),
    auth.uid(), 'Imprimerie Atlas', current_date - 2, 9900, 'Autre',
    'Cartes de visite')$$,
  'Sara creates her own draft');
select is((public.submit_expense('bbbbbbbb-0000-0000-0000-000000000002')).status,
  'needs_review'::public.expense_status,
  'her expense waits for a manager too');
select is((public.decide_expense('bbbbbbbb-0000-0000-0000-000000000002',
    true, '')).status,
  'approved'::public.expense_status,
  'the manager approves her own expense');
select is((select actor_name from public.status_events
  where expense_id = 'bbbbbbbb-0000-0000-0000-000000000002'
    and to_status = 'approved' and actor_kind = 'human'),
  'Sara Manager', 'the history names her as the one who decided');
select is((select reason from public.status_events
  where expense_id = 'bbbbbbbb-0000-0000-0000-000000000002'
    and to_status = 'approved' and actor_kind = 'human'),
  null, 'an approval without a comment keeps no empty reason');

select pg_temp.as_admin();
select * from finish();
rollback;
