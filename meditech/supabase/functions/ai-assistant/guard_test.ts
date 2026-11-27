import { assertEquals } from "jsr:@std/assert@1";
import {
  appHelpAnswer,
  hasInventedFact,
  isAppHelp,
  isMedicineLookup,
  medicineNotListedAnswer,
  recommendPharmacyAnswer,
  refuseReason,
  wantsLiveReservationData,
} from "./guard.ts";

Deno.test("refuses dosing", () => {
  const message = refuseReason("how many tablets should I take") ?? "";
  assertEquals(message.includes("diagnosis"), true);
  assertEquals(message.includes("pharmacist"), true);
});

Deno.test("refuses an outside question", () => {
  const message = refuseReason("what is the weather today") ?? "";
  assertEquals(message.includes("MediTech"), true);
});

Deno.test("allows a medicine question", () => {
  assertEquals(refuseReason("where can I find paracetamol"), null);
});

Deno.test("allows an unknown brand medicine question", () => {
  assertEquals(refuseReason("where can I find aspirin 500mg"), null);
});

Deno.test("allows an app how-to question", () => {
  assertEquals(refuseReason("how do I place a reservation"), null);
});

Deno.test("treats an unknown medicine as a lookup", () => {
  assertEquals(isMedicineLookup("Is Advil 200mg available?"), true);
});

Deno.test("does not treat nearby pharmacies as a medicine lookup", () => {
  assertEquals(isMedicineLookup("Which pharmacies are nearby?"), false);
});

Deno.test("does not treat app help as a medicine lookup", () => {
  assertEquals(isMedicineLookup("How do I search for medicine in the app?"), false);
});

Deno.test("detects app help", () => {
  assertEquals(isAppHelp("How do I place a reservation?"), true);
});

Deno.test("status question is not generic app help", () => {
  const q = "What is the status of my reservation?";
  assertEquals(wantsLiveReservationData(q), true);
  assertEquals(isAppHelp(q), false);
  assertEquals(appHelpAnswer(q).includes("Here's how reservations work"), false);
});

Deno.test("app help returns MediTech steps", () => {
  const answer = appHelpAnswer("How do I place a reservation?");
  assertEquals(answer.includes("My Reservations"), true);
  assertEquals(answer.includes("pickup code"), true);
});

Deno.test("has a clear not-listed answer", () => {
  assertEquals(
    medicineNotListedAnswer().includes("not listed on MediTech"),
    true,
  );
});

Deno.test("recommend from live offers", () => {
  const answer = recommendPharmacyAnswer(
    [{ brand_name: "Biogesic", generic_name: "Paracetamol", strength: "500 mg" }],
    [
      { pharmacy: "Demo Pharmacy La Paz", price: "5.50", availability: "available" },
      { pharmacy: "Another Branch", price: "6.00", availability: "low_stock" },
    ],
  );
  assertEquals(answer?.includes("Demo Pharmacy La Paz"), true);
  assertEquals(answer?.includes("Biogesic"), true);
});

Deno.test("blocks a made-up reservation reference", () => {
  const invented = hasInventedFact("Your reference is RM-010126-9999.", {
    prices: ["12.00"],
    referenceNumbers: ["RM-010126-0001"],
    pickupCodes: [],
  });
  assertEquals(invented, true);
});

Deno.test("allows a real price", () => {
  const invented = hasInventedFact("It costs 12.00.", {
    prices: ["12.00"],
    referenceNumbers: [],
    pickupCodes: [],
  });
  assertEquals(invented, false);
});