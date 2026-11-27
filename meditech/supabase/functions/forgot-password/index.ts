// Send a reset code by email, then save a new password after verifyOtp.
import { createClient } from "npm:@supabase/supabase-js@2";
import { sendResetCodeEmail } from "./mail.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

function recoveryOtp(linkData: unknown): string | null {
  if (!linkData || typeof linkData !== "object") return null;
  const record = linkData as Record<string, unknown>;
  const props = record.properties;
  const fromProps = props && typeof props === "object"
    ? (props as Record<string, unknown>)
    : null;

  for (const raw of [
    record.email_otp,
    record.emailOtp,
    fromProps?.email_otp,
    fromProps?.emailOtp,
  ]) {
    if (typeof raw === "string" && /^\d{6}$/.test(raw)) return raw;
  }
  return null;
}

function isLocalSupabase(): boolean {
  return url.includes("127.0.0.1") || url.includes("localhost") || url.includes("kong:8000");
}

type FoundAccount = {
  account_type?: string;
  email?: string;
};

// PostgREST returns an array; some clients flatten a single row into an object.
function firstRpcRow<T>(data: unknown): T | undefined {
  if (Array.isArray(data)) return data[0] as T | undefined;
  if (data && typeof data === "object" && "email" in (data as object)) {
    return data as T;
  }
  return undefined;
}

// MediTech sends the code to the customer email in Auth, never the SMTP sender mailbox.
function customerInbox(
  identifier: string,
  account: FoundAccount | undefined,
): string | null {
  if (!account || account.account_type !== "customer") return null;
  const onFile = String(account.email ?? "").trim().toLowerCase();
  if (!onFile || !onFile.includes("@")) return null;

  const id = identifier.trim();
  if (id.includes("@")) {
    const typed = id.trim().toLowerCase();
    if (typed !== onFile) return null;
  }
  return onFile;
}

function maskEmail(address: string): string {
  const at = address.indexOf("@");
  if (at < 2) return address;
  const name = address.slice(0, at);
  const domain = address.slice(at);
  const head = name.slice(0, 2);
  return `${head}***${domain}`;
}

// Seed/demo addresses are not real mailboxes; Gmail bounces with NXDOMAIN.
function undeliverableRecipientError(email: string): string | null {
  if (isLocalSupabase()) return null;
  const lower = email.trim().toLowerCase();
  if (lower.endsWith("@demo.meditech.dev")) {
    return "That address is a demo account and cannot receive email. Sign up with your real Gmail, or update the user email in Supabase Auth.";
  }
  return null;
}

const STAFF_INTERNAL_EMAIL_SUFFIX = "@staff.meditech.internal";

function isStaffContactEmail(email: string): boolean {
  const lower = email.trim().toLowerCase();
  if (!lower.includes("@")) return false;
  if (lower.endsWith(STAFF_INTERNAL_EMAIL_SUFFIX)) return false;
  if (undeliverableRecipientError(email)) return false;
  return true;
}

// Pharmacy staff reset when a real Gmail (or contact email) is on file in Auth.
function staffInbox(
  identifier: string,
  account: FoundAccount | undefined,
): string | null {
  if (!account || account.account_type !== "staff") return null;
  const onFile = String(account.email ?? "").trim().toLowerCase();
  if (!isStaffContactEmail(onFile)) return null;

  const id = identifier.trim();
  if (id.includes("@")) {
    if (id.trim().toLowerCase() !== onFile) return null;
    return onFile;
  }
  // Matched by username via find_account_for_sign_in
  return onFile;
}

function recoveryInbox(
  identifier: string,
  account: FoundAccount | undefined,
): string | null {
  return customerInbox(identifier, account) ?? staffInbox(identifier, account);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "");
  const identifier = String(body.identifier ?? "").trim();
  if (!identifier) return reply(400, { error: "Enter your email or mobile number." });

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: found, error: lookupError } = await server.rpc("find_account_for_sign_in", {
    p_identifier: identifier,
  });
  if (lookupError) return reply(500, { error: "Could not send the code. Try again." });
  const account = firstRpcRow<FoundAccount>(found);
  const recipient = recoveryInbox(identifier, account);

  // Always say a code was sent, so nobody can search for accounts.
  if (action === "send") {
    if (account?.account_type === "admin") {
      return reply(400, {
        error: "Admin accounts must reset through the admin portal.",
      });
    }

    if (account?.account_type === "customer" && identifier.includes("@") && !recipient) {
      return reply(400, {
        error: "Use the same email you used when you signed up as a customer in MediTech.",
      });
    }

    if (account?.account_type === "staff" && !recipient) {
      const hint = identifier.includes("@")
        ? "Use the Gmail saved on your pharmacy profile (Profile → Edit profile)."
        : "This account has no contact email yet. Add Gmail under Profile → Edit profile while signed in, or ask your owner to set it on Employees.";
      return reply(400, { error: hint });
    }

    let deliveryEmail: string | null = null;
    if (recipient) {
      const undeliverable = undeliverableRecipientError(recipient);
      if (undeliverable) return reply(400, { error: undeliverable });

      deliveryEmail = maskEmail(recipient);
      // Never call /recover — it sends Supabase's link-only email (often blank on mobile).
      const { data: linkData, error: linkError } = await server.auth.admin.generateLink({
        type: "recovery",
        email: recipient,
      });
      if (linkError) return reply(500, { error: "Could not send the code. Try again." });

      const otp = recoveryOtp(linkData);
      if (!otp) return reply(500, { error: "Could not send the code. Try again." });

      const mailError = await sendResetCodeEmail(recipient, otp);
      if (mailError) return reply(500, { error: mailError });
    }
    return reply(200, {
      sent: true,
      ...(deliveryEmail ? { deliveryEmail } : {}),
    });
  }

  if (action !== "reset") return reply(400, { error: "Use send or reset." });

  const code = String(body.code ?? "").trim();
  const password = String(body.password ?? "");
  if (!recipient || !/^\d{6}$/.test(code) || password.length === 0) {
    return reply(400, { error: "That code is wrong or expired." });
  }

  const auth = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error: codeError } = await auth.auth.verifyOtp({
    email: recipient,
    token: code,
    type: "recovery",
  });
  if (codeError) return reply(400, { error: "That code is wrong or expired." });

  const { error: saveError } = await auth.auth.updateUser({ password });
  if (saveError) return reply(400, { error: saveError.message });
  await auth.auth.signOut();
  return reply(200, { reset: true });
});