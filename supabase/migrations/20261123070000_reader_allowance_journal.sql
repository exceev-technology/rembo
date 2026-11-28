-- The daily allowance of the server reader (take_receipt_reading, from the
-- code review) taken together with the journal of 20261123050000.
-- A migration of its own: 20261123050000 is already applied on rembo-dev.

-- The daily allowance taken in one step (as take_receipt_reading), also
-- recording which engine reads: returns the id of the new row, or null
-- when the allowance is used up.
create function public.take_receipt_reading_logged(
  p_profile uuid, p_limit integer, p_host text, p_model text
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  perform pg_advisory_xact_lock(hashtext('receipt_readings:' || p_profile::text));
  if (select count(*) from public.receipt_readings
      where profile_id = p_profile
        and created_at > now() - interval '24 hours') >= p_limit then
    return null;
  end if;
  insert into public.receipt_readings (profile_id, engine_host, model)
  values (p_profile, left(coalesce(p_host, ''), 200), left(coalesce(p_model, ''), 100))
  returning id into v_id;
  return v_id;
end $$;

revoke execute on function public.take_receipt_reading_logged(uuid, integer,
  text, text) from public, anon, authenticated;
grant execute on function public.take_receipt_reading_logged(uuid, integer,
  text, text) to service_role;
