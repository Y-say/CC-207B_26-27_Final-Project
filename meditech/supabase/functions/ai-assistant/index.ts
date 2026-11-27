// Answer from MediTech facts only, using the free Gemini API
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  appGuide,
  appHelpAnswer,
  hasInventedFact,
  isAppHelp,
  isMedicineLookup,
  medicineNotListedAnswer,
  refuseReason,
  type MedicineFact,
  type OfferFact,
} from "./guard.ts";
import { loadFacts, type ClientLocation } from "./facts.ts";
import { needsLiveMeditechData, tryDeterministicAnswer } from "./handlers.ts";
import { polishAssistantReply } from "./currency.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const geminiKey = Deno.env.get("GEMINI_API_KEY");

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type HistoryLine = { role: "user" | "model"; text: string };

function parseLocation(raw: unknown): ClientLocation {
  if (!raw || typeof raw !== "object") return {};
  const record = raw as Record<string, unknown>;
  return {
    status: typeof record.status === "string" ? record.status : undefined,
    latitude: typeof record.latitude === "number" ? record.latitude : undefined,
    longitude: typeof record.longitude === "number" ? record.longitude : undefined,
    label: typeof record.label === "string" ? record.label : undefined,
    weekday: typeof record.weekday === "number" ? record.weekday : undefined,
    minutes_since_midnight: typeof record.minutes_since_midnight === "number"
      ? record.minutes_since_midnight
      : undefined,
  };
}

function parseHistory(raw: unknown): HistoryLine[] {
  if (!Array.isArray(raw)) return [];
  const lines: HistoryLine[] = [];
  for (const entry of raw.slice(-8)) {
    if (!entry || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const text = String(record.text ?? "").trim();
    if (!text) continue;
    const role = record.role === "model" ? "model" : "user";
    lines.push({ role, text });
  }
  return lines;
}

const systemPrompt = [
  "You are Medipal, the MediTech customer assistant.",
  "Follow the behaviors in facts.medipal_rules and facts.app_guide.",
  "Use location, nearby_pharmacies, offers, and reservations from facts only.",
  "If location.status is granted, do not say location is turned off.",
  "If location is not granted, explain how to enable it using facts.location.help_enable_location.",
  "Understand follow-up questions using conversation history.",
  "Ask for clarification when the question is ambiguous.",
  "For multiple active reservations, ask which reference unless the user was specific.",
  "Never invent prices, stock, reservation status, reference numbers, or pickup codes.",
  "Do not diagnose, prescribe, or recommend medical substitutes — only pharmacies listing the same medicine.",
  "You may share brief general education about a medicine's common use or dosage form, and direct users to a pharmacist for medical advice.",
  "If data is missing or an error occurred, say so clearly.",
  "Write in a professional, courteous tone for pharmacy customers.",
  "Use plain text only: no markdown, no asterisks, no bold, no hashtags.",
  "Use short paragraphs or hyphen bullets (- item) when listing.",
  "Keep answers concise and non-technical.",
  "All money is Philippine peso (PHP). Always prefix prices with ₱ (e.g. ₱12.50). Never use $ or USD.",
].join(" ");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const header = req.headers.get("Authorization");
  if (!header) return reply(401, { error: "Sign in before using the assistant." });

  const body = await req.json().catch(() => ({}));
  const message = String(body.message ?? "").trim();
  if (!message) return reply(400, { error: "Enter a question." });
  if (message.length > 500) return reply(400, { error: "Ask a shorter question." });

  const refusal = refuseReason(message);
  if (refusal) return reply(200, { answer: polishAssistantReply(refusal) });

  if (!geminiKey?.trim()) {
    console.error("[ai-assistant] GEMINI_API_KEY is not set");
    return reply(503, {
      error:
        "The assistant is not configured. Set GEMINI_API_KEY in Supabase → Project Settings → Edge Functions → Secrets, then redeploy ai-assistant.",
      code: "missing_gemini_key",
    });
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: header } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Sign in before using the assistant." });

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const userId = userData.user.id;
  const { data: account } = await server.from("accounts").select("account_type").eq("id", userId).maybeSingle();
  if (account?.account_type !== "customer") {
    return reply(403, { error: "This assistant is for customers." });
  }

  const { data: allowed, error: limitError } = await server.rpc("consume_ai_message", {
    p_account_id: userId,
  });
  if (limitError) {
    console.error("[ai-assistant] consume_ai_message error:", limitError);
    return reply(503, { error: "The assistant is unavailable." });
  }
  if (allowed !== true) return reply(429, { error: "You have reached today's limit of 20 questions." });

  const location = parseLocation(body.location);
  const history = parseHistory(body.history);

  if (isAppHelp(message) && !needsLiveMeditechData(message)) {
    return reply(200, { answer: polishAssistantReply(appHelpAnswer(message)) });
  }

  const facts = await loadFacts(server, userId, message, location);

  const medicines = facts.forModel.medicines as MedicineFact[];
  const offers = facts.forModel.offers as OfferFact[];

  if (isMedicineLookup(message) && medicines.length === 0) {
    return reply(200, { answer: polishAssistantReply(medicineNotListedAnswer()) });
  }

  const deterministic = tryDeterministicAnswer(message, facts, location, medicines, offers);
  if (deterministic) {
    return reply(200, { answer: polishAssistantReply(deterministic) });
  }

  const models = (Deno.env.get("GEMINI_MODELS") ??
    "gemini-3.6-flash,gemini-3.5-flash,gemini-2.5-flash")
    .split(",")
    .map((name) => name.trim())
    .filter((name) => name.length > 0);

  const contents = [
    ...history.map((line) => ({
      role: line.role,
      parts: [{ text: line.text }],
    })),
    { role: "user", parts: [{ text: message }] },
  ];

  let answer = "";
  let geminiOk = false;
  let lastGeminiStatus = 0;
  let lastGeminiBody = "";

  for (const model of models) {
    const gemini = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey.trim() },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{
              text: `${systemPrompt} Facts: ${JSON.stringify(facts.forModel)}`,
            }],
          },
          contents,
          generationConfig: { temperature: 0.2, maxOutputTokens: 600 },
        }),
      },
    );
    if (!gemini.ok) {
      lastGeminiStatus = gemini.status;
      lastGeminiBody = await gemini.text().catch(() => "");
      console.error(`[ai-assistant] Gemini ${model} HTTP ${gemini.status}: ${lastGeminiBody}`);
      continue;
    }
    const payload = await gemini.json();
    const parts = payload?.candidates?.[0]?.content?.parts ?? [];
    answer = parts.map((part: { text?: string }) => part.text ?? "").join("").trim();
    if (answer) {
      geminiOk = true;
      break;
    }
  }

  if (!geminiOk) {
    return reply(503, {
      error: "The assistant could not reach the AI service. Try again in a moment.",
      code: "gemini_unavailable",
    });
  }

  if (hasInventedFact(answer, facts.check)) {
    return reply(200, {
      answer: polishAssistantReply(
        "I can only share information recorded in MediTech. Please ask again with a medicine name or reservation reference.",
      ),
    });
  }
  return reply(200, { answer: polishAssistantReply(answer) });
});