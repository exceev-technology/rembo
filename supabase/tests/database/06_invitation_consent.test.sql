-- An invitation is shown first, and joined only on the person's answer.
-- Run with: supabase test db
--
-- « Atelier Sara » invites Omar (confirmed address) and Nora (unconfirmed).
-- Zed is invited by nobody.

begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'sara@exemple.ma', now(),
   '{"full_name":"Sara Manager"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'omar@exemple.ma', now(),
   '{"full_name":"Omar Employee"}', now(), now()),
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

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select isnt(public.create_company('Atelier Sara', '', 'Casablanca'), null,
  'Sara creates her company');
select lives_ok($$insert into public.invitations (company_id, email, role)
  values (public.my_company_id(), 'omar@exemple.ma', 'accountant'),
         (public.my_company_id(), 'nora@exemple.ma', 'employee')$$,
  'Sara invites Omar and Nora');
select is((select count(*)::int from public.my_invitation()), 0,
  'a member of a company has no invitation waiting');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is((select company_name from public.my_invitation()), 'Atelier Sara',
  'Omar sees which company invites him');
select is((select role from public.my_invitation()),
  'accountant'::public.member_role, 'and with which role');
select is((select count(*)::int from public.memberships), 0,
  'seeing the invitation joins nothing');

select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
select is((select count(*)::int from public.my_invitation()), 0,
  'an unconfirmed address sees no invitation');

select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from public.my_invitation()), 0,
  'nobody sees the invitation of someone else');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
-- Two statements: my_invitation() is stable, so within the statement that
-- accepts it would still see the invitation as it was.
select ok(public.accept_invitation(), 'Omar accepts the invitation');
select is((select count(*)::int from public.my_invitation()), 0,
  'once Omar has accepted, nothing waits any more');

select set_config('role', 'postgres', true);
select * from finish();
rollback;
