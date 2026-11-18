-- A receipt or voice note is evidence once its expense is submitted: its
-- owner may replace or delete the file only while the expense is a draft
-- or rejected, exactly when the expense row itself may change.

-- True when [p_name] is the receipt or voice note of an expense that is no
-- longer a draft nor rejected. Security definer so that the storage
-- policies read every expense, whatever the reader may see.
create function public.receipt_locked(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.expenses e
    where (e.receipt_path = p_name or e.voice_path = p_name)
      and e.status not in ('draft', 'rejected')
  )
$$;

revoke execute on function public.receipt_locked(text) from public, anon;
grant execute on function public.receipt_locked(text) to authenticated;

drop policy receipts_update_own on storage.objects;
create policy receipts_update_own on storage.objects for update
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.receipt_locked(name)
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.receipt_locked(name)
  );

drop policy receipts_delete_own on storage.objects;
create policy receipts_delete_own on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.receipt_locked(name)
  );
