-- An invited person joins a company only when they say so: the app shows
-- the invitation and calls accept_invitation() on their answer, instead of
-- joining at the first sign-in.

-- The invitation waiting for the signed-in person: their confirmed e-mail
-- address is invited and they belong to no company yet. Empty otherwise.
create function public.my_invitation()
returns table (company_name text, role public.member_role)
language sql stable security definer set search_path = '' as $$
  select c.name, i.role
  from public.invitations i
  join public.companies c on c.id = i.company_id
  join auth.users u on lower(u.email) = i.email
  where u.id = auth.uid()
    and u.email_confirmed_at is not null
    and not exists (
      select 1 from public.memberships m where m.profile_id = auth.uid()
    )
  order by i.created_at
  limit 1
$$;

revoke execute on function public.my_invitation() from public, anon;
grant execute on function public.my_invitation() to authenticated;
