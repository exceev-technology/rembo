-- REMBO core schema: companies, roles, expenses, automatic control,
-- manager decisions and accounting exports.
--
-- Principles
--   * Row level security on every table: nobody reads another company.
--   * The app never writes a status. Statuses move only through the
--     functions below, which check who is calling.
--   * Amounts are integer centimes of MAD.

create type public.member_role as enum ('employee', 'manager', 'accountant');
create type public.expense_status as enum
  ('draft', 'submitted', 'needs_review', 'approved', 'rejected', 'exported');

-- Tables ------------------------------------------------------------------

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) >= 2),
  ice text check (ice is null or ice ~ '^\d{15}$'),
  city text,
  currency text not null default 'MAD',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text not null default ''
);

create table public.memberships (
  company_id uuid not null references public.companies (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null default 'employee',
  created_at timestamptz not null default now(),
  primary key (company_id, profile_id)
);
-- MVP: a person belongs to one company.
create unique index memberships_one_company on public.memberships (profile_id);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  email text not null check (email = lower(email) and email like '%_@_%'),
  role public.member_role not null default 'employee',
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (company_id, email)
);

create table public.policies (
  company_id uuid not null references public.companies (id) on delete cascade,
  category text not null
    check (category in ('Repas', 'Transport', 'Hébergement', 'Fournitures')),
  limit_cents bigint not null check (limit_cents > 0),
  receipt_required boolean not null default true,
  primary key (company_id, category)
);

create table public.export_batches (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  created_by uuid not null references public.profiles (id),
  -- Chosen by the app: sending the same request twice returns this batch.
  request_id uuid not null,
  file_name text not null,
  expense_count integer not null,
  total_cents bigint not null,
  created_at timestamptz not null default now(),
  unique (company_id, request_id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  employee_id uuid not null references public.profiles (id),
  supplier_name text not null default '',
  supplier_ice text not null default '',
  expense_date date,
  amount_cents bigint not null default 0 check (amount_cents >= 0),
  vat_cents bigint not null default 0,
  category text not null default ''
    check (category in
      ('', 'Repas', 'Transport', 'Hébergement', 'Fournitures', 'Autre')),
  project text not null default '',
  reason text not null default '' check (length(reason) <= 200),
  status public.expense_status not null default 'draft',
  -- Object name in the private `receipts` bucket, inside the owner's folder.
  receipt_path text,
  -- Why the automatic control asked for a manager: [{kind, message}].
  flags jsonb not null default '[]'::jsonb,
  export_batch_id uuid references public.export_batches (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (vat_cents >= 0 and vat_cents <= amount_cents),
  check (receipt_path is null or receipt_path like employee_id::text || '/%')
);
create index expenses_company_status on public.expenses (company_id, status);
create index expenses_employee on public.expenses (employee_id, created_at desc);

create table public.status_events (
  id bigint generated always as identity primary key,
  expense_id uuid not null references public.expenses (id) on delete cascade,
  from_status public.expense_status,
  to_status public.expense_status not null,
  actor_id uuid references public.profiles (id) on delete set null,
  actor_kind text not null check (actor_kind in ('human', 'agent')),
  actor_name text not null default '',
  reason text,
  created_at timestamptz not null default now()
);
create index status_events_expense on public.status_events (expense_id);

-- Helpers -----------------------------------------------------------------
-- Security definer so that policies can read memberships without
-- recursing into the policies of memberships itself.

create function public.my_company_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select company_id from public.memberships where profile_id = auth.uid()
$$;

create function public.my_role() returns public.member_role
language sql stable security definer set search_path = '' as $$
  select role from public.memberships where profile_id = auth.uid()
$$;

create function public.format_mad(cents bigint) returns text
language sql immutable set search_path = '' as $$
  select (cents / 100)::text || ',' || lpad((cents % 100)::text, 2, '0')
    || ' MAD'
$$;

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger expenses_touch before update on public.expenses
  for each row execute function public.touch_updated_at();

-- A profile for every new account.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    lower(coalesce(new.email, ''))
  );
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row level security ------------------------------------------------------

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.invitations enable row level security;
alter table public.policies enable row level security;
alter table public.export_batches enable row level security;
alter table public.expenses enable row level security;
alter table public.status_events enable row level security;

create policy companies_read on public.companies for select to authenticated
  using (id = public.my_company_id());

create policy profiles_read on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.memberships m
      where m.profile_id = profiles.id
        and m.company_id = public.my_company_id()
    )
  );
create policy profiles_update_own on public.profiles for update
  to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy memberships_read on public.memberships for select
  to authenticated
  using (profile_id = auth.uid() or company_id = public.my_company_id());

create policy invitations_manage on public.invitations for all
  to authenticated
  using (
    company_id = public.my_company_id() and public.my_role() = 'manager'
  )
  with check (
    company_id = public.my_company_id() and public.my_role() = 'manager'
  );

create policy policies_read on public.policies for select to authenticated
  using (company_id = public.my_company_id());
create policy policies_insert on public.policies for insert to authenticated
  with check (
    company_id = public.my_company_id() and public.my_role() = 'manager'
  );
create policy policies_update on public.policies for update to authenticated
  using (
    company_id = public.my_company_id() and public.my_role() = 'manager'
  )
  with check (
    company_id = public.my_company_id() and public.my_role() = 'manager'
  );

create policy export_batches_read on public.export_batches for select
  to authenticated
  using (
    company_id = public.my_company_id() and public.my_role() = 'accountant'
  );

-- Expenses: one's own; a manager sees what was submitted in the company;
-- an accountant sees what is approved or exported.
create policy expenses_read on public.expenses for select to authenticated
  using (
    employee_id = auth.uid()
    or (
      company_id = public.my_company_id()
      and (
        (public.my_role() = 'manager' and status <> 'draft')
        or (public.my_role() = 'accountant'
            and status in ('approved', 'exported'))
      )
    )
  );
create policy expenses_insert on public.expenses for insert to authenticated
  with check (
    employee_id = auth.uid()
    and company_id = public.my_company_id()
    and status = 'draft'
  );
create policy expenses_update on public.expenses for update to authenticated
  using (employee_id = auth.uid() and status in ('draft', 'rejected'))
  with check (employee_id = auth.uid() and status in ('draft', 'rejected'));
create policy expenses_delete on public.expenses for delete to authenticated
  using (employee_id = auth.uid() and status = 'draft');

-- The history is visible with its expense (the sub-query runs under the
-- reader's own rights).
create policy status_events_read on public.status_events for select
  to authenticated
  using (
    exists (
      select 1 from public.expenses e
      where e.id = status_events.expense_id
    )
  );

-- Privileges --------------------------------------------------------------
-- Nothing for visitors. Signed-in people get exactly what the app needs;
-- status, flags, export batch and owner are not writable columns.

revoke all on all tables in schema public from anon, authenticated;

grant select on public.companies, public.memberships, public.policies,
  public.export_batches, public.expenses, public.status_events,
  public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;
grant select, insert, delete on public.invitations to authenticated;
grant insert, update on public.policies to authenticated;
grant insert (id, company_id, employee_id, supplier_name, supplier_ice,
    expense_date, amount_cents, vat_cents, category, project, reason,
    receipt_path)
  on public.expenses to authenticated;
grant update (supplier_name, supplier_ice, expense_date, amount_cents,
    vat_cents, category, project, reason, receipt_path)
  on public.expenses to authenticated;
grant delete on public.expenses to authenticated;

-- Functions the app calls -------------------------------------------------
-- Messages raised here are shown to the user as they are.

-- Creates a company; the caller becomes its first manager.
create function public.create_company(p_name text, p_ice text, p_city text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_company uuid;
begin
  if v_uid is null then
    raise exception 'Session expirée. Reconnectez-vous.';
  end if;
  if exists (select 1 from public.memberships where profile_id = v_uid) then
    raise exception 'Vous appartenez déjà à une entreprise.';
  end if;
  insert into public.companies (name, ice, city, created_by)
  values (trim(p_name), nullif(trim(p_ice), ''), nullif(trim(p_city), ''),
    v_uid)
  returning id into v_company;
  insert into public.memberships (company_id, profile_id, role)
  values (v_company, v_uid, 'manager');
  insert into public.policies (company_id, category, limit_cents,
    receipt_required)
  values
    (v_company, 'Repas', 20000, true),
    (v_company, 'Transport', 50000, false),
    (v_company, 'Hébergement', 120000, true),
    (v_company, 'Fournitures', 100000, false);
  return v_company;
end $$;

-- Joins the company that invited the caller's confirmed e-mail address.
create function public.accept_invitation() returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_inv public.invitations;
begin
  if v_uid is null then
    return false;
  end if;
  if exists (select 1 from public.memberships where profile_id = v_uid) then
    return false;
  end if;
  select lower(email) into v_email from auth.users
  where id = v_uid and email_confirmed_at is not null;
  if v_email is null then
    return false;
  end if;
  select * into v_inv from public.invitations
  where email = v_email order by created_at limit 1;
  if not found then
    return false;
  end if;
  insert into public.memberships (company_id, profile_id, role)
  values (v_inv.company_id, v_uid, v_inv.role);
  delete from public.invitations where email = v_email;
  return true;
end $$;

-- Submission and automatic control. A compliant expense is approved by the
-- agent; anything else waits for a manager. Calling it again is harmless.
-- [p_actor] is the person submitting: the app passes through
-- submit_expense(); only the server (service role) may name someone else,
-- e.g. when the owner confirms by WhatsApp.
create function public.control_expense(p_id uuid, p_actor uuid)
returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := p_actor;
  e public.expenses;
  v_rule public.policies;
  v_flags jsonb := '[]'::jsonb;
  v_status public.expense_status;
  v_name text;
begin
  select * into e from public.expenses where id = p_id for update;
  if not found or e.employee_id is distinct from v_uid then
    raise exception 'Vous ne pouvez soumettre que vos dépenses.';
  end if;
  if e.status not in ('draft', 'rejected') then
    return e;
  end if;
  if trim(e.supplier_name) = '' or e.expense_date is null
     or e.amount_cents <= 0 or e.category = '' or trim(e.reason) = '' then
    raise exception
      'Complétez le fournisseur, la date, le montant, la catégorie et le motif.';
  end if;
  if e.expense_date > current_date then
    raise exception 'La date de la dépense est dans le futur.';
  end if;

  select * into v_rule from public.policies
  where company_id = e.company_id and category = e.category;
  if found then
    if e.amount_cents > v_rule.limit_cents then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Plafond ' || e.category || ' dépassé de '
        || public.format_mad(e.amount_cents - v_rule.limit_cents));
    end if;
    if v_rule.receipt_required and coalesce(e.receipt_path, '') = '' then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Justificatif manquant');
    end if;
  end if;
  if exists (
    select 1 from public.expenses o
    where o.id <> e.id and o.employee_id = e.employee_id
      and o.expense_date = e.expense_date
      and o.amount_cents = e.amount_cents
      and o.status not in ('draft', 'rejected')
  ) then
    v_flags := v_flags || jsonb_build_object('kind', 'duplicate', 'message',
      'Même date et même montant qu’une dépense déjà déclarée');
  end if;
  if e.category = 'Autre' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Catégorie à préciser');
  end if;
  if current_date - e.expense_date > 60 then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense datée de plus de 60 jours');
  end if;

  v_status := case when v_flags = '[]'::jsonb
    then 'approved' else 'needs_review' end;
  select full_name into v_name from public.profiles where id = v_uid;

  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     created_at)
  values
    (e.id, e.status, 'submitted', v_uid, 'human', coalesce(v_name, ''),
     clock_timestamp());
  insert into public.status_events
    (expense_id, from_status, to_status, actor_kind, actor_name, created_at)
  values
    (e.id, 'submitted', v_status, 'agent', 'Contrôle automatique',
     clock_timestamp());
  update public.expenses set status = v_status, flags = v_flags
  where id = e.id returning * into e;
  return e;
end $$;

create function public.submit_expense(p_id uuid) returns public.expenses
language sql security definer set search_path = '' as $$
  select * from public.control_expense(p_id, auth.uid())
$$;

-- Manager decision. Never on one's own expense; a rejection needs a reason.
create function public.decide_expense(
  p_id uuid, p_approve boolean, p_reason text
) returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  e public.expenses;
  v_status public.expense_status;
  v_name text;
begin
  select * into e from public.expenses where id = p_id for update;
  if not found
     or e.company_id is distinct from public.my_company_id()
     or public.my_role() is distinct from 'manager' then
    raise exception 'Cette action est réservée aux responsables.';
  end if;
  if e.employee_id = v_uid then
    raise exception 'Vous ne pouvez pas décider de votre propre dépense.';
  end if;
  if e.status <> 'needs_review' then
    raise exception 'Cette dépense a déjà été traitée.';
  end if;
  if not p_approve and trim(coalesce(p_reason, '')) = '' then
    raise exception 'Le motif du rejet est obligatoire.';
  end if;
  v_status := case when p_approve then 'approved' else 'rejected' end;
  select full_name into v_name from public.profiles where id = v_uid;
  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     reason)
  values
    (e.id, e.status, v_status, v_uid, 'human', coalesce(v_name, ''),
     nullif(left(trim(coalesce(p_reason, '')), 200), ''));
  update public.expenses set status = v_status
  where id = e.id returning * into e;
  return e;
end $$;

-- Accounting export: all the expenses or none. The same request id always
-- returns the same batch, so a retry never exports twice.
create function public.create_export(
  p_ids uuid[], p_request_id uuid, p_file_name text
) returns public.export_batches
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_company uuid := public.my_company_id();
  v_batch public.export_batches;
  v_count integer;
  v_total bigint;
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
  select count(*), coalesce(sum(amount_cents), 0) into v_count, v_total
  from public.expenses
  where id = any (p_ids) and company_id = v_company and status = 'approved';
  if v_count = 0
     or v_count <> (select count(distinct x) from unnest(p_ids) as x) then
    raise exception
      'Seules des dépenses validées et non exportées peuvent être exportées.';
  end if;

  insert into public.export_batches
    (company_id, created_by, request_id, file_name, expense_count,
     total_cents)
  values
    (v_company, v_uid, p_request_id,
     left(regexp_replace(coalesce(p_file_name, ''), '[^A-Za-z0-9._-]', '_',
       'g'), 80),
     v_count, v_total)
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

revoke execute on all functions in schema public
  from public, anon, authenticated;
grant execute on function public.control_expense(uuid, uuid) to service_role;
grant execute on function
  public.my_company_id(), public.my_role(), public.format_mad(bigint),
  public.create_company(text, text, text), public.accept_invitation(),
  public.submit_expense(uuid), public.decide_expense(uuid, boolean, text),
  public.create_export(uuid[], uuid, text)
  to authenticated;

-- Receipts ----------------------------------------------------------------
-- Private bucket. Each person writes in a folder named after their id; a
-- receipt can be read by whoever can read the expense it belongs to.

insert into storage.buckets (id, name, public, file_size_limit,
  allowed_mime_types)
values ('receipts', 'receipts', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

create policy receipts_insert_own on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy receipts_update_own on storage.objects for update
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy receipts_delete_own on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy receipts_read on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.expenses e
        where e.receipt_path = objects.name
      )
    )
  );
