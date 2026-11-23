-- A WhatsApp number is linked only by proof that the person holds it: the
-- app asks for a one-time code, the person sends « LIER 123456 » from that
-- number, and the `whatsapp-webhook` function links the sender's real
-- number. The app can no longer write a number itself.

revoke insert, update on public.whatsapp_links from authenticated;

-- One live code per person, 6 digits, valid 10 minutes. Read and written by
-- the functions below only.
create table public.whatsapp_link_codes (
  profile_id uuid primary key references public.profiles (id)
    on delete cascade,
  code text not null unique check (code ~ '^\d{6}$'),
  expires_at timestamptz not null
);
alter table public.whatsapp_link_codes enable row level security;
revoke all on public.whatsapp_link_codes from anon, authenticated;

-- Wrong codes sent from a number: a sender gets 5 tries per hour, so a
-- code cannot be guessed (1 chance in 200 000 per hour).
create table public.whatsapp_link_attempts (
  id bigint generated always as identity primary key,
  phone text not null,
  created_at timestamptz not null default now()
);
create index whatsapp_link_attempts_phone
  on public.whatsapp_link_attempts (phone, created_at desc);
alter table public.whatsapp_link_attempts enable row level security;
revoke all on public.whatsapp_link_attempts from anon, authenticated;

-- A new code for the signed-in person; the previous one stops working.
create function public.create_whatsapp_link_code()
returns public.whatsapp_link_codes
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_bytes bytea;
  v_code text;
  v_row public.whatsapp_link_codes;
begin
  if v_uid is null then
    raise exception 'Session expirée. Reconnectez-vous.';
  end if;
  delete from public.whatsapp_link_codes
  where profile_id = v_uid or expires_at < now();
  loop
    v_bytes := extensions.gen_random_bytes(4);
    v_code := lpad(((
      (get_byte(v_bytes, 0)::bigint << 24) | (get_byte(v_bytes, 1)::bigint << 16)
      | (get_byte(v_bytes, 2)::bigint << 8) | get_byte(v_bytes, 3)::bigint
    ) % 1000000)::text, 6, '0');
    begin
      insert into public.whatsapp_link_codes (profile_id, code, expires_at)
      values (v_uid, v_code, now() + interval '10 minutes')
      returning * into v_row;
      return v_row;
    exception when unique_violation then
      -- Another person holds this code right now: draw again.
    end;
  end loop;
end $$;

-- Called by the webhook with the sender's real number. Returns 'linked',
-- 'expired', 'invalid' or 'too_many'. A code is used once: found, it is
-- deleted whatever happens next.
create function public.claim_whatsapp_link(p_phone text, p_code text)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.whatsapp_link_codes;
begin
  if (select count(*) from public.whatsapp_link_attempts
      where phone = p_phone and created_at > now() - interval '1 hour') >= 5 then
    return 'too_many';
  end if;
  select * into v_row from public.whatsapp_link_codes
  where code = p_code for update;
  if not found then
    insert into public.whatsapp_link_attempts (phone) values (p_phone);
    return 'invalid';
  end if;
  delete from public.whatsapp_link_codes where profile_id = v_row.profile_id;
  if v_row.expires_at < now() then
    return 'expired';
  end if;
  -- The sender proved the number is theirs: it moves to this account.
  delete from public.whatsapp_links
  where phone = p_phone or profile_id = v_row.profile_id;
  insert into public.whatsapp_links (profile_id, phone)
  values (v_row.profile_id, p_phone);
  return 'linked';
end $$;

revoke execute on function public.create_whatsapp_link_code()
  from public, anon;
grant execute on function public.create_whatsapp_link_code() to authenticated;
revoke execute on function public.claim_whatsapp_link(text, text)
  from public, anon, authenticated;
grant execute on function public.claim_whatsapp_link(text, text)
  to service_role;
