-- What the agents proposed, to measure what people accepted or corrected.
--
-- agent_proposal: written by the app when the form opens, never changed
--   afterwards: {"engine": "device" | "server" | "", "fields": {
--   "<field>": {"value": "...", "confidence": "high|medium|low",
--   "reason": "...", "agent": "reading" | "classification"}}}.
--   Values are written the way the columns store them: amounts in
--   centimes, dates as YYYY-MM-DD.
-- capture_started_at: when the person started declaring (photo taken, or
--   form opened), to measure the time to declare.
--
-- The view agent_metrics compares each proposal with what was submitted.
-- It runs with the rights of the reader (security_invoker): everyone sees
-- the measures of the expenses they may read, nothing more.

alter table public.expenses
  add column agent_proposal jsonb
    check (agent_proposal is null or jsonb_typeof(agent_proposal) = 'object'),
  add column capture_started_at timestamptz;

-- The first proposal and start time are kept: a later save cannot rewrite
-- what the agents said, nor when the declaration began.
create function public.keep_agent_journal() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.agent_proposal is not null then
    new.agent_proposal := old.agent_proposal;
  end if;
  if old.capture_started_at is not null then
    new.capture_started_at := old.capture_started_at;
  end if;
  return new;
end $$;

create trigger expenses_keep_agent_journal before update on public.expenses
  for each row execute function public.keep_agent_journal();

grant insert (agent_proposal, capture_started_at)
  on public.expenses to authenticated;
grant update (agent_proposal, capture_started_at)
  on public.expenses to authenticated;

create view public.agent_metrics with (security_invoker = on) as
with submitted as (
  select e.*,
    (select min(s.created_at) from public.status_events s
     where s.expense_id = e.id and s.to_status = 'submitted') as submitted_at
  from public.expenses e
  where e.status <> 'draft'
),
fields as (
  select s.id, f.key as field, f.value ->> 'value' as proposed,
    f.value ->> 'agent' as agent,
    case f.key
      when 'supplier' then s.supplier_name
      when 'ice' then s.supplier_ice
      when 'date' then s.expense_date::text
      when 'amount' then s.amount_cents::text
      when 'vat' then s.vat_cents::text
      when 'rate' then s.vat_rate::text
      when 'currency' then s.currency
      when 'foreign' then s.foreign_amount_cents::text
      when 'category' then s.category
      when 'project' then s.project
    end as kept
  from submitted s,
    jsonb_each(coalesce(s.agent_proposal -> 'fields', '{}'::jsonb)) as f
)
select s.id as expense_id, s.company_id, s.employee_id,
  coalesce(s.agent_proposal ->> 'engine', '') as engine,
  count(f.field)::int as proposed,
  count(f.field) filter (
    where lower(trim(f.kept)) = lower(trim(f.proposed)))::int as accepted,
  count(f.field) filter (
    where lower(trim(coalesce(f.kept, ''))) <> lower(trim(f.proposed)))::int
    as corrected,
  coalesce(array_agg(f.field order by f.field) filter (
    where lower(trim(coalesce(f.kept, ''))) <> lower(trim(f.proposed))),
    '{}') as corrected_fields,
  extract(epoch from s.submitted_at - s.capture_started_at)::int
    as declare_seconds
from submitted s
left join fields f on f.id = s.id
group by s.id, s.company_id, s.employee_id, s.agent_proposal,
  s.submitted_at, s.capture_started_at;

revoke all on public.agent_metrics from anon, authenticated;
grant select on public.agent_metrics to authenticated;
