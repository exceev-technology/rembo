-- The WhatsApp conversation with each person, so that a message is read in
-- the light of the previous ones (« il manque le client Marjane » completes
-- the taxi sent just before). Only the webhook (service_role) reads and
-- writes it; the conversation agent reads the last turns of the day.

create table public.whatsapp_turns (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  author text not null check (author in ('person', 'rembo')),
  body text not null check (length(body) <= 2000),
  expense_id uuid references public.expenses (id) on delete set null,
  created_at timestamptz not null default now()
);

create index whatsapp_turns_recent
  on public.whatsapp_turns (profile_id, created_at desc);

alter table public.whatsapp_turns enable row level security;
revoke all on public.whatsapp_turns from anon, authenticated;

-- Turns older than 30 days are of no use to the agent: removed at each new
-- turn of the same person, so the table never grows without limit.
create function public.forget_old_turns() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.whatsapp_turns
  where profile_id = new.profile_id
    and created_at < now() - interval '30 days';
  return new;
end $$;

create trigger whatsapp_turns_forget
  after insert on public.whatsapp_turns
  for each row execute function public.forget_old_turns();

revoke execute on function public.forget_old_turns() from public, anon,
  authenticated;
