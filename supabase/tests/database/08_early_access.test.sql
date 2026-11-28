-- Sprint 5 · Early access from the public site.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

set local role anon;
select ok(public.join_early_access('Fatima@Atelier.ma', 'Atelier Fès',
  'dirigeant', '10-49', 'Fès', true), 'a visitor signs up with consent');
select ok(public.join_early_access('fatima@atelier.ma', 'Autre nom', '', '',
  '', true), 'signing up again answers the same, without telling');
select throws_ok($$select public.join_early_access('x@y.ma', 'Société', '',
  '', '', false)$$, 'P0001', null, 'no consent, no sign-up');
select throws_ok($$select public.join_early_access('pas-une-adresse',
  'Société', '', '', '', true)$$, 'P0001',
  'Vérifiez l’adresse e-mail et le nom de l’entreprise.',
  'a malformed address is refused');
select throws_ok($$select count(*) from public.early_access$$, '42501', null,
  'a visitor cannot read the list');
select throws_ok($$insert into public.early_access (email, company)
  values ('a@b.ma', 'Direct')$$, '42501', null,
  'nor write in it directly');

reset role;
select is((select company || ' · ' || email from public.early_access),
  'Atelier Fès · fatima@atelier.ma',
  'one entry, the first one, address in lower case');

select * from finish();
rollback;
