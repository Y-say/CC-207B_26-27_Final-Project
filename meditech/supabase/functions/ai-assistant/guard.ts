// Decide which questions to refuse, and which replies invented a fact

export type AiFacts = {
  prices: string[];
  referenceNumbers: string[];
  pickupCodes: string[];
};

// ─── Refusal patterns ─────────────────────────────────────────────────────────

// Medical advice: diagnosis, dosing, treatment — always refused
// NOTE: "prescription" is intentionally excluded — "do I need a prescription?"
// is a valid app question. Only "prescrib" (prescribe/prescribed) is blocked.
const dosingOrDiagnosis =
  /diagnos|dosage|\bdose\b|how many (tablet|tablets|capsule|capsules|ml|mg)|how much should i take|side effect|symptom|pregnant|what (medicine|drug) should i|treatment|\bcure\b|prescrib/i;

// Clearly off-topic — no connection to MediTech or health at all
const outsideMeditech =
  /weather|joke|homework|write (me )?code|politic|president|prime minister|movie|song lyric|recipe|stock market|bitcoin|crypto|another (customer|person)|someone else|\bwho (are|is) you\b|tell me about yourself|roleplay|pretend (you are|to be)|act as|ignore (your|all) (previous|prior|instructions)|jailbreak/i;

// Topics that ARE about MediTech — used to catch edge cases the other patterns miss
const aboutMeditech =
  /meditech|medicine|pharmacy|pharmacies|reserve|reservation|pickup|price|stock|available|brand|generic|find|where|offer|\bmg\b|tablet|capsule|syrup|biogesic|paracetamol|cart|search|sign ?in|sign ?up|profile|notification|assistant|account|how (do|to|can)|help|recommend|steps?|app|cancel|address|change pharmacy|confirm|confirmed|ready|reject|rejected|prescription|rx\b|upload|password|guest/i;

// ─── App help patterns ────────────────────────────────────────────────────────

// Questions that should be answered with a hardcoded app guide (no Gemini call)
const appHelp =
  /how (do|to|can)|steps?|help|recommend|what is meditech|about (the )?app|sign ?in|sign ?up|cart|profile|notification|forgot password|guest|pickup code|my reservation|use (the )?app|walk me through|change pharmacy|cancel(lation)?|cancel.*(reservation|order)|address|saved address|ready for pickup|confirmed|notification preference|upload.*(prescription|rx)|prescription.*upload|do i need.*prescription|is.*rx|password/i;

// ─── App guide (served directly — no Gemini, no DB) ──────────────────────────

export const appGuide = {
  what_meditech_is:
    "MediTech helps customers find medicines at partner pharmacies, compare prices, and reserve for pickup. It does not give medical or dosing advice.",
  main_steps: [
    "1. Sign in with your email or mobile number, or continue as guest to browse.",
    "2. Use Search or Home to look up a medicine by brand or generic name.",
    "3. Open a medicine to see pharmacy offers. Add Available or Low Stock items to your cart.",
    "4. Your cart is locked to one pharmacy branch. Change Pharmacy in the cart shows other branches carrying the same medicines.",
    "5. Upload a prescription photo in the cart when an Rx item is in it.",
    "6. Tick the acknowledgment checkbox and tap Continue to Reservation.",
    "7. Track progress under My Reservations.",
    "8. Confirmed — the pharmacy accepted your request and is preparing your medicine.",
    "9. Ready for Pickup — medicine is on the counter. Your pickup code appears on the reservation details.",
    "10. Show the pickup code at the pharmacy counter to collect your order.",
    "11. You can cancel a Pending reservation before the pharmacy confirms it.",
  ],
  reservation_statuses: [
    "Pending — waiting for the pharmacy to review your request.",
    "Confirmed — pharmacy accepted; medicine is being prepared. No pickup code yet.",
    "Ready for Pickup — medicine is ready. Pickup code is now visible in the reservation details.",
    "Completed — you collected the medicine. The pickup code was verified.",
    "Rejected — pharmacy declined your request. A reason is shown.",
    "Cancelled — you or the pharmacy cancelled before completion.",
    "Expired — the reservation was not acted on within the allowed time.",
  ],
  recommendations: [
    "Prefer pharmacies marked Available. Low Stock can still be reserved but may run out.",
    "If several pharmacies list the same medicine, compare price and availability in the offers list.",
    "If a medicine is not listed, it is not on MediTech yet. Try another brand or generic name in Search.",
    "Use this Assistant for listings, offers, your reservations, and how to use the app. Ask a pharmacist or doctor for dosing or diagnosis.",
  ],
  limits: [
    "Customers can cancel a Pending reservation only.",
    "Only medicines shown in MediTech can be recommended.",
    "Never invent a price, availability, reservation status, reference number, or pickup code.",
  ],
};

// ─── Classification helpers ───────────────────────────────────────────────────

// True when the customer is asking about a medicine listing (triggers DB lookup + Gemini)
export function isMedicineLookup(message: string): boolean {
  // App how-to questions that mention "medicine" should stay in appHelp
  if (appHelp.test(message)) return false;
  if (/reserv|pickup|reference/i.test(message)) return false;
  if (/nearby pharmac|pharmacies (near|around)|open now/i.test(message)) return false;
  return /find|where|available|stock|price|offer|listed|listing|brand|generic|\bmg\b|tablet|capsule|syrup|medicine/i
    .test(message);
}

export type MedicineFact = { brand_name: string; generic_name: string; strength: string };
export type OfferFact = { pharmacy: string; price: string; availability: string };

function availabilityRank(value: string): number {
  const v = value.toLowerCase();
  if (v === "available") return 0;
  if (v === "low_stock" || v === "lowstock") return 1;
  return 2;
}

function availabilityLabel(value: string): string {
  const v = value.toLowerCase();
  if (v === "available") return "Available";
  if (v === "low_stock" || v === "lowstock") return "Low stock";
  return value;
}

/** Pharmacy picks from live MediTech offers — no Gemini required. */
export function recommendPharmacyAnswer(
  medicines: MedicineFact[],
  offers: OfferFact[],
): string | null {
  if (medicines.length === 0 || offers.length === 0) return null;
  const med = medicines[0];
  const sorted = [...offers].sort((a, b) => {
    const byStock = availabilityRank(a.availability) - availabilityRank(b.availability);
    if (byStock !== 0) return byStock;
    return Number.parseFloat(a.price) - Number.parseFloat(b.price);
  });
  const lines = sorted.slice(0, 3).map(
    (offer, index) =>
      `${index + 1}. ${offer.pharmacy} — ₱${offer.price} (${availabilityLabel(offer.availability)})`,
  );
  return [
    `For ${med.brand_name} (${med.generic_name}, ${med.strength}), these partner pharmacies are on MediTech right now:`,
    ...lines,
    "",
    "Open Search, tap the medicine, and add an offer to your cart. Prefer Available over Low stock.",
  ].join("\n");
}

// What to say when MediTech has no matching medicine listed
export function medicineNotListedAnswer(): string {
  return (
    "That medicine is not listed on MediTech yet. " +
    "Try searching by brand name, generic name, or strength in the Search tab. " +
    "If it still doesn't appear, it may not be carried by any partner pharmacy at this time."
  );
}

// Status / track / list — must use live reservations from the database, not how-to text.
export function wantsLiveReservationData(message: string): boolean {
  const lower = message.toLowerCase();
  if (/how (do|to|can).*(place|make|submit).*reserv/i.test(lower)) return false;
  return /track my|list my|show my|all my reserv|status of my|what.?s the status|how.?s my order|how are my reserv|order status|reservation status|when.*expire|what medicine did i|where.*pick up|what did i reserve/i
    .test(lower);
}

// True when the customer wants app how-to help (answered with canned text, no Gemini)
export function isAppHelp(message: string): boolean {
  if (wantsLiveReservationData(message)) return false;
  // "Recommend a pharmacy for [specific medicine]" should use live offers via Gemini
  if (
    /recommend/i.test(message) &&
    /\bmg\b|tablet|capsule|syrup|for [a-z]|biogesic|paracetamol|amoxicillin|metformin|losartan|amlodipine|cetirizine|omeprazole/i.test(message) &&
    !/how (do|to|can)|steps|what is meditech|sign ?in|cart|profile/i.test(message)
  ) {
    return false;
  }
  return appHelp.test(message);
}

// ─── Canned app-help answers (no Gemini, no DB) ──────────────────────────────

export function appHelpAnswer(message: string): string {
  const lower = message.toLowerCase();

  // Reservation workflow (not live status — that uses wantsLiveReservationData above)
  if (
    !wantsLiveReservationData(message) &&
    /reserv|pickup code|ready for pickup|confirmed|how.*(order|place|submit)/.test(lower)
  ) {
    return [
      "Reservation process in MediTech:",
      "1. Search for a medicine and open one listed in the app.",
      "2. Choose a pharmacy offer marked Available or Low Stock and add it to your cart.",
      "3. One pharmacy per cart. Sign in if you are still a guest.",
      "4. Upload a prescription photo in the cart if any item needs one.",
      "5. Tick the acknowledgment and tap Continue to Reservation.",
      "6. Track progress under My Reservations.",
      "7. Confirmed — pharmacy accepted. Your medicine is being prepared. No pickup code yet.",
      "8. Ready for Pickup — medicine is on the counter. Your pickup code now appears on the reservation details.",
      "9. Show the code at the pharmacy counter to collect your order.",
      "",
      "You can cancel a Pending reservation before the pharmacy confirms it.",
      "Ask a pharmacist or doctor for medical advice — this assistant covers the app only.",
    ].join("\n");
  }

  // Cancellation
  if (/cancel/.test(lower)) {
    return [
      "Cancellation rules in MediTech:",
      "- You can cancel a reservation while it is still Pending (before the pharmacy confirms it).",
      "- Once Confirmed, Ready for Pickup, or Completed, you cannot cancel from the app.",
      "- To cancel: open My Reservations → tap the reservation → tap Cancel reservation.",
      "- The pharmacy will no longer prepare the order and no stock will be held.",
    ].join("\n");
  }

  // Reservation statuses
  if (/status|pending|confirmed|ready|rejected|expired|completed/.test(lower)) {
    return [
      "Reservation statuses in MediTech:",
      ...appGuide.reservation_statuses.map((s) => `- ${s}`),
    ].join("\n");
  }

  // Prescription / Rx
  if (/prescription|rx\b|upload|do i need/.test(lower)) {
    return [
      "Prescriptions in MediTech:",
      "- Items marked Rx require a prescription. You will see an Rx badge on the medicine and in your cart.",
      "- Upload a photo of your prescription (JPG, PNG, or PDF, max 5 MB) in the cart before placing the reservation.",
      "- You can upload up to 3 files. Bring the original prescription to the pharmacy when you collect your order.",
      "- The pharmacist checks the prescription before confirming your reservation.",
    ].join("\n");
  }

  // Change pharmacy
  if (/change pharmacy|switch pharmacy|different pharmacy/.test(lower)) {
    return [
      "To change the pharmacy in your cart:",
      "- Open your cart and tap Change Pharmacy in the branch banner.",
      "- MediTech shows pharmacies that carry the same medicines you already have in your cart.",
      "- Tap Switch to this pharmacy — your cart items are moved to the new branch.",
      "- If no alternatives appear, no other registered pharmacy currently carries all your medicines.",
    ].join("\n");
  }

  // Saved addresses
  if (/address|saved address/.test(lower)) {
    return [
      "Saved addresses in MediTech:",
      "- Go to Profile → Saved Addresses to add, edit, or remove addresses.",
      "- You can set one address as your default.",
      "- Addresses are used to show pharmacies near you and to pre-fill delivery details.",
    ].join("\n");
  }

  // Notifications
  if (/notification/.test(lower)) {
    return [
      "Notifications in MediTech:",
      "- You receive a notification when your reservation status changes (confirmed, ready for pickup, rejected, etc.).",
      "- Manage which channels notify you under Profile → Notification Preferences.",
      "- You can turn push, email, or SMS notifications on or off independently.",
    ].join("\n");
  }

  // Account / sign-in / sign-up / password
  if (/sign ?in|sign ?up|account|guest|forgot password|profile|password/.test(lower)) {
    return [
      "Account help in MediTech:",
      "- Sign in with your email address or mobile number and password.",
      "- New? Tap Create account on the sign-in screen. You must be 18 or older to register.",
      "- Guests can browse and search, but need to sign in to use the cart, place reservations, and view reservation history.",
      "- Forgot your password? Tap Forgot password on the sign-in screen for a 6-digit code by email.",
      "- Change your profile details under Profile → Edit Profile.",
      "- Change your password under Profile → Change Password.",
    ].join("\n");
  }

  // Recommendation (generic)
  if (/recommend/.test(lower)) {
    return [
      "In MediTech I only recommend from medicines and offers listed in the app:",
      "- Prefer pharmacies marked Available. Low Stock can still be reserved, but may run out.",
      "- Compare price and availability on the medicine's offer list.",
      "- Ask me about a specific medicine (for example Biogesic or paracetamol) for pharmacy options.",
      "- If it isn't in Search, it isn't on MediTech yet.",
      "",
      appGuide.what_meditech_is,
    ].join("\n");
  }

  // Generic app overview
  return [
    appGuide.what_meditech_is,
    "",
    "How to use MediTech:",
    ...appGuide.main_steps,
    "",
    "Tips:",
    ...appGuide.recommendations.map((tip) => `- ${tip}`),
  ].join("\n");
}

// ─── Refusal function ─────────────────────────────────────────────────────────

export function refuseReason(message: string): string | null {
  if (dosingOrDiagnosis.test(message)) {
    return (
      "I am not able to provide diagnosis, dosing, or treatment advice. " +
      "Please consult a pharmacist or physician. " +
      "I can assist with finding medicines on MediTech, checking availability, or explaining how reservations work."
    );
  }
  if (outsideMeditech.test(message)) {
    return "I can assist only with the MediTech app: medicines, pharmacies, your reservations, and how to use the app.";
  }
  // If nothing in the message relates to MediTech at all, refuse
  if (!aboutMeditech.test(message)) {
    return "I can assist only with the MediTech app: medicines, pharmacies, your reservations, and how to use the app.";
  }
  return null;
}

// ─── Hallucination guard ──────────────────────────────────────────────────────

// Returns true when the reply contains a reference number or pickup code
// that was not in the facts loaded from the database.
// Price checking was removed — it caused too many false positives when Gemini
// reformatted or rounded numbers.
export function hasInventedFact(reply: string, facts: AiFacts): boolean {
  // Reference numbers: RM-MMDDYY-XXXX format
  const references = reply.match(/RM-\d{6}-[A-Za-z0-9]{4,5}/gi) ?? [];
  if (references.some((ref) => !facts.referenceNumbers.includes(ref.toUpperCase()))) {
    return true;
  }

  // Pickup codes: 4-character alphanumeric after "pickup code"
  const pickup = reply.match(/pickup code[^A-Za-z0-9]*([A-Za-z0-9]{4})\b/i);
  if (pickup && !facts.pickupCodes.includes(pickup[1].toUpperCase())) {
    return true;
  }

  return false;
}
