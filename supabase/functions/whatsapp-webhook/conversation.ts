// The conversation agent. A message may start a new expense, or complete
// or correct the draft the person sent a moment ago (« il manque le client
// Marjane », « c'était 50 dh »), or cancel it. The receipt engine reads the
// message with the day's conversation and that draft in mind; without an
// engine, simple rules decide. Kept apart from the webhook, so that it can
// later serve another channel (a chat in the app) unchanged.

import { type Engine, patiently } from "../_shared/engines.ts";

export const CATEGORY_NAMES = [
  "Transport",
  "Repas",
  "Hébergement",
  "Fournitures",
  "Autre",
];

/** The draft the conversation is about, as the engine sees it. */
export type Draft = {
  id: string;
  supplier: string;
  amountCents: number;
  category: string;
  project: string;
  reason: string;
};

/** One message of the conversation, oldest first. */
export type Turn = { author: "person" | "rembo"; body: string };

/** Fields read in the message; null: not said, keep what is there. */
export type Fields = {
  supplier: string | null;
  amountCents: number | null;
  category: string | null;
  project: string | null;
  reason: string | null;
};

export type Understanding =
  | { intent: "new"; fields: Fields | null }
  | { intent: "update"; fields: Fields }
  | { intent: "cancel" }
  | { intent: "other" };

export const CONVERSATION_INSTRUCTIONS = `You help an employee in Morocco \
declare work expenses through WhatsApp, in French, darija or Arabic. You \
receive the conversation of the day, their new message and, when there is \
one, the draft expense they sent last. Decide what the message does:

- "update": it completes or corrects that draft (a missing client or \
project, another amount, supplier or category, "c'était 50 dh", "il manque \
le client Marjane", "plutôt repas"). Give only the fields it changes.
- "new": it describes another expense. Give every field you can read.
- "cancel": it asks to cancel or delete the draft.
- "other": a greeting, a question or anything else.

Fields: supplier (short name, e.g. "Taxi"), amount_mad (number, the amount \
in dirhams), category (one of ${
  CATEGORY_NAMES.join(", ")
}), project (the client or project, e.g. "Client Marjane"), reason (one \
short French sentence on what the expense was for). Use null for anything \
not said. Never invent an amount.

Answer with one JSON object: {"intent": "...", "supplier": ..., \
"amount_mad": ..., "category": ..., "project": ..., "reason": ...}`;

const text = (value: unknown, max: number) =>
  typeof value === "string" && value.trim() ? value.trim().slice(0, max) : null;

function cents(value: unknown): number | null {
  const n = typeof value === "number"
    ? value
    : Number(String(value ?? "").replace(/[^\d,.]/g, "").replace(",", "."));
  return Number.isFinite(n) && n > 0 && n < 10_000_000
    ? Math.round(n * 100)
    : null;
}

/** The engine's answer, checked; an update without a draft is a new one. */
export function toUnderstanding(
  raw: unknown,
  draft: Draft | null,
): Understanding | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const category =
    CATEGORY_NAMES.find((c) =>
      c.toLowerCase() === String(r.category ?? "").trim().toLowerCase()
    ) ?? null;
  const fields: Fields = {
    supplier: text(r.supplier, 80),
    amountCents: cents(r.amount_mad),
    category,
    project: text(r.project, 80),
    reason: text(r.reason, 200),
  };
  switch (r.intent) {
    case "update":
      return draft ? { intent: "update", fields } : { intent: "new", fields };
    case "new":
      return { intent: "new", fields };
    case "cancel":
      return draft ? { intent: "cancel" } : { intent: "other" };
    case "other":
      return { intent: "other" };
    default:
      return null;
  }
}

/** Without an engine: a message with no amount and no category, right
 * after a draft, completes it; « annule » cancels it. */
export function followUpByRules(
  message: string,
  draft: Draft | null,
  read: { amountCents: number; category: string; project: string },
): Understanding | null {
  if (!draft) return null;
  if (/^\s*(annule[rz]?|supprime[rz]?|stop)\b/i.test(message)) {
    return { intent: "cancel" };
  }
  if (read.amountCents > 0 || read.category) return null;
  if (!read.project) return null;
  return {
    intent: "update",
    fields: {
      supplier: null,
      amountCents: null,
      category: null,
      project: read.project,
      reason: null,
    },
  };
}

/** The draft once the update is applied. */
export function applyUpdate(draft: Draft, fields: Fields): Draft {
  return {
    id: draft.id,
    supplier: fields.supplier ?? draft.supplier,
    amountCents: fields.amountCents ?? draft.amountCents,
    category: fields.category ?? draft.category,
    project: fields.project ?? draft.project,
    reason: fields.reason ?? draft.reason,
  };
}

/** The JSON object in the engine's answer, even inside a code block. */
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

/** What the engine is given: the day's turns, the draft, the message. */
export function prompt(history: Turn[], draft: Draft | null, message: string) {
  const turns = history.slice(-12).map((t) =>
    `${t.author === "person" ? "Employee" : "REMBO"}: ${t.body.slice(0, 400)}`
  ).join("\n");
  const current = draft
    ? JSON.stringify({
      supplier: draft.supplier,
      amount_mad: draft.amountCents / 100,
      category: draft.category,
      project: draft.project,
      reason: draft.reason,
    })
    : "none";
  return `Conversation so far:\n${turns || "(none)"}\n\n` +
    `Draft expense: ${current}\n\nNew message: ${message.slice(0, 1000)}`;
}

/** Asks the engine; null when it cannot answer in time (rules decide). */
export async function understand(
  e: Engine,
  history: Turn[],
  draft: Draft | null,
  message: string,
): Promise<Understanding | null> {
  try {
    return await patiently(
      e,
      async (x) => {
        const answer = await fetch(`${x.base}/chat/completions`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            ...(x.key ? { authorization: `Bearer ${x.key}` } : {}),
          },
          body: JSON.stringify({
            model: x.model,
            temperature: 0,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: CONVERSATION_INSTRUCTIONS },
              { role: "user", content: prompt(history, draft, message) },
            ],
          }),
          signal: AbortSignal.timeout(x.timeoutMs ?? 10_000),
        });
        if (!answer.ok) {
          throw new Error(`engine ${answer.status} ${await answer.text()}`);
        }
        const payload = await answer.json();
        return toUnderstanding(
          parseJson(String(payload?.choices?.[0]?.message?.content ?? "")),
          draft,
        );
      },
      800,
      12_000,
    );
  } catch (error) {
    console.error("conversation agent", error);
    return null;
  }
}
