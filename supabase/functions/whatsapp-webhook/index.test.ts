// Run with: deno test --allow-env supabase/functions/whatsapp-webhook/
import { assertEquals } from "jsr:@std/assert@1";

// The module opens a database client when it loads: give it placeholders.
Deno.env.set("SUPABASE_URL", "http://localhost:54321");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test");
const { parseMessage } = await import("./index.ts");

Deno.test("the amount is the number written with a currency", () => {
  assertEquals(parseMessage("2 taxis, 45 dh").amountCents, 4500);
  assertEquals(parseMessage("Déjeuner 3 personnes 380,50 dirhams").amountCents, 38050);
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
