// Sign-in for all three apps: accepts an email, mobile number, or username
import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Which accounts may use each app
const allowed: Record<string, string[]> = {
  customer: ["customer"],
  pharmacy: ["staff"],
  admin: ["admin"],
};

// App names shown in the audit records
const appNames: Record<string, string> = {
  customer: "Customer app",
  pharmacy: "Pharmacy app",
  admin: "Admin portal",
};

// Lets the app call this function
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Send a reply to the app
function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Same message for wrong password and unknown account, so nobody can guess accounts
const wrongDetails = "Wrong email, mobile number, username, or password.";
const lockedMessage = "Too many wrong passwords. Try again in 15 minutes.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  // Read what the user typed
  const { identifier, password, app } = await req.json().catch(() => ({}));
  if (!identifier || !password || !allowed[app]) {
    return reply(400, { error: "Enter your sign-in details." });
  }

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const typed = String(identifier).trim();
  const appName = appNames[app];

  // Find the account behind what they typed
  const { data: found } = await server.rpc("find_account_for_sign_in", { p_identifier: typed });
  const account = found?.[0];

  // Unknown account: record it, but show the usual message
  if (!account) {
    await server.rpc("record_failed_sign_in", {
      p_account_id: null, p_label: "Unknown", p_identifier: typed, p_app: appName,
    });
    return reply(401, { error: wrongDetails });
  }

  // Still locked from earlier wrong passwords
  const { data: attempt } = await server
    .from("auth_attempts")
    .select("locked_until")
    .eq("account_id", account.account_id)
    .maybeSingle();
  if (attempt?.locked_until && new Date(attempt.locked_until) > new Date()) {
    return reply(429, { error: lockedMessage, locked_until: attempt.locked_until });
  }

  // Check the password
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data, error } = await client.auth.signInWithPassword({
    email: account.email,
    password,
  });

  if (error) {
    // Wrong password: count it, and lock on the 5th try
    if (error.code === "invalid_credentials" || error.message === "Invalid login credentials") {
      const { data: lockedUntil } = await server.rpc("record_failed_sign_in", {
        p_account_id: account.account_id,
        p_label: account.display_name,
        p_identifier: typed,
        p_app: appName,
      });
      if (lockedUntil) return reply(429, { error: lockedMessage, locked_until: lockedUntil });
      return reply(401, { error: wrongDetails });
    }
    // Refused for another reason, such as a deactivated account
    return reply(403, { error: error.message });
  }

  // Right password, but this account belongs to a different app
  if (!allowed[app].includes(account.account_type)) {
    await server.auth.admin.signOut(data.session!.access_token);
    return reply(403, { error: "This account can't sign in to this app." });
  }

  // Success: clear failed tries, record it, and hand the session to the app
  await server.rpc("record_successful_sign_in", {
    p_account_id: account.account_id,
    p_label: account.display_name,
    p_app: appName,
  });

  return reply(200, {
    access_token: data.session!.access_token,
    refresh_token: data.session!.refresh_token,
    expires_in: data.session!.expires_in,
    account_type: account.account_type,
  });
});