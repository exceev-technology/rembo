-- Sprint 5 · Compliance agent: VAT, ICE, near duplicates, currencies.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
  'sara@exemple.ma', now(), '{"full_name":"Sara Manager"}', now(), now());

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

-- A Transport expense (no receipt needed, limit 500 MAD), then submitted.
create function pg_temp.submit(p_id uuid, p_supplier text, p_days int,
  p_amount int, p_vat int, p_rate int, p_ice text, p_currency text,
  p_paid int) returns jsonb
language sql as $$
  insert into public.expenses (id, company_id, employee_id, supplier_name,
    supplier_ice, expense_date, amount_cents, vat_cents, vat_rate, currency,
    foreign_amount_cents, category, reason)
  values (p_id, public.my_company_id(), auth.uid(), p_supplier, p_ice,
    current_date - p_days, p_amount, p_vat, p_rate, p_currency, p_paid,
    'Transport', 'Mission');
  select (public.submit_expense(p_id)).flags;
$$;

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.create_company('Atelier Sara', '', 'Casablanca');
-- Sara, the manager, declares her own expenses in these tests.
select public.set_managers_declare(true);

select is(pg_temp.submit('dddddddd-0000-0000-0000-000000000001', 'Station Afriquia',
    5, 49875, 6125, 14, '001234567000089', 'MAD', null), '[]'::jsonb,
  'VAT matching its rate and a valid ICE: nothing to report');

select ok(pg_temp.submit('dddddddd-0000-0000-0000-000000000002', 'Station Ziz',
    10, 40000, 2000, 20, '', 'MAD', null)
  @> '[{"message": "TVA incohérente avec le taux indiqué"}]',
  'a VAT far from what its rate gives is reported');

select ok(pg_temp.submit('dddddddd-0000-0000-0000-000000000003', 'Station Winxo',
    11, 30000, 0, null, '12345', 'MAD', null)
  @> '[{"message": "ICE du fournisseur invalide : 15 chiffres attendus"}]',
  'an ICE that is not 15 digits is reported');

select ok(pg_temp.submit('dddddddd-0000-0000-0000-000000000004', 'station  AFRIQUIA',
    3, 49875, 0, null, '', 'MAD', null)
  @> '[{"kind": "duplicate", "message": "Même fournisseur et même montant à quelques jours d’intervalle"}]',
  'the same supplier and amount two days apart is a likely duplicate');

select is(pg_temp.submit('dddddddd-0000-0000-0000-000000000005', 'Station Afriquia',
    20, 49875, 0, null, '', 'MAD', null), '[]'::jsonb,
  'the same amount weeks later is not a duplicate');

select throws_ok($$select pg_temp.submit('dddddddd-0000-0000-0000-000000000006',
    'Uber Paris', 1, 22000, 0, null, '', 'EUR', null)$$,
  'P0001', 'Indiquez le montant payé en devise.',
  'a receipt in euros needs the amount paid in euros');

select pg_temp.as_admin();
delete from public.expenses where id = 'dddddddd-0000-0000-0000-000000000006';
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');

select ok(pg_temp.submit('dddddddd-0000-0000-0000-000000000007', 'Uber Paris',
    1, 22000, 0, null, '', 'EUR', 2000)
  @> '[{"message": "Dépense en devise : conversion en dirhams à vérifier"}]',
  'a receipt in euros goes to a manager to check the conversion');

update public.expenses set vat_rate = 7
  where id = 'dddddddd-0000-0000-0000-000000000001';
select is((select vat_rate from public.expenses
  where id = 'dddddddd-0000-0000-0000-000000000001'), 14::smallint,
  'a submitted expense cannot be changed by its owner');

select pg_temp.as_admin();
select throws_ok($$update public.expenses set vat_rate = 15
  where id = 'dddddddd-0000-0000-0000-000000000001'$$, '23514', null,
  'only Moroccan VAT rates are accepted');

select * from finish();
rollback;
