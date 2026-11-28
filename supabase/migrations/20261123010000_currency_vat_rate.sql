-- Currency and VAT rate of a receipt.
--
-- The amount reimbursed stays in dirhams (amount_cents, MAD): it is what
-- the accountant books. A receipt paid in another currency also keeps its
-- currency and the amount actually paid in it (foreign_amount_cents), so
-- the conversion can be checked. The VAT rate is the one printed on the
-- receipt (Moroccan rates: 20, 14, 10 and 7 %, or 0 when exempt).

alter table public.expenses
  add column currency text not null default 'MAD'
    check (currency ~ '^[A-Z]{3}$'),
  add column foreign_amount_cents bigint
    check (foreign_amount_cents is null or foreign_amount_cents > 0),
  add column vat_rate smallint
    check (vat_rate is null or vat_rate in (0, 7, 10, 14, 20));

grant insert (currency, foreign_amount_cents, vat_rate)
  on public.expenses to authenticated;
grant update (currency, foreign_amount_cents, vat_rate)
  on public.expenses to authenticated;
