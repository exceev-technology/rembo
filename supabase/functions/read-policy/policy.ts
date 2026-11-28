// What the engine is asked to find in a company's reimbursement policy,
// and how its answer is checked before it reaches a manager.

/** Categories REMBO knows, besides « Autre » which has no limit. */
export const CATEGORIES = ["Repas", "Transport", "Hébergement", "Fournitures"];

export const POLICY_INSTRUCTIONS = `You read a company's expense \
reimbursement policy (pages of a document, a photo or plain text, often in \
French, sometimes Arabic or English). Find only these rules:

- deadline_days: within how many days after the expense it must be \
declared (an integer), or null if the policy says nothing about it.
- project_required: true if every expense must name a project, client or \
mission; false if the policy says it is optional; null if it says nothing.
- rules: for each of these categories the policy limits: ${
  CATEGORIES.join(", ")
} — map meals/restaurant to Repas, taxi/train/fuel/travel to Transport, \
hotel/lodging to Hébergement, office supplies to Fournitures. For each: \
{"category": one of those names, "limit_mad": the maximum amount per \
expense in Moroccan dirhams (a number), "receipt_required": true/false or \
null}. Leave out a category the policy does not limit. If a limit is per \
day or per night, still give it as the limit per expense.
- not_applied: the other rules of the policy, one short French sentence \
each (at most 10), e.g. "Pas d'alcool remboursé", "Classe économique \
obligatoire pour les vols".
- summary: two or three French sentences summing up the policy.

Never invent a rule the document does not state. Answer with one JSON \
object: {"summary": "...", "deadline_days": ..., "project_required": ..., \
"rules": [...], "not_applied": [...]}. If the document is not an expense \
policy, answer {"unreadable": true}.`;

export type Proposal = {
  summary: string;
  deadline_days: number | null;
  project_required: boolean | null;
  rules: { category: string; limit_cents: number; receipt_required: boolean }[];
  not_applied: string[];
};

const text = (value: unknown, max: number) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

/** « 1 200,50 », 1200.5 or "1200 DH" → 120050 centimes; null otherwise. */
export function toCents(value: unknown): number | null {
  let n: number;
  if (typeof value === "number") {
    n = value;
  } else if (typeof value === "string") {
    const cleaned = value.replace(/[^\d,.]/g, "").replace(/\s/g, "");
    const decimal = cleaned.replace(/[.,](?=\d{3}(\D|$))/g, "")
      .replace(",", ".");
    n = Number(decimal);
  } else {
    return null;
  }
  if (!Number.isFinite(n) || n <= 0 || n > 1_000_000) return null;
  return Math.round(n * 100);
}

/** The engine's answer, kept only where it fits what REMBO can apply;
 * null when it is not a policy. */
export function toProposal(raw: unknown): Proposal | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (r.unreadable === true) return null;
  const days = typeof r.deadline_days === "number"
    ? Math.round(r.deadline_days)
    : Number.parseInt(String(r.deadline_days ?? ""), 10);
  const seen = new Set<string>();
  const rules: Proposal["rules"] = [];
  for (const item of Array.isArray(r.rules) ? r.rules : []) {
    if (!item || typeof item !== "object") continue;
    const rule = item as Record<string, unknown>;
    const category = CATEGORIES.find((c) =>
      c.toLowerCase() === text(rule.category, 40).toLowerCase()
    );
    const cents = toCents(rule.limit_mad ?? rule.limit_cents);
    if (!category || cents == null || seen.has(category)) continue;
    seen.add(category);
    rules.push({
      category,
      limit_cents: cents,
      receipt_required: rule.receipt_required !== false,
    });
  }
  const notApplied = (Array.isArray(r.not_applied) ? r.not_applied : [])
    .map((n) => text(n, 300))
    .filter(Boolean)
    .slice(0, 10);
  const proposal: Proposal = {
    summary: text(r.summary, 1200),
    deadline_days: Number.isFinite(days) && days >= 1 && days <= 365
      ? days
      : null,
    project_required: typeof r.project_required === "boolean"
      ? r.project_required
      : null,
    rules,
    not_applied: notApplied,
  };
  const empty = proposal.deadline_days == null &&
    proposal.project_required == null && rules.length === 0 &&
    notApplied.length === 0;
  return empty ? null : proposal;
}

/** The JSON object in the engine's answer, even wrapped in a code block. */
export function parseJson(content: string): unknown {
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(content.slice(start, end + 1));
  } catch {
    return null;
  }
}
