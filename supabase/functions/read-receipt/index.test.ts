// Run: deno test supabase/functions/read-receipt/
import { assertEquals } from "jsr:@std/assert@1";
import {
  fieldsFound,
  isPrivateHost,
  parseAnswer,
  toCents,
  toDay,
  toResponse,
} from "./index.ts";

const today = new Date("2026-11-20T12:00:00Z");

Deno.test("amounts become centimes, whatever their writing", () => {
  assertEquals(toCents("240.00"), 24000);
  assertEquals(toCents("240,5"), 24050);
  assertEquals(toCents(45), 4500);
  assertEquals(toCents("0"), null);
  assertEquals(toCents("1 240,00"), null);
  assertEquals(toCents(null), null);
});

Deno.test("only real days up to today", () => {
  assertEquals(toDay("2026-11-19", today), "2026-11-19");
  assertEquals(toDay("2026-02-30", today), null);
  assertEquals(toDay("2027-01-01", today), null);
  assertEquals(toDay("19/11/2026", today), null);
});

Deno.test("the answer is checked again before it reaches the app", () => {
  const r = toResponse({
    readable: true,
    supplier: "  مطعم الأندلس ",
    supplier_ice: "001 234 567 000 089",
    date: "2026-11-18",
    total: "240.00",
    vat: "300.00",
    vat_rate: 15,
    currency: "dh",
  }, today);
  assertEquals(r, {
    unreadable: false,
    supplier: "مطعم الأندلس",
    supplier_ice: "001234567000089",
    date: "2026-11-18",
    amount_cents: 24000,
    vat_cents: null,
    vat_rate: null,
    currency: "MAD",
  });
  assertEquals(fieldsFound(r), 5);
  assertEquals(toResponse({ readable: false }, today), { unreadable: true });
});

Deno.test("a JSON answer, even inside a code fence", () => {
  const r = parseAnswer(
    '```json\n{"readable": true, "total": 45, "currency": "MAD"}\n```',
  );
  assertEquals(r?.total, 45);
  assertEquals(parseAnswer("Je ne peux pas lire ce reçu."), null);
  assertEquals(parseAnswer('{"total": 45}'), null);
});

Deno.test("only the company's own hosts count as private", () => {
  assertEquals(isPrivateHost("host.docker.internal"), true);
  assertEquals(isPrivateHost("192.168.1.20"), true);
  assertEquals(isPrivateHost("ocr.atlas.lan", ["ocr.atlas.lan"]), true);
  assertEquals(isPrivateHost("generativelanguage.googleapis.com"), false);
  assertEquals(isPrivateHost("172.40.0.1"), false);
});
