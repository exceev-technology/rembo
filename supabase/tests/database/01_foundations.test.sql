-- Sprint 1 · Foundations: accounts, companies, roles and row level security.
-- Run with: supabase test db
--
-- Two companies: « Atelier Sara » (Sara manager, Omar employee, Lina
-- accountant) and « Autre SARL » (Zed manager). Each step signs in as one
-- person and checks what that person can and cannot do.

begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

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
  ('00000000-0000-0000-0000-000000000000', '55555555-5555-5555-5555-555555555555',
   'authenticated', 'authenticated', 'nora@exemple.ma', null,
   '{"full_name":"Nora Unconfirmed"}', now(), now());

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

-- Schema -------------------------------------------------------------------
select is(
  (select count(*)::int from pg_tables
   where schemaname = 'public' and not rowsecurity),
  0, 'every public table has row level security enabled');

select is(
  (select public from storage.buckets where id = 'receipts'),
  false, 'the receipts bucket is private');

select is(
  (select full_name from public.profiles
   where id = '22222222-2222-2222-2222-222222222222'),
  'Omar Employee', 'a profile is created with each new account');

select is(
  (select email from public.profiles
   where id = '11111111-1111-1111-1111-111111111111'),
  'sara@exemple.ma', 'the profile keeps the e-mail in lower case');

-- Visitors (not signed in) -------------------------------------------------
set local role anon;
select throws_ok('select * from public.expenses', '42501', null,
  'a visitor cannot read expenses');
select throws_ok('select * from public.companies', '42501', null,
  'a visitor cannot read companies');
select throws_ok('select * from public.receipt_readings', '42501', null,
  'the count of AI readings is not readable by the app');
select throws_ok($$select public.create_company('X SARL', '', '')$$, '42501',
  null, 'a visitor cannot create a company');
reset role;

-- Companies and roles ------------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select isnt(public.create_company('Atelier Sara', '', 'Casablanca'), null,
  'Sara creates her company');
select is(public.my_role(), 'manager'::public.member_role,
  'the founder becomes manager');
select is((select count(*)::int from public.policies), 4,
  'the company starts with the four default rules');
select throws_ok($$select public.create_company('Deuxième', '', '')$$,
  'P0001', 'Vous appartenez déjà à une entreprise.',
  'a person belongs to one company only');
select lives_ok($$insert into public.invitations (company_id, email, role)
  values (public.my_company_id(), 'omar@exemple.ma', 'employee'),
         (public.my_company_id(), 'lina@exemple.ma', 'accountant'),
         (public.my_company_id(), 'nora@exemple.ma', 'employee')$$,
  'a manager invites people with a role');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select isnt(public.create_company('Autre SARL', '', 'Rabat'), null,
  'Zed creates another company');

-- These steps check the control itself: the companies let it approve the
-- compliant expenses (by default a manager confirms them, see
-- 03_validation_mode).
select pg_temp.as_admin();
update public.companies set auto_approve = true;

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select ok(public.accept_invitation(), 'Omar joins through his invitation');
select is(public.my_role(), 'employee'::public.member_role,
  'Omar gets the invited role');

select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select ok(public.accept_invitation(), 'Lina joins through her invitation');
select is(public.my_role(), 'accountant'::public.member_role,
  'Lina gets the invited role');

select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
select ok(not public.accept_invitation(),
  'an unconfirmed e-mail address cannot use an invitation');

-- Isolation between companies ---------------------------------------------
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from public.companies), 1,
  'Zed sees only his own company');
select is((select count(*)::int from public.profiles), 1,
  'Zed sees no profile of the other company');
select is((select count(*)::int from public.memberships), 1,
  'Zed sees no membership of the other company');
select is((select count(*)::int from public.invitations), 0,
  'Zed sees no invitation of the other company');

-- Rights inside a company --------------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is((select count(*)::int from public.profiles), 3,
  'Omar sees the three members of his company, not the pending invitee');
select throws_ok($$insert into public.invitations (company_id, email, role)
  values (public.my_company_id(), 'x@exemple.ma', 'manager')$$, '42501', null,
  'an employee cannot invite anyone');
select throws_ok($$update public.memberships set role = 'manager'
  where profile_id = auth.uid()$$, '42501', null,
  'nobody can change their own role');
update public.policies set limit_cents = 999999;
select is((select max(limit_cents)::int from public.policies), 120000,
  'an employee cannot change the rules');
update public.profiles set full_name = 'Piraté'
  where id = '11111111-1111-1111-1111-111111111111';
select is((select full_name from public.profiles
  where id = '11111111-1111-1111-1111-111111111111'), 'Sara Manager',
  'nobody can rename another person');
select lives_ok($$update public.profiles set full_name = 'Omar E.'
  where id = auth.uid()$$, 'a person can rename themselves');

-- Expenses -----------------------------------------------------------------
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason)
  values ('aaaaaaaa-0000-0000-0000-000000000001', public.my_company_id(),
    auth.uid(), 'Petit Taxi', current_date - 1, 4500, 'Transport',
    'Course client')$$,
  'an employee creates a draft');
select throws_ok($$insert into public.expenses (company_id, employee_id,
    supplier_name, amount_cents)
  values (public.my_company_id(), '11111111-1111-1111-1111-111111111111',
    'Faux', 100)$$, '42501', null,
  'nobody creates an expense in someone else''s name');
select throws_ok($$update public.expenses set status = 'approved'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$, '42501', null,
  'the app can never write a status');
select throws_ok($$select public.control_expense(
    'aaaaaaaa-0000-0000-0000-000000000001', auth.uid())$$, '42501', null,
  'only the server may call the control directly');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select count(*)::int from public.expenses), 0,
  'a manager does not see a colleague''s draft');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is((public.submit_expense('aaaaaaaa-0000-0000-0000-000000000001')).status,
  'approved'::public.expense_status,
  'a compliant expense is approved by the automatic control');
select is((select count(*)::int from public.status_events
  where expense_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 2,
  'the history records the submission and the control');

select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select is((select count(*)::int from public.expenses), 1,
  'the accountant sees the approved expense');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from public.expenses), 0,
  'another company never sees it');
select is((select count(*)::int from public.status_events), 0,
  'nor its history');

-- Receipts -----------------------------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select lives_ok($$insert into storage.objects (bucket_id, name, owner_id)
  values ('receipts', '22222222-2222-2222-2222-222222222222/r1', auth.uid()::text)$$,
  'a person stores a receipt in their own folder');
select throws_ok($$insert into storage.objects (bucket_id, name, owner_id)
  values ('receipts', '11111111-1111-1111-1111-111111111111/r1', auth.uid()::text)$$,
  '42501', null, 'nobody writes in someone else''s folder');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from storage.objects
  where bucket_id = 'receipts'), 0,
  'another company cannot list or read the receipt');

select pg_temp.as_admin();
select * from finish();
rollback;
