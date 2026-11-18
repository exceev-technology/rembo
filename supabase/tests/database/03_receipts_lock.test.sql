-- A submitted receipt is evidence: its owner can no longer replace or
-- delete it, until a manager rejects the expense. Run with: supabase test db
--
-- « Atelier Sara »: Sara and Karim managers. A refused update or delete
-- under row level security changes no row, so each step reads the file back.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'sara@exemple.ma', now(),
   '{"full_name":"Sara Manager"}', now(), now()),
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

create function pg_temp.version_of(p_name text) returns text
language sql as $$
  select metadata ->> 'v' from storage.objects
  where bucket_id = 'receipts' and name = p_name
$$;

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select isnt(public.create_company('Atelier Sara', '', 'Casablanca'), null,
  'Sara creates her company');
select lives_ok($$insert into public.invitations (company_id, email, role)
  values (public.my_company_id(), 'karim@exemple.ma', 'manager')$$,
  'Sara invites a second manager');
select pg_temp.as_user('66666666-6666-6666-6666-666666666666');
select ok(public.accept_invitation(), 'Karim joins as manager');

-- A receipt while its expense is a draft --------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason, receipt_path)
  values ('cccccccc-0000-0000-0000-000000000001', public.my_company_id(),
    auth.uid(), 'Café Atlas', current_date - 1, 4500, 'Repas',
    'Déjeuner client', '11111111-1111-1111-1111-111111111111/r1')$$,
  'Sara creates a draft with its receipt');
select lives_ok($$insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('receipts', '11111111-1111-1111-1111-111111111111/r1',
    auth.uid()::text, '{"v":"0"}')$$,
  'she stores the receipt');
update storage.objects set metadata = '{"v":"1"}'
  where name = '11111111-1111-1111-1111-111111111111/r1';
select is(pg_temp.version_of('11111111-1111-1111-1111-111111111111/r1'), '1',
  'a draft''s receipt can be replaced');

-- Once submitted, it is locked ----------------------------------------------
select is((public.submit_expense('cccccccc-0000-0000-0000-000000000001')).status,
  'approved'::public.expense_status,
  'the expense is submitted and approved by the control');
update storage.objects set metadata = '{"v":"2"}'
  where name = '11111111-1111-1111-1111-111111111111/r1';
select is(pg_temp.version_of('11111111-1111-1111-1111-111111111111/r1'), '1',
  'the receipt of a submitted expense cannot be replaced');
delete from storage.objects
  where name = '11111111-1111-1111-1111-111111111111/r1';
select is((select count(*)::int from storage.objects
  where name = '11111111-1111-1111-1111-111111111111/r1'), 1,
  'nor deleted');

-- A file attached to no expense stays the owner's ----------------------------
select lives_ok($$insert into storage.objects (bucket_id, name, owner_id)
  values ('receipts', '11111111-1111-1111-1111-111111111111/loose',
    auth.uid()::text)$$,
  'a file attached to no expense can be stored');
delete from storage.objects
  where name = '11111111-1111-1111-1111-111111111111/loose';
select is((select count(*)::int from storage.objects
  where name = '11111111-1111-1111-1111-111111111111/loose'), 0,
  'and deleted');

-- A rejected expense opens its receipt again ---------------------------------
select lives_ok($$insert into public.expenses (id, company_id, employee_id,
    supplier_name, expense_date, amount_cents, category, reason, receipt_path)
  values ('cccccccc-0000-0000-0000-000000000002', public.my_company_id(),
    auth.uid(), 'Imprimerie Atlas', current_date - 2, 9900, 'Autre',
    'Cartes de visite', '11111111-1111-1111-1111-111111111111/r2')$$,
  'Sara creates a second draft');
select lives_ok($$insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('receipts', '11111111-1111-1111-1111-111111111111/r2',
    auth.uid()::text, '{"v":"0"}')$$,
  'with its receipt');
select is((public.submit_expense('cccccccc-0000-0000-0000-000000000002')).status,
  'needs_review'::public.expense_status,
  'it waits for a manager');

select pg_temp.as_user('66666666-6666-6666-6666-666666666666');
select is((public.decide_expense('cccccccc-0000-0000-0000-000000000002',
    false, 'Ticket illisible')).status,
  'rejected'::public.expense_status,
  'Karim rejects it');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
update storage.objects set metadata = '{"v":"1"}'
  where name = '11111111-1111-1111-1111-111111111111/r2';
select is(pg_temp.version_of('11111111-1111-1111-1111-111111111111/r2'), '1',
  'the receipt of a rejected expense can be replaced');

select pg_temp.as_admin();
select * from finish();
rollback;
