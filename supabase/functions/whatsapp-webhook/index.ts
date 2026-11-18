// WhatsApp → REMBO. Receives the messages of the WhatsApp Cloud API and
// turns them into draft expenses of the person who linked that number.
//
//   « LIER 123456 »                            → links the sender's number to
//                                                the account that asked for
//                                                that code in the app
//   text   « Taxi, 45 dirhams, client Atlas »  → draft, summary sent back
//   « oui »                                    → latest draft is submitted
//   voice note                                 → stored; transcribed only
//                                                when TRANSCRIBE_URL is set
//   photo                                      → stored as the receipt
//
// NOT YET RUN against WhatsApp or Supabase: deploy on a test project first.
//
// Secrets (supabase secrets set …):
//   WHATSAPP_VERIFY_TOKEN     free text, also typed in the Meta console
//   WHATSAPP_APP_SECRET       Meta app secret, checks each request's signature
//   WHATSAPP_TOKEN            access token used to answer and fetch media
//   WHATSAPP_PHONE_NUMBER_ID  id of the REMBO WhatsApp number
//   TRANSCRIBE_URL / TRANSCRIBE_KEY  optional speech-to-text endpoint:
//     POST audio bytes (Authorization: Bearer KEY) → { "text": "…" }
// Deploy: supabase functions deploy whatsapp-webhook --no-verify-jwt

import { createClient } from "jsr:@supabase/supabase-js@2";

const env = (name: string) => Deno.env.get(name) ?? "";
const GRAPH = "https://graph.facebook.com/v21.0";
const BUCKET = "receipts";

const db = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
  auth: { persistSession: false },
});

// --- Understanding a message ------------------------------------------------

const CATEGORIES: [string, RegExp][] = [
  ["Transport", /taxi|train|bus|tram|carburant|essence|gasoil|p[ée]age|parking|طاكسي|طاكسى/i],
  ["Repas", /d[ée]jeuner|d[îi]ner|restaurant|resto|caf[ée]|repas|sandwich/i],
  ["Hébergement", /h[ôo]tel|nuit[ée]e?|riad/i],
  ["Fournitures", /fourniture|papier|cartouche|stylo|bureau/i],
];

export type Parsed = {
  supplier: string;
  amountCents: number;
  category: string;
  project: string;
  reason: string;
};

/** An amount as people type it: 45, 45.5, 45,50. */
const NUMBER = String.raw`(\d{1,7})(?:[.,](\d{1,2}))?`;

/** Reads what it can from a short sentence; missing parts stay empty. */
export function parseMessage(text: string): Parsed {
  const clean = text.trim().replace(/\s+/g, " ");
  // The number written with a currency is the amount (« 2 taxis, 45 dh »
  // costs 45); without one, the first number.
  const amount = clean.match(new RegExp(`${NUMBER}\\s*(?:dhs?|dirhams?|mad|درهم)(?![a-z])`, "i")) ??
    clean.match(new RegExp(NUMBER));
  const amountCents = amount
    ? parseInt(amount[1], 10) * 100 + parseInt((amount[2] ?? "0").padEnd(2, "0"), 10)
    : 0;
  const category = CATEGORIES.find(([, re]) => re.test(clean))?.[0] ?? "";
  const project = clean.match(/\b(client|projet)\s+([^,.;]+)/i);
  const supplier = clean.split(/[,.;]/)[0].replace(/\d.*$/, "").trim();
  return {
    supplier: supplier.slice(0, 80),
    amountCents,
    category,
    project: project ? `${cap(project[1])} ${project[2].trim()}`.slice(0, 80) : "",
    reason: clean.slice(0, 200),
  };
}

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
const isYes = (t: string) => /^\s*(oui|ok|d'accord|wah|ah|iyeh|نعم|واه)\s*[.!]?\s*$/i.test(t);
const linkCode = (t: string) => /^\s*lier\s+(\d{6})\s*$/i.exec(t)?.[1] ?? null;
const mad = (cents: number) =>
  `${Math.floor(cents / 100)},${String(cents % 100).padStart(2, "0")} MAD`;

/** Today in Morocco, as YYYY-MM-DD. */
const today = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Casablanca" }).format(new Date());

// --- WhatsApp Cloud API -----------------------------------------------------

// Best effort: a reply that cannot be sent is logged and never fails the
// handling, whose writes in the database are already done.
async function reply(to: string, body: string) {
  try {
    const res = await fetch(`${GRAPH}/${env("WHATSAPP_PHONE_NUMBER_ID")}/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env("WHATSAPP_TOKEN")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ messaging_product: "whatsapp", to, type: "text", text: { body } }),
    });
    if (!res.ok) console.error("reply failed", res.status, await res.text());
  } catch (e) {
    console.error("reply failed", e);
  }
}

async function downloadMedia(
  id: string,
): Promise<{ bytes: Uint8Array<ArrayBuffer>; type: string } | null> {
  const auth = { Authorization: `Bearer ${env("WHATSAPP_TOKEN")}` };
  const meta = await fetch(`${GRAPH}/${id}`, { headers: auth });
  if (!meta.ok) return null;
  const { url, mime_type } = await meta.json();
  const file = await fetch(url, { headers: auth });
  if (!file.ok) return null;
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length > 10 * 1024 * 1024) return null;
  return { bytes, type: String(mime_type ?? "application/octet-stream").split(";")[0] };
}

async function transcribe(audio: Uint8Array<ArrayBuffer>, type: string): Promise<string> {
  if (!env("TRANSCRIBE_URL")) return "";
  try {
    const res = await fetch(env("TRANSCRIBE_URL"), {
      method: "POST",
      headers: { Authorization: `Bearer ${env("TRANSCRIBE_KEY")}`, "Content-Type": type },
      body: audio,
    });
    if (!res.ok) return "";
    return String((await res.json()).text ?? "").slice(0, 500);
  } catch {
    return "";
  }
}

async function validSignature(raw: string, header: string | null): Promise<boolean> {
  const secret = env("WHATSAPP_APP_SECRET");
  if (!secret || !header?.startsWith("sha256=")) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw)));
  const expected = Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
  const given = header.slice(7);
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

// --- Handling one message ---------------------------------------------------

type Owner = { profile_id: string; company_id: string };

// A database failure is thrown, never read as « no account »: the person
// would be told their number is not linked when it is.
async function ownerOf(phone: string): Promise<Owner | null> {
  const { data: link, error: linkError } = await db.from("whatsapp_links")
    .select("profile_id").eq("phone", phone).maybeSingle();
  if (linkError) throw linkError;
  if (!link) return null;
  const { data: member, error: memberError } = await db.from("memberships")
    .select("company_id").eq("profile_id", link.profile_id).maybeSingle();
  if (memberError) throw memberError;
  return member ? { profile_id: link.profile_id, company_id: member.company_id } : null;
}

async function createDraft(owner: Owner, p: Parsed, extra: Record<string, unknown>) {
  const { data, error } = await db.from("expenses").insert({
    company_id: owner.company_id,
    employee_id: owner.profile_id,
    supplier_name: p.supplier,
    expense_date: today(),
    amount_cents: p.amountCents,
    category: p.category,
    project: p.project,
    reason: p.reason,
    source: "whatsapp",
    ...extra,
  }).select("id").single();
  if (error) throw error;
  return data.id as string;
}

const summary = (p: Parsed) =>
  [
    p.supplier || "Dépense",
    p.amountCents > 0 ? mad(p.amountCents) : "montant à préciser",
    p.category || "catégorie à préciser",
    p.project,
  ].filter(Boolean).join(" · ");

// deno-lint-ignore no-explicit-any
async function handle(message: any) {
  // First writer wins: a message delivered twice is handled once. Only a
  // duplicate id (23505) means « already seen »; any other error is thrown.
  const { error: seen } = await db.from("whatsapp_messages").insert({ id: message.id });
  if (seen?.code === "23505") return;
  if (seen) throw seen;
  const state: Handling = { wrote: false };
  try {
    await answer(message, state);
  } catch (e) {
    // Forgotten only when nothing was written, so that the next delivery
    // retries it. Once an expense is created or submitted, handling the
    // message again would create or submit a second one.
    if (!state.wrote) {
      await db.from("whatsapp_messages").delete().eq("id", message.id);
    }
    throw e;
  }
}

/** Set once the handling of a message has written an expense. */
type Handling = { wrote: boolean };

// deno-lint-ignore no-explicit-any
async function answer(message: any, state: Handling) {
  const from = `+${message.from}`;
  // A number not linked yet may send its code: checked before the owner.
  const code = message.type === "text" ? linkCode(String(message.text?.body ?? "")) : null;
  if (code) return linkNumber(from, code, message.from, state);
  const owner = await ownerOf(from);
  if (!owner) {
    await reply(
      message.from,
      "Ce numéro n’est relié à aucun compte REMBO. Ouvrez l’application → Profil → WhatsApp " +
        "pour obtenir un code, puis envoyez « LIER » suivi du code.",
    );
    return;
  }
  await db.from("whatsapp_messages").update({ profile_id: owner.profile_id }).eq("id", message.id);

  if (message.type === "text") {
    const text = String(message.text?.body ?? "");
    if (isYes(text)) return confirmLatest(owner, message.from, state);
    const parsed = parseMessage(text);
    await createDraft(owner, parsed, { transcript: text.slice(0, 500) });
    state.wrote = true;
    await reply(
      message.from,
      `${summary(parsed)}\nRépondez « oui » pour confirmer, ou complétez dans l’application.`,
    );
    return;
  }

  if (message.type === "audio" || message.type === "image") {
    const mediaId = message[message.type]?.id;
    const media = mediaId ? await downloadMedia(mediaId) : null;
    if (!media) {
      await reply(message.from, "Le fichier n’a pas pu être récupéré. Réessayez.");
      return;
    }
    const voice = message.type === "audio";
    const text = voice ? await transcribe(media.bytes, media.type) : "";
    const parsed = parseMessage(text || String(message.image?.caption ?? ""));
    const id = await createDraft(owner, parsed, { transcript: text || null });
    state.wrote = true;
    const path = `${owner.profile_id}/${id}${voice ? "-voice" : ""}`;
    // The draft exists from here on: a file that cannot be kept (refused
    // type, storage down) is said to the person instead of being dropped.
    const upload = await db.storage.from(BUCKET).upload(path, media.bytes, {
      contentType: media.type,
      upsert: true,
    });
    const link = upload.error ? null : await db.from("expenses")
      .update(voice ? { voice_path: path } : { receipt_path: path })
      .eq("id", id);
    const failure = upload.error ?? link?.error;
    if (failure) {
      console.error("media not stored", message.id, failure.message);
      await reply(
        message.from,
        "La dépense est créée, mais le fichier n’a pas pu être enregistré. Ajoutez-le dans l’application.",
      );
      return;
    }
    await reply(
      message.from,
      text
        ? `${summary(parsed)}\nRépondez « oui » pour confirmer, ou complétez dans l’application.`
        : voice
        ? "Message vocal reçu. Ouvrez REMBO pour compléter et confirmer la dépense."
        : "Ticket reçu. Ouvrez REMBO pour compléter et confirmer la dépense.",
    );
    return;
  }

  await reply(message.from, "Envoyez un message, une note vocale ou la photo d’un ticket.");
}

const LINK_REPLIES: Record<string, string> = {
  linked: "Numéro relié à votre compte REMBO. Vous pouvez envoyer vos dépenses ici.",
  expired:
    "Ce code a expiré. Demandez un nouveau code dans l’application → Profil → WhatsApp.",
  invalid:
    "Code inconnu. Vérifiez-le, ou demandez un nouveau code dans l’application → Profil → WhatsApp.",
  too_many: "Trop d’essais depuis ce numéro. Réessayez dans une heure.",
};

// The server checks the code and links the number it came from: the person
// proves they hold the number, nobody can link someone else's.
async function linkNumber(phone: string, code: string, to: string, state: Handling) {
  const { data, error } = await db.rpc("claim_whatsapp_link", {
    p_phone: phone,
    p_code: code,
  });
  if (error) throw error;
  // The code is used up (or the attempt counted): never claim it twice.
  state.wrote = true;
  await reply(to, LINK_REPLIES[String(data)] ?? LINK_REPLIES.invalid);
}

async function confirmLatest(owner: Owner, to: string, state: Handling) {
  const { data: draft, error: draftError } = await db.from("expenses").select("id")
    .eq("employee_id", owner.profile_id).eq("source", "whatsapp").eq("status", "draft")
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (draftError) throw draftError;
  if (!draft) {
    await reply(to, "Aucune dépense en attente de confirmation.");
    return;
  }
  // Same control as in the app; the server decides the outcome.
  const { data, error } = await db.rpc("control_expense", {
    p_id: draft.id,
    p_actor: owner.profile_id,
  });
  if (error) {
    await reply(to, `${error.message}\nComplétez la dépense dans l’application.`);
    return;
  }
  state.wrote = true;
  await reply(
    to,
    data.status === "approved"
      ? `Dépense validée : ${mad(data.amount_cents)}.`
      : "Dépense transmise à votre responsable pour décision.",
  );
}

// --- HTTP -------------------------------------------------------------------

if (import.meta.main) {
  Deno.serve(async (req) => {
    const url = new URL(req.url);
    if (req.method === "GET") {
      // Subscription check made once by Meta.
      const ok = url.searchParams.get("hub.mode") === "subscribe" &&
        env("WHATSAPP_VERIFY_TOKEN") !== "" &&
        url.searchParams.get("hub.verify_token") === env("WHATSAPP_VERIFY_TOKEN");
      return ok
        ? new Response(url.searchParams.get("hub.challenge") ?? "")
        : new Response("forbidden", { status: 403 });
    }
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

    const raw = await req.text();
    if (!(await validSignature(raw, req.headers.get("x-hub-signature-256")))) {
      return new Response("bad signature", { status: 401 });
    }
    let payload;
    try {
      payload = JSON.parse(raw);
    } catch (e) {
      // Sending it again would not make it readable: no retry.
      console.error("webhook payload", e);
      return new Response("ok");
    }
    // One message that fails does not stop the others. Meta then delivers
    // the payload again: the messages already handled are skipped (see
    // handle) and the failed one is tried again.
    let failed = false;
    for (const entry of payload.entry ?? []) {
      for (const change of entry.changes ?? []) {
        for (const message of change.value?.messages ?? []) {
          try {
            await handle(message);
          } catch (e) {
            console.error("webhook error", message?.id, e);
            failed = true;
          }
        }
      }
    }
    return failed ? new Response("retry", { status: 500 }) : new Response("ok");
  });
}
