// Run: deno test --allow-env supabase/functions/_shared/
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  engine,
  isGeminiNative,
  patiently,
  transcribeAudio,
} from "./engines.ts";

Deno.test("Gemini's own API is told apart from its OpenAI door", () => {
  assertEquals(
    isGeminiNative("https://generativelanguage.googleapis.com/v1beta"),
    true,
  );
  assertEquals(
    isGeminiNative("https://generativelanguage.googleapis.com/v1beta/openai"),
    false,
  );
  assertEquals(isGeminiNative("http://whisper.lan:8000/v1"), false);
});

Deno.test("a shared engine needs the fictitious-data lock", () => {
  Deno.env.set(
    "T1_API_URL",
    "https://generativelanguage.googleapis.com/v1beta",
  );
  Deno.env.set("T1_MODEL", "gemini-2.5-flash");
  assertEquals(engine("T1"), null);
  Deno.env.set("T1_SHARED_ENGINE", "fictitious-data-only");
  assertEquals(engine("T1")?.host, "generativelanguage.googleapis.com");
});

Deno.test("a voice note goes to Gemini inline, with the key in a header", async () => {
  const seen: { url: string; key: string | null; body: string }[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = (async (url: string | URL, init?: RequestInit) => {
    seen.push({
      url: String(url),
      key: new Headers(init?.headers).get("x-goog-api-key"),
      body: String(init?.body),
    });
    return new Response(JSON.stringify({
      candidates: [{
        content: { parts: [{ text: "Taxi 30 dirhams client Atlas" }] },
      }],
    }));
  }) as typeof fetch;
  try {
    const text = await transcribeAudio(
      {
        base: "https://generativelanguage.googleapis.com/v1beta",
        model: "gemini-2.5-flash",
        host: "generativelanguage.googleapis.com",
        key: "cle-de-test",
        fallback: "",
      },
      new Uint8Array([1, 2, 3]),
      "audio/ogg",
    );
    assertEquals(text, "Taxi 30 dirhams client Atlas");
    assertEquals(
      seen[0].url,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
    );
    assertEquals(seen[0].key, "cle-de-test");
    assertEquals(JSON.parse(seen[0].body).contents[0].parts[0].inline_data, {
      mime_type: "audio/ogg",
      data: "AQID",
    });
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("a busy engine is tried again, then with its fallback model", async () => {
  const e = { base: "x", model: "main", host: "x", key: "", fallback: "spare" };
  const asked: string[] = [];
  const answer = await patiently(e, (x) => {
    asked.push(x.model);
    if (x.model === "main") throw new Error("engine 503 high demand");
    return Promise.resolve("read");
  }, 0);
  assertEquals(answer, "read");
  assertEquals(asked, ["main", "main", "spare"]);
});

Deno.test("any other failure is not tried again", async () => {
  const e = { base: "x", model: "main", host: "x", key: "", fallback: "spare" };
  let calls = 0;
  await assertRejects(() =>
    patiently(e, () => {
      calls++;
      throw new Error("engine 400 Invalid Auth key");
    }, 0)
  );
  assertEquals(calls, 1);
});

Deno.test("a spent daily allowance goes straight to the fallback", async () => {
  const e = { base: "x", model: "main", host: "x", key: "", fallback: "spare" };
  const asked: string[] = [];
  await patiently(e, (x) => {
    asked.push(x.model);
    if (x.model === "main") {
      throw new Error("engine 429 RESOURCE_EXHAUSTED free tier");
    }
    return Promise.resolve("read");
  }, 0);
  assertEquals(asked, ["main", "spare"]);
});

Deno.test("the fallback models are tried in turn", async () => {
  const e = {
    base: "x",
    model: "main",
    host: "x",
    key: "",
    fallback: "spare-1, spare-2",
  };
  const asked: string[] = [];
  const answer = await patiently(e, (x) => {
    asked.push(x.model);
    if (x.model !== "spare-2") throw new Error("engine 503 high demand");
    return Promise.resolve("read");
  }, 0);
  assertEquals(answer, "read");
  assertEquals(asked, ["main", "main", "spare-1", "spare-2"]);
});

Deno.test("no call starts once the time budget is spent", async () => {
  const e = { base: "x", model: "main", host: "x", key: "", fallback: "a,b" };
  let calls = 0;
  await assertRejects(() =>
    patiently(
      e,
      async (x) => {
        calls++;
        assertEquals(x.timeoutMs! <= 2_500, true);
        await new Promise((r) => setTimeout(r, 600));
        throw new Error("engine 503 high demand");
      },
      0,
      2_500,
    )
  );
  assertEquals(calls, 1);
});
