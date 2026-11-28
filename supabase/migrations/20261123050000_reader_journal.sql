-- Journal of the server reader: which engine read a receipt, how long it
-- took and whether it found anything. Still nothing about the receipt
-- itself (no picture, no value): only what is needed to watch the cost,
-- the speed and the quality of the engine chosen.

alter table public.receipt_readings
  add column engine_host text not null default '',
  add column model text not null default '',
  add column duration_ms integer,
  add column outcome text not null default 'pending'
    check (outcome in ('pending', 'read', 'unreadable', 'error')),
  add column fields_found smallint not null default 0;
