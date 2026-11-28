import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  applyUpdate,
  type Draft,
  followUpByRules,
  parseJson,
  prompt,
  toUnderstanding,
} from "./conversation.ts";
import { parseMessage } from "./index.ts";

const taxi: Draft = {
  id: "d1",
  supplier: "Taxi",
  amountCents: 4500,
  category: "Transport",
  project: "",
  reason: "Taxi 45 DHS, course chez Marjane",
};

Deno.test("a missing client completes the taxi sent just before", () => {
  const u = toUnderstanding(
    { intent: "update", project: "Client Marjane", amount_mad: null },
    taxi,
  );
  assertEquals(u?.intent, "update");
  if (u?.intent !== "update") return;
  assertEquals(applyUpdate(taxi, u.fields), {
    ...taxi,
    project: "Client Marjane",
  });
});

Deno.test("a corrected amount replaces only the amount", () => {
  const u = toUnderstanding({ intent: "update", amount_mad: "50" }, taxi);
  if (u?.intent !== "update") throw new Error("update expected");
  assertEquals(applyUpdate(taxi, u.fields).amountCents, 5000);
  assertEquals(applyUpdate(taxi, u.fields).supplier, "Taxi");
});

Deno.test("an unknown category is not kept", () => {
  const u = toUnderstanding(
    { intent: "new", supplier: "Café", amount_mad: 30, category: "Boissons" },
    null,
  );
  assertEquals(u, {
    intent: "new",
    fields: {
      supplier: "Café",
      amountCents: 3000,
      category: null,
      project: null,
      reason: null,
    },
  });
});

Deno.test("without a draft, an update is a new expense, a cancel nothing", () => {
  assertEquals(toUnderstanding({ intent: "update" }, null)?.intent, "new");
  assertEquals(toUnderstanding({ intent: "cancel" }, null)?.intent, "other");
  assertEquals(toUnderstanding({ intent: "?" }, taxi), null);
});

Deno.test("without an engine, rules follow the conversation", () => {
  const text = "Il manque le client Marjane";
  const u = followUpByRules(text, taxi, parseMessage(text));
  assertEquals(u?.intent, "update");
  if (u?.intent === "update") {
    assertEquals(u.fields.project, "Client Marjane");
  }
  assertEquals(
    followUpByRules("annule", taxi, parseMessage("annule"))?.intent,
    "cancel",
  );
  // An amount is another expense; no draft, nothing to follow.
  const lunch = "Déjeuner 120 dh client Atlas";
  assertEquals(followUpByRules(lunch, taxi, parseMessage(lunch)), null);
  assertEquals(followUpByRules(text, null, parseMessage(text)), null);
});

Deno.test("the engine sees the day's turns and the draft", () => {
  const p = prompt(
    [
      { author: "person", body: "Taxi 45 DHS, course chez Marjane" },
      { author: "rembo", body: "Taxi · 45,00 MAD · Transport" },
    ],
    taxi,
    "Il manque le client Marjane",
  );
  assertStringIncludes(p, "Employee: Taxi 45 DHS");
  assertStringIncludes(p, "REMBO: Taxi · 45,00 MAD");
  assertStringIncludes(p, '"amount_mad":45');
  assertStringIncludes(p, "New message: Il manque le client Marjane");
});

Deno.test("the JSON object is found inside a code block", () => {
  assertEquals(parseJson('```json\n{"intent": "cancel"}\n```'), {
    intent: "cancel",
  });
});
