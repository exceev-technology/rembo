-- The daily allowance of server readings is taken in one step: counting
-- then inserting from the function let requests sent at the same time all
-- pass under the limit.

-- Records one reading for [p_profile] when fewer than [p_limit] were made in
-- the last 24 hours, and says whether it did. Requests of the same person
-- wait for each other on a lock held until the end of the transaction.
create function public.take_receipt_reading(p_profile uuid, p_limit integer)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtext('receipt_readings:' || p_profile::text));
  if (select count(*) from public.receipt_readings
      where profile_id = p_profile
        and created_at > now() - interval '24 hours') >= p_limit then
    return false;
  end if;
  insert into public.receipt_readings (profile_id) values (p_profile);
  return true;
end $$;

revoke execute on function public.take_receipt_reading(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.take_receipt_reading(uuid, integer)
  to service_role;
