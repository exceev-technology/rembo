-- WhatsApp channel: a person links their number; messages sent from it
-- become their draft expenses, written by the `whatsapp-webhook` function
-- (service role). The app can read these fields, never write them.

create table public.whatsapp_links (
  profile_id uuid primary key references public.profiles (id)
    on delete cascade,
  phone text not null unique check (phone ~ '^\+[1-9]\d{7,14}$'),
  created_at timestamptz not null default now()
);
alter table public.whatsapp_links enable row level security;
-- One's own number only: colleagues do not see it.
create policy whatsapp_links_own on public.whatsapp_links for all
  to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
revoke all on public.whatsapp_links from anon, authenticated;
grant select, insert, update, delete on public.whatsapp_links
  to authenticated;

-- Messages already handled: WhatsApp delivers some of them twice.
create table public.whatsapp_messages (
  id text primary key,
  profile_id uuid references public.profiles (id) on delete set null,
  received_at timestamptz not null default now()
);
alter table public.whatsapp_messages enable row level security;
revoke all on public.whatsapp_messages from anon, authenticated;

alter table public.expenses
  add column source text not null default 'app'
    check (source in ('app', 'whatsapp')),
  add column transcript text,
  add column voice_path text,
  add constraint expenses_voice_in_owner_folder
    check (voice_path is null or voice_path like employee_id::text || '/%');

-- Voice notes live next to the receipts, under the same rules.
update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp',
  'image/heic', 'audio/ogg', 'audio/mpeg', 'audio/mp4', 'audio/aac']
where id = 'receipts';

drop policy receipts_read on storage.objects;
create policy receipts_read on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.expenses e
        where e.receipt_path = objects.name or e.voice_path = objects.name
      )
    )
  );
