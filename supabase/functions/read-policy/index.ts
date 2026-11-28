// A company's reimbursement policy → rules REMBO can apply, read by the
// receipt engine (same RECEIPT_* secrets as read-receipt).
//
//   POST { file_name, text }               a text file or pasted text
//   POST { file_name, pages_base64: [...] } pages of a PDF or a photo (PNG
//                                          or JPEG), at most 6
//   (managers only)
//   → { summary, deadline_days, project_required,
//       rules: [{ category, limit_cents, receipt_required }],
//       not_applied: [...] }                or { unreadable: true }
//
// Nothing is applied here: the app shows the proposal, the manager checks
// it, and apply_policy (see migrations) writes what they accepted.
// Deploy: supabase functions deploy read-policy

import { createClient } from "jsr:@supabase/supabase-js@2";
import { type Engine, engine, isBusy, patiently } from "../_shared/engines.ts";
import { parseJson, POLICY_INSTRUCTIONS, toProposal } from "./policy.ts";

export { parseJson, toCents, toProposal } from "./policy.ts";

const env = (name: string) => Deno.env.get(name) ?? "";
const MAX_PAGES = 6;
const MAX_PAGE_BYTES = 3 * 1024 * 1024;
const MAX_TEXT = 40_000;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

type Content =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string } };

async function readPolicy(e: Engine, content: Content[]) {
  const answer = await fetch(`${e.base}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(e.key ? { authorization: `Bearer ${e.key}` } : {}),
    },
    body: JSON.stringify({
      model: e.model,
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: POLICY_INSTRUCTIONS },
        { role: "user", content },
      ],
    }),
    signal: AbortSignal.timeout(e.timeoutMs ?? 40_000),
  });
  if (!answer.ok) {
    throw new Error(`engine ${answer.status} ${await answer.text()}`);
  }
  const payload = await answer.json();
  return toProposal(
    parseJson(String(payload?.choices?.[0]?.message?.content ?? "")),
  );
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method !== "POST") return json({ error: "method" }, 405);

    const asUser = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
      global: {
        headers: { Authorization: request.headers.get("Authorization") ?? "" },
      },
      auth: { persistSession: false },
    });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json({ error: "unauthenticated" }, 401);
    const { data: role } = await asUser.rpc("my_role");
    if (role !== "manager") return json({ error: "forbidden" }, 403);

    let body: { file_name?: unknown; text?: unknown; pages_base64?: unknown };
    try {
      body = await request.json();
    } catch {
      return json({ error: "body" }, 400);
    }
    const content: Content[] = [];
    if (typeof body.text === "string" && body.text.trim()) {
      content.push({
        type: "text",
        text: `Policy:\n\n${body.text.slice(0, MAX_TEXT)}`,
      });
    } else if (Array.isArray(body.pages_base64)) {
      const pages = body.pages_base64.slice(0, MAX_PAGES);
      for (const page of pages) {
        if (
          typeof page !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(page) ||
          page.length * 0.75 > MAX_PAGE_BYTES
        ) {
          return json({ error: "file" }, 400);
        }
        const type = page.startsWith("/9j/") ? "image/jpeg" : "image/png";
        content.push({
          type: "image_url",
          image_url: { url: `data:${type};base64,${page}` },
        });
      }
      content.push({ type: "text", text: "Read this policy." });
    }
    if (content.length === 0) return json({ error: "file" }, 400);

    const reader = engine("RECEIPT");
    if (!reader) return json({ error: "not_configured" }, 503);
    try {
      const proposal = await patiently(
        { ...reader, timeoutMs: 40_000 },
        (e) => readPolicy(e, content),
        1500,
        // The app waits 60 s: a policy is longer to read than a receipt.
        55_000,
      );
      return json(proposal ?? { unreadable: true });
    } catch (error) {
      console.error("read-policy", error);
      return json(
        { error: isBusy(error) ? "busy" : "reader" },
        isBusy(error) ? 429 : 502,
      );
    }
  });
}
