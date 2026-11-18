-- One row per receipt read by the AI reader (edge function read-receipt).
-- It only serves to count: each reading costs money, so a person has a
-- daily allowance. Nothing about the receipt itself is kept here.
create table public.receipt_readings (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index receipt_readings_profile_day
  on public.receipt_readings (profile_id, created_at desc);

-- Written and read by the server only: no policy for the app's roles.
alter table public.receipt_readings enable row level security;
revoke all on public.receipt_readings from anon, authenticated;
