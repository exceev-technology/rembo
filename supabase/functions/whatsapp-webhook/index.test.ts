// Run with: deno test --allow-env supabase/functions/whatsapp-webhook/
import { assertEquals } from "jsr:@std/assert@1";

// Placeholders, in case a test reaches the database client.
Deno.env.set("SUPABASE_URL", "http://localhost:54321");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test");
const { fromReading, parseMessage, validSignature } = await import(
  "./index.ts"
);

Deno.test("the amount is the number written with a currency", () => {
  assertEquals(parseMessage("2 taxis, 45 dh").amountCents, 4500);
  assertEquals(
    parseMessage("Déjeuner 3 personnes 380,50 dirhams").amountCents,
    38050,
  );
  assertEquals(parseMessage("Parking 2 heures 12.5 MAD").amountCents, 1250);
  assertEquals(parseMessage("طاكسي 2 أشخاص 45 درهم").amountCents, 4500);
});

Deno.test("without a currency, the first number is the amount", () => {
  assertEquals(parseMessage("Taxi 45, client Atlas").amountCents, 4500);
  assertEquals(parseMessage("Café Atlas").amountCents, 0);
});

Deno.test("a word starting like a currency is not one", () => {
  assertEquals(parseMessage("Hotel 2 made 300 mad").amountCents, 30000);
});

Deno.test("the other fields keep being read", () => {
  const p = parseMessage("Taxi, 45 dirhams, client Atlas");
  assertEquals(p.supplier, "Taxi");
  assertEquals(p.category, "Transport");
  assertEquals(p.project, "Client Atlas");
});

Deno.test("a transcribed voice note in darija reads the same", () => {
  const p = parseMessage("طاكسي 30 درهم");
  assertEquals(p.amountCents, 3000);
  assertEquals(p.category, "Transport");
});

Deno.test("a photo's reading wins, its caption adds the context", () => {
  const { parsed, extra } = fromReading({
    supplier: "Café Atlas",
    supplier_ice: "001234567000089",
    date: "2026-11-18",
    amount_cents: 24000,
    vat_cents: 2182,
    vat_rate: 10,
    currency: "MAD",
  }, "déjeuner client Atlas");
  assertEquals(parsed.supplier, "Café Atlas");
  assertEquals(parsed.amountCents, 24000);
  assertEquals(parsed.category, "Repas");
  assertEquals(parsed.project, "Client Atlas");
  assertEquals(extra.expense_date, "2026-11-18");
  assertEquals(extra.vat_rate, 10);
});

Deno.test("a receipt in euros keeps the paid amount apart", () => {
  const { parsed, extra } = fromReading(
    { supplier: "Uber London", amount_cents: 2240, currency: "GBP" },
    "",
  );
  assertEquals(parsed.amountCents, 0);
  assertEquals(extra.currency, "GBP");
  assertEquals(extra.foreign_amount_cents, 2240);
  assertEquals(parsed.reason, "Reçu Uber London");
});

Deno.test("only Meta's signature opens the door", async () => {
  Deno.env.set("WHATSAPP_APP_SECRET", "secret-de-test");
  const body = '{"entry":[]}';
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode("secret-de-test"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)),
  );
  const hex = Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
  assertEquals(await validSignature(body, `sha256=${hex}`), true);
  assertEquals(await validSignature(body + " ", `sha256=${hex}`), false);
  assertEquals(await validSignature(body, null), false);
});
