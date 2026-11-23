-- A WhatsApp number is linked by a one-time code sent from that number.
-- Run with: supabase test db
--
-- Sara asks for codes in the app; the webhook (service role, here the admin)
-- claims them with the number of the sender.

begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'sara@exemple.ma', now(),
   '{"full_name":"Sara Manager"}', now(), now());

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

-- What the app may and may not do ---------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select throws_ok($$insert into public.whatsapp_links (profile_id, phone)
  values (auth.uid(), '+212612345678')$$, '42501', null,
  'the app can no longer write a number itself');
select throws_ok('select * from public.whatsapp_link_codes', '42501', null,
  'the app cannot read the codes');
select throws_ok($$select public.claim_whatsapp_link('+212612345678', '123456')$$,
  '42501', null, 'only the server claims a code');
select matches((public.create_whatsapp_link_code()).code, '^\d{6}$',
  'the app gets a 6-digit code');
select set_config('rembo.first', (public.create_whatsapp_link_code()).code, true);
select set_config('rembo.code', (public.create_whatsapp_link_code()).code, true);

select pg_temp.as_admin();
select is((select count(*)::int from public.whatsapp_link_codes
  where profile_id = '11111111-1111-1111-1111-111111111111'), 1,
  'a new code replaces the previous one');
select ok((select expires_at between now() + interval '9 minutes'
    and now() + interval '10 minutes'
  from public.whatsapp_link_codes
  where profile_id = '11111111-1111-1111-1111-111111111111'),
  'a code is valid 10 minutes');

-- Claiming ----------------------------------------------------------------
select is(public.claim_whatsapp_link('+212612345678',
    current_setting('rembo.first')), 'invalid',
  'a replaced code no longer works');
select is(public.claim_whatsapp_link('+212612345678',
    current_setting('rembo.code')), 'linked',
  'the right code links the number');
select is((select phone from public.whatsapp_links
  where profile_id = '11111111-1111-1111-1111-111111111111'), '+212612345678',
  'the link holds the sender''s real number');
select is((select count(*)::int from public.whatsapp_link_codes), 0,
  'a used code is deleted');
select is(public.claim_whatsapp_link('+212699999999',
    current_setting('rembo.code')), 'invalid',
  'a used code cannot link a second number');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select count(*)::int from public.whatsapp_links), 1,
  'Sara sees her linked number');
select set_config('rembo.late', (public.create_whatsapp_link_code()).code, true);

select pg_temp.as_admin();
update public.whatsapp_link_codes set expires_at = now() - interval '1 minute';
select is(public.claim_whatsapp_link('+212612345678',
    current_setting('rembo.late')), 'expired',
  'an expired code is refused');
select is((select count(*)::int from public.whatsapp_link_codes), 0,
  'and deleted');

-- Guessing ------------------------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select set_config('rembo.live', (public.create_whatsapp_link_code()).code, true);
select pg_temp.as_admin();
select public.claim_whatsapp_link('+212688888888', 'wrong!')
from generate_series(1, 4);
select is(public.claim_whatsapp_link('+212688888888', 'wrong?'), 'invalid',
  'a sender may try 5 wrong codes');
select is(public.claim_whatsapp_link('+212688888888',
    current_setting('rembo.live')), 'too_many',
  'then even a right code is refused for an hour');
select is((select phone from public.whatsapp_links
  where profile_id = '11111111-1111-1111-1111-111111111111'), '+212612345678',
  'so the guessing number never takes the account');

-- Unlinking -------------------------------------------------------------------
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
delete from public.whatsapp_links where profile_id = auth.uid();
select is((select count(*)::int from public.whatsapp_links), 0,
  'Sara can still remove her number');

select pg_temp.as_admin();
select * from finish();
rollback;
