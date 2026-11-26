-- Sprint 5 · Export agent: accounts per category, VAT total of a batch,
-- and control C3 (the exported totals equal the approved totals).
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, now(), json_build_object('full_name', p.name),
  now(), now()
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'sara@exemple.ma', 'Sara Manager'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'omar@exemple.ma', 'Omar Employee'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'lina@exemple.ma', 'Lina Accountant'),
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
select public.set_auto_approve(true);
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select public.create_company('Autre SARL', '', 'Rabat');
select pg_temp.as_admin();
-- These tests are about managers who declare their own expenses too.
update public.companies set managers_declare = true;
insert into public.memberships (company_id, profile_id, role)
select c.id, m.profile_id, m.role::public.member_role
from public.companies c, (values
  ('22222222-2222-2222-2222-222222222222'::uuid, 'employee'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'accountant')
) as m (profile_id, role)
where c.name = 'Atelier Sara';

-- Accounts -------------------------------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$insert into public.category_accounts
    (company_id, category, account_code)
  values (public.my_company_id(), 'Transport', '6142')$$, '42501', null,
  'an employee cannot set an account');

select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select lives_ok($$insert into public.category_accounts
    (company_id, category, account_code)
  values (public.my_company_id(), 'Transport', '6142')$$,
  'the accountant sets the account of a category');
select throws_ok($$insert into public.category_accounts
    (company_id, category, account_code)
  values (public.my_company_id(), 'Repas', '61A3')$$, '23514', null,
  'an account is made of digits');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from public.category_accounts), 0,
  'another company does not see the accounts');

-- Export totals (control C3) ---------------------------------------------------
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
insert into public.expenses (id, company_id, employee_id, supplier_name,
  expense_date, amount_cents, vat_cents, vat_rate, category, reason)
values
  ('ffffffff-0000-0000-0000-000000000001', public.my_company_id(), auth.uid(),
   'Taxi Bleu', current_date - 1, 4500, 0, null, 'Transport', 'Course'),
  ('ffffffff-0000-0000-0000-000000000002', public.my_company_id(), auth.uid(),
   'ONCF', current_date - 2, 24900, 4150, 20, 'Transport', 'Train'),
  ('ffffffff-0000-0000-0000-000000000003', public.my_company_id(), auth.uid(),
   'Librairie', current_date - 3, 18000, 3000, 20, 'Fournitures', 'Cahiers');
select public.submit_expense(id) from public.expenses
where id::text like 'ffffffff%';

select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
create temp table approved_before as
select count(*)::int as n, sum(amount_cents)::bigint as ttc,
  sum(vat_cents)::bigint as vat
from public.expenses where status = 'approved';
select is((select n from approved_before), 3, 'three approved expenses');

select public.create_export(array(select id from public.expenses
  where status = 'approved'), 'b0000000-0000-0000-0000-0000000000c3', 'c3.csv');

select is(
  (select (expense_count, total_cents, vat_cents)::text
   from public.export_batches),
  (select (n, ttc, vat)::text from approved_before),
  'C3: the batch holds exactly the count, total and VAT that were approved');
select is((select count(*)::int from public.expenses
  where status = 'exported'), 3,
  'C3: every approved expense was exported exactly once');
select throws_ok($$select public.create_export(array(select id
    from public.expenses), 'b0000000-0000-0000-0000-0000000000c4', 'x.csv')$$,
  'P0001', null, 'C3: an exported expense cannot be exported again');

select pg_temp.as_admin();
select * from finish();
rollback;
