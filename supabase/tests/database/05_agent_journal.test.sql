-- Sprint 5 · What the agents proposed, and what people kept.
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
select id, '22222222-2222-2222-2222-222222222222'::uuid,
  'employee'::public.member_role
from public.companies where name = 'Atelier Sara';

-- Omar photographed a receipt 90 seconds ago; the agents proposed three
-- fields. He keeps the supplier and the category, corrects the amount.
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
insert into public.expenses (id, company_id, employee_id, supplier_name,
  expense_date, amount_cents, category, reason, agent_proposal,
  capture_started_at)
values ('eeeeeeee-0000-0000-0000-000000000001', public.my_company_id(),
  auth.uid(), 'Café Atlas', current_date - 1, 25000, 'Repas',
  'Déjeuner client',
  '{"engine": "device", "fields": {
     "supplier": {"value": "Café Atlas", "confidence": "medium", "agent": "reading"},
     "amount": {"value": "24000", "confidence": "low", "agent": "reading"},
     "category": {"value": "repas", "confidence": "medium", "agent": "classification"}}}',
  now() - interval '90 seconds');

update public.expenses
set agent_proposal = '{"engine": "server", "fields": {}}',
  capture_started_at = now()
where id = 'eeeeeeee-0000-0000-0000-000000000001';
select is((select agent_proposal ->> 'engine' from public.expenses
  where id = 'eeeeeeee-0000-0000-0000-000000000001'), 'device',
  'what the agents proposed cannot be rewritten afterwards');

select is((select count(*)::int from public.agent_metrics), 0,
  'a draft is not measured yet');
select public.submit_expense('eeeeeeee-0000-0000-0000-000000000001');

select is((select proposed from public.agent_metrics), 3,
  'three fields were proposed');
select is((select accepted from public.agent_metrics), 2,
  'two were kept as they were (case does not matter)');
select is((select corrected_fields from public.agent_metrics), '{amount}',
  'the amount was corrected');
select ok((select declare_seconds from public.agent_metrics) between 89 and 600,
  'the time to declare runs from the capture to the submission');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select count(*)::int from public.agent_metrics), 1,
  'the manager sees the measures of the team');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select is((select count(*)::int from public.agent_metrics), 0,
  'another company sees none');

select pg_temp.as_admin();
select * from finish();
rollback;
