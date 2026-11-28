-- Export agent: accounting accounts per category and VAT totals per batch.
--
-- Each company sets the account (plan comptable) its accountant books
-- each category on; the CSV carries it. A batch now also keeps its VAT
-- total, so the app can check that the file holds exactly the totals the
-- server recorded.

create table public.category_accounts (
  company_id uuid not null references public.companies (id) on delete cascade,
  category text not null
    check (category in ('Repas', 'Transport', 'Hébergement', 'Fournitures',
      'Autre')),
  account_code text not null check (account_code ~ '^[0-9]{3,10}$'),
  primary key (company_id, category)
);

alter table public.category_accounts enable row level security;

create policy category_accounts_read on public.category_accounts
  for select to authenticated
  using (company_id = public.my_company_id());
create policy category_accounts_write on public.category_accounts
  for all to authenticated
  using (
    company_id = public.my_company_id()
    and public.my_role() in ('accountant', 'manager')
  )
  with check (
    company_id = public.my_company_id()
    and public.my_role() in ('accountant', 'manager')
  );

grant select, insert, update, delete on public.category_accounts
  to authenticated;

alter table public.export_batches
  add column vat_cents bigint not null default 0;

-- Same export as before; it also records the VAT total of the batch.
create or replace function public.create_export(
  p_ids uuid[], p_request_id uuid, p_file_name text
) returns public.export_batches
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_company uuid := public.my_company_id();
  v_batch public.export_batches;
  v_count integer;
  v_total bigint;
  v_vat bigint;
  v_name text;
begin
  if v_company is null or public.my_role() is distinct from 'accountant' then
    raise exception 'Cette action est réservée aux comptables.';
  end if;
  select * into v_batch from public.export_batches
  where company_id = v_company and request_id = p_request_id;
  if found then
    return v_batch;
  end if;

  perform 1 from public.expenses
  where id = any (p_ids) and company_id = v_company for update;
  select count(*), coalesce(sum(amount_cents), 0), coalesce(sum(vat_cents), 0)
  into v_count, v_total, v_vat
  from public.expenses
  where id = any (p_ids) and company_id = v_company and status = 'approved';
  if v_count = 0
     or v_count <> (select count(distinct x) from unnest(p_ids) as x) then
    raise exception
      'Seules des dépenses validées et non exportées peuvent être exportées.';
  end if;

  insert into public.export_batches
    (company_id, created_by, request_id, file_name, expense_count,
     total_cents, vat_cents)
  values
    (v_company, v_uid, p_request_id,
     left(regexp_replace(coalesce(p_file_name, ''), '[^A-Za-z0-9._-]', '_',
       'g'), 80),
     v_count, v_total, v_vat)
  returning * into v_batch;

  select full_name into v_name from public.profiles where id = v_uid;
  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name)
  select id, 'approved', 'exported', v_uid, 'human', coalesce(v_name, '')
  from public.expenses where id = any (p_ids);
  update public.expenses
  set status = 'exported', export_batch_id = v_batch.id
  where id = any (p_ids);
  return v_batch;
end $$;
