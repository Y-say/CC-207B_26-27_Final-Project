import {
  recommendPharmacyAnswer,
  wantsLiveReservationData,
  type OfferFact,
  type MedicineFact,
} from "./guard.ts";
import type { ClientLocation, LoadedFacts } from "./facts.ts";

const ACTIVE = new Set(["pending", "confirmed", "ready_for_pickup"]);

function statusLabel(status: string): string {
  return status.replaceAll("_", " ");
}

export function isNearbyPharmacyQuery(message: string): boolean {
  return /near me|nearby|open now|closest pharmacy|pharmacies.*(open|near)|which pharmacy.*open/i.test(
    message,
  );
}

export function isDirectionsQuery(message: string): boolean {
  return /direction|navigate|how (do i|to) get|take me to|map to/i.test(message);
}

export function isPharmacyHoursQuery(message: string): boolean {
  return /(is|are).*(open|close)|operating hours|opening hours|what time.*(open|close)/i.test(
    message,
  );
}

export function isLowestPriceQuery(message: string): boolean {
  return /cheapest|lowest price|most affordable|best price/i.test(message);
}

export function isReservationTrackingQuery(message: string): boolean {
  return wantsLiveReservationData(message) ||
    /pickup code|my reserv/i.test(message.toLowerCase());
}

export function needsLiveMeditechData(message: string): boolean {
  return (
    isReservationTrackingQuery(message) ||
    isCancelReservationQuery(message) ||
    isNearbyPharmacyQuery(message) ||
    isLowestPriceQuery(message) ||
    isDirectionsQuery(message)
  );
}

export function isCancelReservationQuery(message: string): boolean {
  return /cancel (my )?(reservation|order)/i.test(message);
}

function locationBlockedAnswer(location: ClientLocation): string | null {
  const status = location.status ?? "unknown";
  if (status === "granted") return null;
  if (status === "services_disabled") {
    return [
      "I need your device location to list pharmacies near you.",
      "Turn on Location in your phone quick settings, then allow MediTech to use it (Settings → Apps → MediTech → Permissions → Location).",
      "You can still use Search and the Map tab to browse pharmacies manually.",
    ].join(" ");
  }
  if (status === "denied" || status === "denied_forever") {
    return [
      "Location permission is off, so I cannot see pharmacies near you yet.",
      "Open Settings → Apps → MediTech → Permissions → Location → Allow.",
      "Or open the Map tab in MediTech to pick a pharmacy on the map.",
    ].join(" ");
  }
  if (status === "loading") {
    return "Your location is still loading. Wait a moment on this screen and ask again, or open Search to browse pharmacies.";
  }
  return [
    "I do not have your location yet.",
    "Allow location for MediTech, or open Map / Search to choose a pharmacy yourself.",
  ].join(" ");
}

export function answerNearbyOpenPharmaciesFixed(
  facts: LoadedFacts,
  message: string,
  location: ClientLocation,
): string | null {
  if (!isNearbyPharmacyQuery(message)) return null;

  const blocked = locationBlockedAnswer(location);
  if (blocked) return blocked;

  const nearby = facts.forModel.nearby_pharmacies as {
    name: string;
    address: string;
    distance_km: number;
    hours_today: string;
    open_now: boolean;
  }[] | undefined;

  if (!nearby?.length) {
    return "No partner pharmacy locations are on file in MediTech near you right now. Try Search or the Map tab.";
  }

  const open = nearby.filter((b) => b.open_now);
  const lines = (open.length > 0 ? open : nearby).slice(0, 5).map((b, i) =>
    `${i + 1}. ${b.name} — ${b.distance_km} km — ${b.address} — ${b.hours_today}`
  );

  const header = open.length > 0
    ? `Here are partner pharmacies open near you${location.label ? ` (${location.label})` : ""}:`
    : `No partner pharmacies show as open near you right now. Nearest branches:`;

  return [
    header,
    ...lines,
    "",
    "Open Map in MediTech for directions, or tap a pharmacy in Search for details.",
  ].join("\n");
}

export function answerDirections(facts: LoadedFacts, message: string): string | null {
  if (!isDirectionsQuery(message)) return null;
  const branches = facts.forModel.branches_index as {
    id: string;
    name: string;
    address: string;
  }[] | undefined;
  if (!branches?.length) return "I do not have pharmacy addresses in MediTech right now.";

  const lower = message.toLowerCase();
  const hit = branches.find((b) => lower.includes(b.name.toLowerCase().split(" ")[0]));
  const target = hit ?? branches[0];
  return [
    `${target.name}`,
    `Address: ${target.address}`,
    "",
    "In MediTech: open the Map tab (bottom navigation) for directions, or Search → tap the branch → Get directions.",
    `You can also open /map?branch=${target.id} after navigating in the app.`,
  ].join("\n");
}

export function answerLowestPrice(
  medicines: MedicineFact[],
  offers: OfferFact[],
): string | null {
  if (medicines.length === 0 || offers.length === 0) return null;
  const sorted = [...offers]
    .filter((o) => !/unavailable|unconfirmed/i.test(o.availability))
    .sort((a, b) => Number.parseFloat(a.price) - Number.parseFloat(b.price));
  if (sorted.length === 0) {
    return "That medicine is on MediTech but no branch is showing available stock right now.";
  }
  const best = sorted[0];
  const med = medicines[0];
  return [
    `Lowest listed price for ${med.brand_name} (${med.generic_name}, ${med.strength}) on MediTech:`,
    `${best.pharmacy} — ₱${best.price} (${best.availability})`,
    sorted.length > 1
      ? `Next options: ${sorted.slice(1, 3).map((o) => `${o.pharmacy} ₱${o.price}`).join("; ")}`
      : "",
    "",
    "Open Search → tap the medicine → compare offers before reserving.",
  ].filter((line) => line.length > 0).join("\n");
}

type ReservationFact = {
  reference_no: string;
  status: string;
  pickup_code: string | null;
  expires_at: string;
  pharmacy: string;
  address: string;
  items: { brand_name: string; quantity: number }[];
};

function mentionReference(message: string, reservations: ReservationFact[]): ReservationFact | null {
  const upper = message.toUpperCase();
  return reservations.find((r) => upper.includes(r.reference_no.toUpperCase())) ?? null;
}

export function answerReservationQueries(
  facts: LoadedFacts,
  message: string,
): string | null {
  const reservations = (facts.forModel.reservations ?? []) as ReservationFact[];
  if (reservations.length === 0 && isReservationTrackingQuery(message)) {
    return "You do not have any reservations on MediTech yet. Search for a medicine, add it to your cart, and place a reservation.";
  }

  if (/track my|list my|show my|all my reserv/i.test(message.toLowerCase()) && reservations.length > 0) {
    const lines = reservations.slice(0, 8).map((r) => {
      const code = r.pickup_code ? ` — pickup code ${r.pickup_code}` : "";
      return `- ${r.reference_no}: ${statusLabel(r.status)} at ${r.pharmacy}${code}`;
    });
    return [
      "Your reservations on MediTech (most recent first):",
      ...lines,
      "",
      "Open My Reservations in the app for details, pickup QR, and cancellation.",
    ].join("\n");
  }

  const active = reservations.filter((r) => ACTIVE.has(r.status));
  const specified = mentionReference(message, reservations);

  if (isCancelReservationQuery(message)) {
    const cancellable = reservations.filter((r) => r.status === "pending");
    if (cancellable.length === 0) {
      return [
        "Only Pending reservations can be cancelled in the app.",
        "If yours is Confirmed or Ready for pickup, contact the pharmacy branch directly.",
        "Open My Reservations to see each status.",
      ].join(" ");
    }
    if (cancellable.length === 1) {
      return [
        `You can cancel ${cancellable[0].reference_no} while it is still Pending.`,
        "Open My Reservations → tap the reservation → Cancel reservation → confirm.",
      ].join(" ");
    }
    return [
      "You have more than one Pending reservation. Open My Reservations and cancel the one you mean:",
      ...cancellable.map((r) => `- ${r.reference_no} at ${r.pharmacy}`),
    ].join("\n");
  }

  if (!isReservationTrackingQuery(message) && !/expire/i.test(message)) return null;

  if (active.length > 1 && !specified && !/all|each|list/i.test(message)) {
    return [
      "You have more than one active reservation. Which one do you mean?",
      ...active.map((r) =>
        `- ${r.reference_no}: ${statusLabel(r.status)} at ${r.pharmacy}`
      ),
      "",
      "Reply with the reference number (for example RM-112726-0001) or ask about a specific status.",
    ].join("\n");
  }

  const focus = specified ?? active[0] ?? reservations[0];
  if (!focus) return null;

  const itemLines = focus.items.map((i) =>
    `- ${i.brand_name}, quantity ${i.quantity}`
  );

  if (/expire/i.test(message)) {
    return [
      `${focus.reference_no} expires on ${new Date(focus.expires_at).toLocaleString("en-PH", { timeZone: "Asia/Manila" })} (Philippines time).`,
      "If you do not pick up in time, the reservation may expire and stock will not be held.",
      `Status now: ${statusLabel(focus.status)}.`,
    ].join(" ");
  }

  if (/pickup|ready/i.test(message) && focus.status === "ready_for_pickup") {
    return [
      `${focus.reference_no} is Ready for pickup at ${focus.pharmacy}.`,
      focus.address ? `Address: ${focus.address}` : "",
      focus.pickup_code
        ? `Your pickup code is ${focus.pickup_code}. Show it at the counter (also on reservation details).`
        : "Open My Reservations → reservation details for your pickup code and QR.",
      itemLines.length ? ["Medicines:", ...itemLines].join("\n") : "",
    ].filter(Boolean).join("\n");
  }

  if (/medicine did i|what did i reserve/i.test(message)) {
    return [
      `${focus.reference_no} at ${focus.pharmacy}:`,
      ...itemLines,
      `Status: ${statusLabel(focus.status)}.`,
      focus.pickup_code ? `Pickup code (when ready): ${focus.pickup_code}` : "",
    ].filter(Boolean).join("\n");
  }

  return [
    `${focus.reference_no}: ${statusLabel(focus.status)}.`,
    `Pharmacy: ${focus.pharmacy}.`,
    focus.pickup_code ? `Pickup code: ${focus.pickup_code}` : "",
    itemLines.length ? `Items: ${itemLines.join("; ")}` : "",
    "Details: My Reservations in the app.",
  ].filter(Boolean).join(" ");
}

export function tryDeterministicAnswer(
  message: string,
  facts: LoadedFacts,
  location: ClientLocation,
  medicines: MedicineFact[],
  offers: OfferFact[],
): string | null {
  const nearby = answerNearbyOpenPharmaciesFixed(facts, message, location);
  if (nearby) return nearby;

  const directions = answerDirections(facts, message);
  if (directions) return directions;

  if (isLowestPriceQuery(message)) {
    const price = answerLowestPrice(medicines, offers);
    if (price) return price;
  }

  const reservation = answerReservationQueries(facts, message);
  if (reservation) return reservation;

  if (/recommend/i.test(message)) {
    return recommendPharmacyAnswer(medicines, offers);
  }

  return null;
}