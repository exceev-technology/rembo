-- Early access: companies that want to try REMBO, from the public site.
--
-- Visitors (anon key, no account) may only call join_early_access(): they
-- can neither read the list nor learn whether an address is already on it.
-- The team reads it from the Supabase dashboard (service role). Personal
-- data under law 09-08: only what is needed to call back, with consent,
-- and deleted on request (see docs/wiki/Traction.md).

create table public.early_access (
  id bigint generated always as identity primary key,
  email text not null unique
    check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
      and length(email) <= 200),
  company text not null check (length(trim(company)) between 2 and 120),
  role text not null default ''
    check (role in ('', 'dirigeant', 'rh', 'comptable', 'collaborateur',
      'cabinet', 'autre')),
  team_size text not null default ''
    check (team_size in ('', '1-9', '10-49', '50-249', '250+')),
  city text not null default '' check (length(city) <= 80),
  consent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.early_access enable row level security;
revoke all on public.early_access from anon, authenticated;

-- Always answers true: a second sign-up of the same address is ignored,
-- without telling the visitor that it was already there.
create function public.join_early_access(
  p_email text, p_company text, p_role text, p_team_size text, p_city text,
  p_consent boolean
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(p_consent, false) then
    raise exception 'Le consentement est nécessaire pour vous recontacter.';
  end if;
  insert into public.early_access (email, company, role, team_size, city)
  values (lower(trim(p_email)), trim(p_company), coalesce(p_role, ''),
    coalesce(p_team_size, ''), left(trim(coalesce(p_city, '')), 80))
  on conflict (email) do nothing;
  return true;
exception
  when check_violation then
    raise exception 'Vérifiez l’adresse e-mail et le nom de l’entreprise.';
end $$;

revoke execute on function public.join_early_access(text, text, text, text,
  text, boolean) from public;
grant execute on function public.join_early_access(text, text, text, text,
  text, boolean) to anon, authenticated;
