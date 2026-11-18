-- The daily allowance of server readings. Run with: supabase test db
--
-- The read-receipt function (service role, here the admin) takes one reading
-- per request; Sara's allowance is 2 in this test.

begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'sara@exemple.ma', now(),
   '{"full_name":"Sara Manager"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'omar@exemple.ma', now(),
   '{"full_name":"Omar Employee"}', now(), now());

select ok(public.take_receipt_reading('11111111-1111-1111-1111-111111111111', 2),
  'a first reading is allowed');
select ok(public.take_receipt_reading('11111111-1111-1111-1111-111111111111', 2),
  'a second one too');
select ok(not public.take_receipt_reading('11111111-1111-1111-1111-111111111111', 2),
  'the third one is refused');
select is((select count(*)::int from public.receipt_readings
  where profile_id = '11111111-1111-1111-1111-111111111111'), 2,
  'a refused reading is not counted');
select ok(public.take_receipt_reading('22222222-2222-2222-2222-222222222222', 2),
  'each person has their own allowance');

update public.receipt_readings set created_at = now() - interval '25 hours'
  where profile_id = '11111111-1111-1111-1111-111111111111';
select ok(public.take_receipt_reading('11111111-1111-1111-1111-111111111111', 2),
  'readings older than 24 hours no longer count');

select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111',
    'role', 'authenticated')::text, true);
set local role authenticated;
select throws_ok($$select public.take_receipt_reading(
    '11111111-1111-1111-1111-111111111111', 1000)$$, '42501', null,
  'the app cannot take readings itself');
reset role;

select * from finish();
rollback;
