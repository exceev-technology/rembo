-- Fictional data for a LOCAL test project (supabase db reset).
-- Never run this on a project that holds real data.
--
-- Two companies, one person per role, and expenses in every status. The
-- statuses are reached through the real functions (submit, decide,
-- export), as each person: the seed also checks that the rules hold.
--
-- Every account signs in with the password  Rembo-2026!
--
--   Atlas Conseil   sara@atlas.test     manager
--                   karim@atlas.test    manager
--                   omar@atlas.test     employee
--                   salma@atlas.test    employee
--                   lina@atlas.test     accountant
--   Autre SARL      zed@autre.test      manager

-- People ---------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at,
  updated_at, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, reauthentication_token)
select '00000000-0000-0000-0000-000000000000', p.id, 'authenticated',
  'authenticated', p.email, extensions.crypt('Rembo-2026!',
  extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  json_build_object('full_name', p.name), now(), now(), '', '', '', '', '', ''
from (values
  ('a0000000-0000-0000-0000-000000000001'::uuid, 'sara@atlas.test', 'Sara Bennani'),
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'karim@atlas.test', 'Karim Alaoui'),
  ('a0000000-0000-0000-0000-000000000003'::uuid, 'omar@atlas.test', 'Omar Idrissi'),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 'salma@atlas.test', 'Salma Tazi'),
  ('a0000000-0000-0000-0000-000000000005'::uuid, 'lina@atlas.test', 'Lina Chraibi'),
  ('a0000000-0000-0000-0000-000000000006'::uuid, 'zed@autre.test', 'Zed Ouazzani')
) as p (id, email, name);

insert into auth.identities (id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
  json_build_object('sub', u.id::text, 'email', u.email,
    'email_verified', true),
  now(), now(), now()
from auth.users u where u.email like '%.test';

-- Acts as one person for the next statements, like the app would.
create function pg_temp.as_user(p_uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, false);
$$;

-- Companies and roles ------------------------------------------------------
select pg_temp.as_user('a0000000-0000-0000-0000-000000000001');
select public.create_company('Atlas Conseil', '001234567000089', 'Casablanca');
select pg_temp.as_user('a0000000-0000-0000-0000-000000000006');
select public.create_company('Autre SARL', '', 'Rabat');

insert into public.memberships (company_id, profile_id, role)
select c.id, m.profile_id, m.role::public.member_role
from public.companies c, (values
  ('a0000000-0000-0000-0000-000000000002'::uuid, 'manager'),
  ('a0000000-0000-0000-0000-000000000003'::uuid, 'employee'),
  ('a0000000-0000-0000-0000-000000000004'::uuid, 'employee'),
  ('a0000000-0000-0000-0000-000000000005'::uuid, 'accountant')
) as m (profile_id, role)
where c.name = 'Atlas Conseil';

-- Expenses -----------------------------------------------------------------
-- Drafts written as their owner would; then submitted through the control.
insert into public.expenses (id, company_id, employee_id, supplier_name,
  supplier_ice, expense_date, amount_cents, vat_cents, category, project,
  reason)
select e.id, c.id, e.employee, e.supplier, e.ice, current_date - e.days_ago,
  e.amount, e.vat, e.category, e.project, e.reason
from public.companies c, (values
  -- Omar
  ('e0000000-0000-0000-0000-000000000001'::uuid,
   'a0000000-0000-0000-0000-000000000003'::uuid, 'Taxi Bleu', '', 1,
   4500, 0, 'Transport', 'Client Atlas', 'Trajet vers le client'),
  ('e0000000-0000-0000-0000-000000000002'::uuid,
   'a0000000-0000-0000-0000-000000000003'::uuid, 'Café Atlas', '', 2,
   24000, 2182, 'Repas', 'Mission Rabat', 'Déjeuner client'),
  ('e0000000-0000-0000-0000-000000000003'::uuid,
   'a0000000-0000-0000-0000-000000000003'::uuid, 'Librairie Nationale',
   '002345678000012', 3, 18000, 3000, 'Fournitures', '', 'Cahiers et stylos'),
  ('e0000000-0000-0000-0000-000000000004'::uuid,
   'a0000000-0000-0000-0000-000000000003'::uuid, 'Hôtel Farah', '', 5,
   95000, 8636, 'Hébergement', 'Mission Tanger', 'Nuit à Tanger'),
  -- Salma
  ('e0000000-0000-0000-0000-000000000005'::uuid,
   'a0000000-0000-0000-0000-000000000004'::uuid, 'ONCF', '', 4,
   24900, 0, 'Transport', 'Mission Rabat', 'Train Al Boraq'),
  ('e0000000-0000-0000-0000-000000000006'::uuid,
   'a0000000-0000-0000-0000-000000000004'::uuid, 'Restaurant Le Jardin', '', 6,
   12000, 1091, 'Repas', '', 'Repas d''équipe'),
  ('e0000000-0000-0000-0000-000000000007'::uuid,
   'a0000000-0000-0000-0000-000000000004'::uuid, 'Divers', '', 7,
   6000, 0, 'Autre', '', 'Achat à préciser'),
  -- A draft left as is
  ('e0000000-0000-0000-0000-000000000008'::uuid,
   'a0000000-0000-0000-0000-000000000003'::uuid, 'Pâtisserie Bennis', '', 0,
   3500, 0, '', '', '')
) as e (id, employee, supplier, ice, days_ago, amount, vat, category, project,
  reason)
where c.name = 'Atlas Conseil';

-- Submissions, each by its owner (the control runs on the server).
select public.control_expense(id, employee_id)
from public.expenses
where id <> 'e0000000-0000-0000-0000-000000000008'
order by expense_date;

-- Karim decides what waits for a manager, except what is left for the
-- demo: the café over its limit, the hotel without receipt, « Divers » to
-- clarify and the compliant train ticket, to confirm in one gesture.
select pg_temp.as_user('a0000000-0000-0000-0000-000000000002');
select public.approve_compliant(array[
  'e0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000003']::uuid[]);
select public.decide_expense('e0000000-0000-0000-0000-000000000006', false,
  'Repas d''équipe : joindre la liste des participants.')
where exists (select 1 from public.expenses
  where id = 'e0000000-0000-0000-0000-000000000006'
    and status = 'needs_review');

-- Lina exports the approved transport and supplies.
select pg_temp.as_user('a0000000-0000-0000-0000-000000000005');
select public.create_export(
  array(select id from public.expenses
        where status = 'approved'
          and id in ('e0000000-0000-0000-0000-000000000001',
                     'e0000000-0000-0000-0000-000000000003')),
  'b0000000-0000-0000-0000-000000000001', 'rembo_seed.csv')
where exists (select 1 from public.expenses
  where status = 'approved'
    and id in ('e0000000-0000-0000-0000-000000000001',
               'e0000000-0000-0000-0000-000000000003'));

select set_config('request.jwt.claims', '', false);
