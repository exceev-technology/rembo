-- The WhatsApp conversation (20261128010000_whatsapp_conversation): only
-- the webhook reads it, and it forgets turns older than 30 days.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000',
  '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
  'omar@exemple.ma', now(), '{"full_name": "Omar Employee"}', now(), now());

insert into public.whatsapp_turns (profile_id, author, body, created_at)
values ('22222222-2222-2222-2222-222222222222', 'person', 'Taxi 45 DH',
  now() - interval '40 days');
insert into public.whatsapp_turns (profile_id, author, body)
values ('22222222-2222-2222-2222-222222222222', 'person',
  'Il manque le client Marjane');

select is((select count(*) from public.whatsapp_turns
  where profile_id = '22222222-2222-2222-2222-222222222222'), 1::bigint,
  'a turn older than 30 days is forgotten at the next one');
select throws_ok($$insert into public.whatsapp_turns (profile_id, author, body)
  values ('22222222-2222-2222-2222-222222222222', 'someone', 'x')$$,
  '23514', null, 'a turn is from the person or from REMBO');

select set_config('request.jwt.claims',
  '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}',
  true);
select set_config('role', 'authenticated', true);
select throws_ok($$select * from public.whatsapp_turns$$, '42501', null,
  'a signed-in person cannot read the conversations');
select throws_ok($$insert into public.whatsapp_turns (profile_id, author, body)
  values (auth.uid(), 'person', 'x')$$, '42501', null,
  'nor write in them');

select * from finish();
rollback;
