import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { appGuide, type AiFacts } from "./guard.ts";

export type ClientLocation = {
  status?: string;
  latitude?: number;
  longitude?: number;
  label?: string;
  weekday?: number;
  minutes_since_midnight?: number;
};

export type BranchHourRow = {
  weekday: number;
  opens_at: string;
  closes_at: string;
  is_closed: boolean;
};

export type LoadedFacts = {
  check: AiFacts;
  forModel: Record<string, unknown>;
};

export function money(value: unknown): string {
  return Number(value).toFixed(2);
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const r = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) ** 2;
  return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function parseTimeToMinutes(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})/.exec(value.trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

export function branchOpenNow(
  hours: BranchHourRow[],
  weekday: number,
  minutesSinceMidnight: number,
): { open: boolean; label: string } {
  const today = hours.find((row) => row.weekday === weekday);
  if (!today || today.is_closed) {
    return { open: false, label: "Closed today" };
  }
  const opens = parseTimeToMinutes(today.opens_at);
  const closes = parseTimeToMinutes(today.closes_at);
  if (opens == null || closes == null) {
    return { open: false, label: "Hours not on file" };
  }
  if (minutesSinceMidnight < opens) {
    return { open: false, label: `Opens at ${today.opens_at.slice(0, 5)}` };
  }
  if (minutesSinceMidnight >= closes) {
    return { open: false, label: `Closed (hours ${today.opens_at.slice(0, 5)}–${today.closes_at.slice(0, 5)})` };
  }
  return {
    open: true,
    label: `Open until ${today.closes_at.slice(0, 5)}`,
  };
}

function activeReservationStatuses(): string[] {
  return ["pending", "confirmed", "ready_for_pickup"];
}

function extractWords(message: string): string[] {
  return message
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 3 &&
      !["where", "find", "medicine", "pharmacy", "price", "with", "your", "have", "does", "what", "when", "near", "open"].includes(word))
    .slice(0, 4);
}

export async function loadFacts(
  server: SupabaseClient,
  userId: string,
  message: string,
  location: ClientLocation,
): Promise<LoadedFacts> {
  const words = extractWords(message);
  let medicines: { id: string; brand_name: string; generic_name: string; strength: string }[] = [];
  if (words.length > 0) {
    const filter = words
      .map((word) => `brand_name.ilike.%${word}%,generic_name.ilike.%${word}%`)
      .join(",");
    const { data } = await server
      .from("medicines")
      .select("id, brand_name, generic_name, strength")
      .eq("status", "active")
      .or(filter)
      .limit(8);
    medicines = data ?? [];
  }

  const medicineIds = medicines.map((medicine) => medicine.id);
  const { data: offers } = medicineIds.length === 0
    ? { data: [] }
    : await server
      .from("public_availability")
      .select(
        "medicine_id, branch_id, price_per_unit, availability, stock_confirmed_at",
      )
      .in("medicine_id", medicineIds)
      .limit(40);

  const { data: allBranches } = await server
    .from("public_branches")
    .select("id, pharmacy_name, branch_name, address, latitude, longitude");

  const branchMap = new Map(
    (allBranches ?? []).map((b) => [
      b.id,
      {
        name: `${b.pharmacy_name} ${b.branch_name}`.trim(),
        address: b.address as string,
        latitude: b.latitude as number | null,
        longitude: b.longitude as number | null,
      },
    ]),
  );

  const { data: hoursRows } = await server
    .from("public_branch_hours")
    .select("branch_id, weekday, opens_at, closes_at, is_closed");

  const hoursByBranch = new Map<string, BranchHourRow[]>();
  for (const row of hoursRows ?? []) {
    const list = hoursByBranch.get(row.branch_id) ?? [];
    list.push({
      weekday: row.weekday,
      opens_at: String(row.opens_at),
      closes_at: String(row.closes_at),
      is_closed: row.is_closed === true,
    });
    hoursByBranch.set(row.branch_id, list);
  }

  const weekday = location.weekday ?? new Date().getUTCDay();
  const minutes = location.minutes_since_midnight ??
    (new Date().getUTCHours() * 60 + new Date().getUTCMinutes());

  const offerFacts = (offers ?? []).map((offer) => {
    const branch = branchMap.get(offer.branch_id);
    return {
      pharmacy: branch?.name ?? "Pharmacy",
      address: branch?.address ?? null,
      price: money(offer.price_per_unit),
      availability: offer.availability,
      stock_updated_at: offer.stock_confirmed_at ?? null,
    };
  });

  let nearby: {
    name: string;
    address: string;
    distance_km: number;
    hours_today: string;
    open_now: boolean;
    branch_id: string;
  }[] = [];

  const lat = location.latitude;
  const lng = location.longitude;
  const locationOk = location.status === "granted" && lat != null && lng != null;

  if (locationOk) {
    for (const branch of allBranches ?? []) {
      if (branch.latitude == null || branch.longitude == null) continue;
      const dist = haversineKm(lat!, lng!, Number(branch.latitude), Number(branch.longitude));
      const hours = hoursByBranch.get(branch.id) ?? [];
      const open = branchOpenNow(hours, weekday, minutes);
      nearby.push({
        branch_id: branch.id,
        name: `${branch.pharmacy_name} ${branch.branch_name}`.trim(),
        address: branch.address as string,
        distance_km: Math.round(dist * 10) / 10,
        hours_today: open.label,
        open_now: open.open,
      });
    }
    nearby.sort((a, b) => a.distance_km - b.distance_km);
    nearby = nearby.slice(0, 8);
  }

  type ReservationRow = {
    reference_no: string;
    status: string;
    total: string;
    pickup_code: string | null;
    expires_at: string;
    submitted_at: string;
    pharmacy: string;
    address: string;
    items: { brand_name: string; generic_name: string; strength: string; quantity: number }[];
  };

  const { data: rows } = await server
    .from("reservations")
    .select("id, reference_no, status, total_amount, expires_at, submitted_at, branch_id")
    .eq("customer_id", userId)
    .order("submitted_at", { ascending: false })
    .limit(10);

  const ids = (rows ?? []).map((row) => row.id);
  const { data: items } = ids.length === 0
    ? { data: [] }
    : await server
      .from("reservation_items")
      .select("reservation_id, brand_name, generic_name, strength, quantity")
      .in("reservation_id", ids);

  const { data: codes } = ids.length === 0
    ? { data: [] }
    : await server.from("pickup_codes").select("reservation_id, code_suffix").in(
      "reservation_id",
      ids,
    );

  type ItemRow = {
    reservation_id: string;
    brand_name: string;
    generic_name: string;
    strength: string;
    quantity: number;
  };
  const itemsByRes = new Map<string, ItemRow[]>();
  for (const item of (items ?? []) as ItemRow[]) {
    const list = itemsByRes.get(item.reservation_id) ?? [];
    list.push(item);
    itemsByRes.set(item.reservation_id, list);
  }
  const codeByRes = new Map((codes ?? []).map((c) => [c.reservation_id, c.code_suffix]));

  const reservations: ReservationRow[] = (rows ?? []).map((row) => {
    const branch = branchMap.get(row.branch_id);
    return {
      reference_no: row.reference_no,
      status: row.status,
      total: money(row.total_amount),
      pickup_code: codeByRes.get(row.id) ?? null,
      expires_at: row.expires_at,
      submitted_at: row.submitted_at,
      pharmacy: branch?.name ?? "Pharmacy",
      address: branch?.address ?? "",
      items: (itemsByRes.get(row.id) ?? []).map((line) => ({
        brand_name: line.brand_name,
        generic_name: line.generic_name,
        strength: line.strength,
        quantity: line.quantity,
      })),
    };
  });

  const activeCount = reservations.filter((r) =>
    activeReservationStatuses().includes(r.status)
  ).length;

  const check: AiFacts = {
    prices: [
      ...offerFacts.map((offer) => offer.price),
      ...reservations.map((row) => row.total),
    ],
    referenceNumbers: reservations.map((row) => row.reference_no),
    pickupCodes: reservations.map((row) => row.pickup_code).filter((code): code is string =>
      code != null
    ),
  };

  const locationContext = {
    status: location.status ?? "unknown",
    label: location.label ?? null,
    coordinates_available: locationOk,
    help_enable_location: location.status !== "granted"
      ? "Profile and Search use device location when allowed. On Android: Settings → Apps → MediTech → Permissions → Location → Allow. Turn on Location in quick settings."
      : null,
  };

  return {
    check,
    forModel: {
      app_guide: appGuide,
      medipal_rules: [
        "Use conversation history for follow-ups (e.g. price at the pharmacy you just mentioned).",
        "Ask which reservation if several are active and the user was vague.",
        "Never recommend medical substitutes or prescribe; only list other pharmacies with the same medicine on MediTech.",
        "For errors or missing data, say so plainly — do not invent.",
        "Keep answers short and friendly.",
      ],
      location: locationContext,
      nearby_pharmacies: nearby,
      medicines: medicines.map((medicine) => ({
        brand_name: medicine.brand_name,
        generic_name: medicine.generic_name,
        strength: medicine.strength,
      })),
      offers: offerFacts,
      reservations,
      active_reservation_count: activeCount,
      branches_index: (allBranches ?? []).map((b) => ({
        id: b.id,
        name: `${b.pharmacy_name} ${b.branch_name}`.trim(),
        address: b.address,
      })),
    },
  };
}