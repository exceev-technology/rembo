// Receipt → values, read by a vision model on the server. The phone reads
// receipts itself first (Google ML Kit, Latin script only); it calls this
// function when that reading is missing or incomplete, typically for a
// receipt in Arabic or handwritten.
//
//   POST { file_name, image_base64 }   (signed-in users only)
//   → { unreadable, supplier, supplier_ice, date, amount_cents, vat_cents,
//       vat_rate, currency }
//
// Any engine that speaks the OpenAI « chat completions » API works:
//
//   * a model the company hosts itself (recommended: free and private),
//     e.g. Ollama with a vision model:
//       RECEIPT_API_URL=http://<server>:11434/v1  RECEIPT_MODEL=qwen2.5vl:7b
//     The picture never leaves the company's servers.
//   * a cloud model, e.g. Gemini through its OpenAI-compatible endpoint:
//       RECEIPT_API_URL=https://generativelanguage.googleapis.com/v1beta/openai
//       RECEIPT_MODEL=gemini-2.5-flash  RECEIPT_API_KEY=<key>
//     Free tiers may reuse what is sent to them. Such an engine is refused
//     unless RECEIPT_SHARED_ENGINE=fictitious-data-only says, on purpose,
//     that the project only holds fictional receipts (demo, user tests).
//
// The values come back as proposals: the person checks them on the form,
// and the server's own control decides on the expense.
//
// Secrets (supabase secrets set …):
//   RECEIPT_API_URL        base URL of the engine (required)
//   RECEIPT_MODEL          model name (required)
//   RECEIPT_API_KEY        when the engine needs one; never in the app
//   RECEIPT_PRIVATE_HOSTS  comma-separated hosts the company controls;
//                          localhost, host.docker.internal and private
//                          network addresses always count as such
//   RECEIPT_SHARED_ENGINE  "fictitious-data-only" to allow another host
//   RECEIPT_DAILY_LIMIT    readings per person per day (default 40)
// Deploy: supabase functions deploy read-receipt

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  engine,
  fieldsFound,
  isBusy,
  patiently,
  readPicture,
} from "../_shared/engines.ts";

export {
  fieldsFound,
  isPrivateHost,
  parseAnswer,
  toCents,
  toDay,
  toResponse,
} from "../_shared/engines.ts";

const env = (name: string) => Deno.env.get(name) ?? "";
const DAILY_LIMIT = Number(env("RECEIPT_DAILY_LIMIT")) || 40;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const MEDIA_TYPES = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
} as const;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

if (import.meta.main) {
  Deno.serve(async (request) => {
    if (request.method !== "POST") return json({ error: "method" }, 405);

    // Who is asking: the platform already checked the token's signature;
    // this resolves the person, to count their readings.
    const authorization = request.headers.get("Authorization") ?? "";
    const asUser = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json({ error: "unauthenticated" }, 401);

    let body: { file_name?: unknown; image_base64?: unknown };
    try {
      body = await request.json();
    } catch {
      return json({ error: "body" }, 400);
    }
    const name = typeof body.file_name === "string" ? body.file_name : "";
    const image = typeof body.image_base64 === "string"
      ? body.image_base64
      : "";
    const ext = name.toLowerCase().split(".").pop() ?? "";
    const mediaType = MEDIA_TYPES[ext as keyof typeof MEDIA_TYPES];
    if (!mediaType || !/^[A-Za-z0-9+/]+=*$/.test(image)) {
      return json({ error: "image" }, 400);
    }
    if (image.length * 0.75 > MAX_IMAGE_BYTES) {
      return json({ error: "too_large" }, 413);
    }

    const reader = engine("RECEIPT");
    if (!reader) return json({ error: "not_configured" }, 503);

    // A person gets a daily allowance: an engine costs money or time.
    const admin = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );
    // Counted and recorded in one step (take_receipt_reading_logged, see
    // migrations): requests sent at the same time cannot all pass under the
    // limit. The row it returns then receives the outcome of the reading.
    const { data: journalId, error: quotaError } = await admin.rpc(
      "take_receipt_reading_logged",
      {
        p_profile: user.id,
        p_limit: DAILY_LIMIT,
        p_host: reader.host,
        p_model: reader.model,
      },
    );
    if (quotaError) return json({ error: "server" }, 500);
    if (journalId == null) return json({ error: "daily_limit" }, 429);
    const started = Date.now();
    const done = async (outcome: string, fields = 0) => {
      await admin.from("receipt_readings").update({
        outcome,
        fields_found: fields,
        duration_ms: Date.now() - started,
      }).eq("id", journalId);
    };

    try {
      const response = await patiently(
        reader,
        (e) => readPicture(e, image, mediaType),
      );
      await done(
        response.unreadable ? "unreadable" : "read",
        fieldsFound(response),
      );
      return json(response);
    } catch (error) {
      console.error("read-receipt", error);
      await done("error");
      return json(
        { error: isBusy(error) ? "busy" : "reader" },
        isBusy(error) ? 429 : 502,
      );
    }
  });
}
