import { assertEquals } from "jsr:@std/assert@1";
import {
  answerNearbyOpenPharmaciesFixed,
  answerReservationQueries,
  isNearbyPharmacyQuery,
  isReservationTrackingQuery,
  needsLiveMeditechData,
} from "./handlers.ts";
import type { LoadedFacts } from "./facts.ts";

Deno.test("detects nearby pharmacy questions", () => {
  assertEquals(
    isNearbyPharmacyQuery("What pharmacies are open near me right now?"),
    true,
  );
});

Deno.test("tracks reservation status instead of generic app help", () => {
  assertEquals(isReservationTrackingQuery("What is the status of my reservation?"), true);
  assertEquals(isReservationTrackingQuery("Track my reservations"), true);
  assertEquals(needsLiveMeditechData("Track my reservations"), true);
  assertEquals(isReservationTrackingQuery("How do I place a reservation?"), false);
});

Deno.test("lists reservations when user asks to track", () => {
  const facts = {
    check: { prices: [], referenceNumbers: ["RM-112726-0001"], pickupCodes: [] },
    forModel: {
      reservations: [{
        reference_no: "RM-112726-0001",
        status: "confirmed",
        pickup_code: null,
        expires_at: "2026-12-01T00:00:00Z",
        pharmacy: "Demo Pharmacy La Paz",
        address: "12 Rizal St",
        items: [{ brand_name: "Biogesic", quantity: 2 }],
      }],
    },
  };
  const answer = answerReservationQueries(facts, "Track my reservations");
  assertEquals(answer?.includes("RM-112726-0001"), true);
  assertEquals(answer?.includes("confirmed"), true);
});

Deno.test("explains when location denied", () => {
  const facts: LoadedFacts = {
    check: { prices: [], referenceNumbers: [], pickupCodes: [] },
    forModel: { nearby_pharmacies: [] },
  };
  const answer = answerNearbyOpenPharmaciesFixed(
    facts,
    "pharmacies open near me",
    { status: "denied" },
  );
  assertEquals(answer?.includes("permission"), true);
});