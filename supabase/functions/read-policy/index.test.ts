import { assertEquals } from "jsr:@std/assert@1";
import { parseJson, toCents, toProposal } from "./index.ts";

Deno.test("amounts are read as dirhams", () => {
  assertEquals(toCents(150), 15000);
  assertEquals(toCents("1 200,50"), 120050);
  assertEquals(toCents("1.200 DH"), 120000);
  assertEquals(toCents("200 MAD"), 20000);
  assertEquals(toCents(-5), null);
  assertEquals(toCents("aucun"), null);
});

Deno.test("only rules REMBO can apply are kept", () => {
  const p = toProposal({
    summary: "Politique de frais",
    deadline_days: 30,
    project_required: true,
    rules: [
      { category: "repas", limit_mad: 150, receipt_required: true },
      { category: "Repas", limit_mad: 999 }, // twice: the first one wins
      { category: "Alcool", limit_mad: 50 }, // unknown category
      { category: "Transport", limit_mad: "aucun" }, // no amount
      { category: "Hébergement", limit_mad: "800", receipt_required: false },
    ],
    not_applied: ["Pas d'alcool", "", 42],
  });
  assertEquals(p, {
    summary: "Politique de frais",
    deadline_days: 30,
    project_required: true,
    rules: [
      { category: "Repas", limit_cents: 15000, receipt_required: true },
      { category: "Hébergement", limit_cents: 80000, receipt_required: false },
    ],
    not_applied: ["Pas d'alcool"],
  });
});

Deno.test("an out-of-range deadline is left out", () => {
  const p = toProposal({ deadline_days: 900, project_required: false });
  assertEquals(p?.deadline_days, null);
  assertEquals(p?.project_required, false);
});

Deno.test("a document that is not a policy gives nothing", () => {
  assertEquals(toProposal({ unreadable: true }), null);
  assertEquals(toProposal({ summary: "Une recette de cuisine" }), null);
  assertEquals(toProposal(null), null);
});

Deno.test("the JSON object is found inside a code block", () => {
  assertEquals(parseJson('```json\n{"deadline_days": 15}\n```'), {
    deadline_days: 15,
  });
  assertEquals(parseJson("pas de JSON"), null);
});
