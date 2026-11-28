-- Compliance agent: more checks, each with a reason a manager can read.
--
--   * VAT that does not match the rate printed on the receipt
--   * a supplier ICE that is not 15 digits
--   * the same supplier and amount a few days apart (likely duplicate)
--   * a receipt in another currency: the conversion is checked by a
--     manager, and the amount paid in that currency is required
--
-- The app previews the same checks before submission (lib/core/agents):
-- keep both in step.

create or replace function public.control_expense(p_id uuid, p_actor uuid)
returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := p_actor;
  e public.expenses;
  v_rule public.policies;
  v_flags jsonb := '[]'::jsonb;
  v_status public.expense_status;
  v_auto boolean;
  v_name text;
  v_expected numeric;
begin
  select * into e from public.expenses where id = p_id for update;
  if not found or e.employee_id is distinct from v_uid then
    raise exception 'Vous ne pouvez soumettre que vos dépenses.';
  end if;
  if e.status not in ('draft', 'rejected') then
    return e;
  end if;
  if trim(e.supplier_name) = '' or e.expense_date is null
     or e.amount_cents <= 0 or e.category = '' or trim(e.reason) = '' then
    raise exception
      'Complétez le fournisseur, la date, le montant, la catégorie et le motif.';
  end if;
  if e.expense_date > current_date then
    raise exception 'La date de la dépense est dans le futur.';
  end if;
  if e.currency <> 'MAD' and e.foreign_amount_cents is null then
    raise exception 'Indiquez le montant payé en devise.';
  end if;

  select * into v_rule from public.policies
  where company_id = e.company_id and category = e.category;
  if found then
    if e.amount_cents > v_rule.limit_cents then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Plafond ' || e.category || ' dépassé de '
        || public.format_mad(e.amount_cents - v_rule.limit_cents));
    end if;
    if v_rule.receipt_required and coalesce(e.receipt_path, '') = '' then
      v_flags := v_flags || jsonb_build_object('kind', 'policy', 'message',
        'Justificatif manquant');
    end if;
  end if;
  if exists (
    select 1 from public.expenses o
    where o.id <> e.id and o.employee_id = e.employee_id
      and o.expense_date = e.expense_date
      and o.amount_cents = e.amount_cents
      and o.status not in ('draft', 'rejected')
  ) then
    v_flags := v_flags || jsonb_build_object('kind', 'duplicate', 'message',
      'Même date et même montant qu’une dépense déjà déclarée');
  elsif exists (
    select 1 from public.expenses o
    where o.id <> e.id and o.employee_id = e.employee_id
      and o.amount_cents = e.amount_cents
      and abs(o.expense_date - e.expense_date) <= 3
      and lower(regexp_replace(trim(o.supplier_name), '\s+', ' ', 'g'))
        = lower(regexp_replace(trim(e.supplier_name), '\s+', ' ', 'g'))
      and o.status not in ('draft', 'rejected')
  ) then
    v_flags := v_flags || jsonb_build_object('kind', 'duplicate', 'message',
      'Même fournisseur et même montant à quelques jours d’intervalle');
  end if;
  if e.category = 'Autre' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Catégorie à préciser');
  end if;
  if current_date - e.expense_date > 60 then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense datée de plus de 60 jours');
  end if;
  if e.currency <> 'MAD' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'Dépense en devise : conversion en dirhams à vérifier');
  end if;
  if e.vat_rate > 0 and e.vat_cents > 0 then
    v_expected := e.amount_cents * e.vat_rate / (100.0 + e.vat_rate);
    if abs(e.vat_cents - v_expected) > greatest(100, v_expected * 0.02) then
      v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
        'TVA incohérente avec le taux indiqué');
    end if;
  end if;
  if e.supplier_ice <> '' and e.supplier_ice !~ '^\d{15}$' then
    v_flags := v_flags || jsonb_build_object('kind', 'ambiguity', 'message',
      'ICE du fournisseur invalide : 15 chiffres attendus');
  end if;

  select auto_approve into v_auto from public.companies
  where id = e.company_id;
  v_status := case when v_flags = '[]'::jsonb and v_auto
    then 'approved' else 'needs_review' end;
  select full_name into v_name from public.profiles where id = v_uid;

  insert into public.status_events
    (expense_id, from_status, to_status, actor_id, actor_kind, actor_name,
     created_at)
  values
    (e.id, e.status, 'submitted', v_uid, 'human', coalesce(v_name, ''),
     clock_timestamp());
  insert into public.status_events
    (expense_id, from_status, to_status, actor_kind, actor_name, reason,
     created_at)
  values
    (e.id, 'submitted', v_status, 'agent', 'Contrôle automatique',
     case when v_flags = '[]'::jsonb and v_status = 'needs_review'
       then 'Conforme aux règles' end,
     clock_timestamp());
  update public.expenses set status = v_status, flags = v_flags
  where id = e.id returning * into e;
  return e;
end $$;
