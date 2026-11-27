// Employee accounts: an owner adds staff, turns them on or off, resets their
// password, and updates license details. An admin verifies licenses.
import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

// Field rules, the same as the database's
const nameRule = /^[A-Za-zÑñ .'-]{2,50}$/;
const emailRule = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const usernameRule = /^[A-Za-z0-9_]{4,20}$/;
const prcRule = /^[0-9]{7}$/;
const dateRule = /^\d{4}-\d{2}-\d{2}$/;

// Today in the Philippines, like 2026-11-17
function today() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Manila" });
}

// A one-time password with letters and numbers, leaving out look-alikes
function temporaryPassword() {
  const letters = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  const numbers = "23456789";
  const pick = (set: string) => set[crypto.getRandomValues(new Uint32Array(1))[0] % set.length];
  const chars = [pick(letters), pick(numbers)];
  while (chars.length < 12) chars.push(pick(letters + numbers));
  // Shuffle so the letter and number are not always first
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.getRandomValues(new Uint32Array(1))[0] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  // Who is asking?
  const header = req.headers.get("Authorization");
  if (!header) return reply(401, { error: "Sign in first." });

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: header } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Sign in first." });
  const callerId = userData.user.id;

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  // deno-lint-ignore no-explicit-any
  const db: any = server;

  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "");

  const { data: account } = await db
    .from("accounts")
    .select("account_type, state")
    .eq("id", callerId)
    .maybeSingle();
  if (!account || account.state !== "active") {
    return reply(403, { error: "This account can't do that." });
  }

  // ---------------------------------------------------------------
  // Admin: verify a pharmacist's license
  // ---------------------------------------------------------------
  if (action === "verify_license") {
    if (account.account_type !== "admin") {
      return reply(403, { error: "Only an administrator can verify licenses." });
    }
    const { data: target } = await db
      .from("staff_members")
      .select("account_id, branch_id, display_id, license_status, prc_license_no, prc_license_expiry")
      .eq("account_id", String(body.employee_id ?? ""))
      .maybeSingle();
    if (!target) return reply(404, { error: "Employee not found." });
    if (!target.prc_license_no || !target.prc_license_expiry) {
      return reply(400, { error: "This employee has no license details yet." });
    }
    if (target.prc_license_expiry < today()) {
      return reply(400, { error: "This license has already expired." });
    }

    const { error } = await db
      .from("staff_members")
      .update({
        license_status: "verified",
        license_verified_by: callerId,
        license_verified_at: new Date().toISOString(),
      })
      .eq("account_id", target.account_id);
    if (error) return reply(500, { error: "Could not verify the license." });

    const { data: admin } = await db
      .from("admins")
      .select("display_name")
      .eq("account_id", callerId)
      .maybeSingle();
    await db.rpc("log_audit", {
      p_actor_id: callerId,
      p_actor_label: admin?.display_name ?? "Admin",
      p_actor_role: "admin",
      p_event: "admin_action",
      p_action: "Verified a pharmacist license",
      p_record_ref: target.display_id,
      p_details: { expires: target.prc_license_expiry },
    });
    await db.from("notifications").insert({
      recipient_id: target.account_id,
      type: "license_verified",
      title: "Your PRC license was verified",
      body: "You can now confirm and release reservations.",
    });
    return reply(200, { ok: true });
  }

  // ---- Contact email for the signed-in owner or employee ------------
  if (action === "update_my_email") {
    if (account.account_type !== "staff") {
      return reply(403, { error: "Only pharmacy staff can update email." });
    }
    const rawEmail = String(body.email ?? "").trim();
    const errors: Record<string, string> = {};
    if (!emailRule.test(rawEmail)) errors.email = "Enter a valid email.";
    if (Object.keys(errors).length) {
      return reply(400, { error: "Check the highlighted fields.", fields: errors });
    }

    const { data: staff } = await db
      .from("staff_members")
      .select("display_id, branch_id, role, first_name, last_name, is_active")
      .eq("account_id", callerId)
      .maybeSingle();
    if (!staff?.is_active) {
      return reply(403, { error: "Your account is not active." });
    }

    const { error: emailError } = await db.auth.admin.updateUserById(callerId, {
      email: rawEmail,
      email_confirm: true,
    });
    if (emailError) {
      return reply(409, {
        error: "This email is already registered.",
        fields: { email: "Already registered." },
      });
    }

    const label = `${staff.first_name} ${staff.last_name} (${staff.role})`;
    await db.rpc("log_activity", {
      p_branch_id: staff.branch_id,
      p_actor_id: callerId,
      p_actor_label: label,
      p_actor_role: staff.role,
      p_action: "Updated contact email",
      p_entity_type: "employee",
      p_entity_id: staff.display_id,
      p_details: {},
    }).catch(() => {});

    return reply(200, { ok: true });
  }

  // ---------------------------------------------------------------
  // Everything else is for a branch owner
  // ---------------------------------------------------------------
  const { data: owner } = await db
    .from("staff_members")
    .select("branch_id, role, first_name, last_name, is_active")
    .eq("account_id", callerId)
    .maybeSingle();
  if (account.account_type !== "staff" || !owner || owner.role !== "owner" || !owner.is_active) {
    return reply(403, { error: "Only the pharmacy owner can manage employees." });
  }

  const { data: branch } = await db
    .from("branches")
    .select("status")
    .eq("id", owner.branch_id)
    .maybeSingle();
  if (branch?.status !== "active") {
    return reply(403, { error: "Your pharmacy must be active to manage employees." });
  }

  const ownerLabel = `${owner.first_name} ${owner.last_name} (Owner)`;
  const logActivity = (what: string, employeeDisplayId: string, details = {}) =>
    db.rpc("log_activity", {
      p_branch_id: owner.branch_id,
      p_actor_id: callerId,
      p_actor_label: ownerLabel,
      p_actor_role: "owner",
      p_action: what,
      p_entity_type: "employee",
      p_entity_id: employeeDisplayId,
      p_details: details,
    });

  // Find an employee of this branch (never the owner's own account)
  async function findEmployee(id: unknown) {
    const { data } = await db
      .from("staff_members")
      .select("account_id, display_id, role, first_name, last_name, is_active")
      .eq("account_id", String(id ?? ""))
      .eq("branch_id", owner.branch_id)
      .maybeSingle();
    return data;
  }

  // ---- Add an employee ----------------------------------------
  if (action === "create") {
    const d = body as Record<string, string | undefined>;
    const errors: Record<string, string> = {};
    if (!nameRule.test(d.first_name ?? "")) errors.first_name = "First name: 2 to 50 letters.";
    if (!nameRule.test(d.last_name ?? "")) errors.last_name = "Last name: 2 to 50 letters.";
    if (d.middle_name && !nameRule.test(d.middle_name)) {
      errors.middle_name = "Middle name: 2 to 50 letters.";
    }
    const rawEmail = (d.email ?? "").trim();
    if (rawEmail && !emailRule.test(rawEmail)) errors.email = "Enter a valid email.";
    if (!usernameRule.test(d.username ?? "")) {
      errors.username = "Username: 4 to 20 letters, numbers, or underscores.";
    }
    if (d.role !== "pharmacist" && d.role !== "staff") {
      errors.role = "Choose Pharmacist or Staff.";
    }
    if (d.role === "pharmacist") {
      if (!prcRule.test(d.prc_license_no ?? "")) {
        errors.prc_license_no = "PRC license number: exactly 7 digits.";
      }
      if (!dateRule.test(d.prc_license_expiry ?? "")) {
        errors.prc_license_expiry = "Pick the license expiry date.";
      } else if ((d.prc_license_expiry as string) < today()) {
        errors.prc_license_expiry = "This license has already expired.";
      }
    }
    if (Object.keys(errors).length) {
      return reply(400, { error: "Check the highlighted fields.", fields: errors });
    }

    // Staff accounts sign in by username; use an internal address if no email is given
    const authEmail = rawEmail || `${d.username!.toLowerCase()}@staff.meditech.internal`;
    const password = temporaryPassword();
    const { data: created, error: userError } = await db.auth.admin.createUser({
      email: authEmail,
      password,
      email_confirm: true,
    });
    if (userError) {
      return reply(409, {
        error: rawEmail ? "This email is already registered." : "This username is taken.",
        fields: rawEmail ? { email: "Already registered." } : { username: "Already taken." },
      });
    }
    const newId: string = created.user.id;

    // Undo the sign-in if anything below fails
    const undo = () => db.auth.admin.deleteUser(newId);

    const { error: accountError } = await db.from("accounts").insert({
      id: newId,
      account_type: "staff",
      username: d.username,
      must_change_password: true,
    });
    if (accountError) {
      await undo();
      if (String(accountError.message).includes("username")) {
        return reply(409, { error: "This username is taken.", fields: { username: "Already taken." } });
      }
      return reply(500, { error: "Could not create the account." });
    }

    const { data: employee, error: staffError } = await db
      .from("staff_members")
      .insert({
        account_id: newId,
        branch_id: owner.branch_id,
        role: d.role,
        first_name: d.first_name,
        middle_name: d.middle_name || null,
        last_name: d.last_name,
        prc_license_no: d.role === "pharmacist" ? d.prc_license_no : null,
        prc_license_expiry: d.role === "pharmacist" ? d.prc_license_expiry : null,
        license_status: d.role === "pharmacist" ? "pending" : "none",
      })
      .select("display_id")
      .maybeSingle();
    if (staffError) {
      await undo(); // the account row goes with the sign-in
      return reply(500, { error: "Could not save the employee." });
    }

    await logActivity("Added an employee", employee?.display_id ?? "", { role: d.role });
    return reply(200, {
      account_id: newId,
      display_id: employee?.display_id,
      temporary_password: password,
    });
  }

  // ---- Everything below works on one existing employee --------
  const employee = await findEmployee(body.employee_id);
  if (!employee) return reply(404, { error: "Employee not found." });
  if (employee.account_id === callerId) {
    return reply(400, { error: "You can't change your own account here." });
  }
  if (employee.role === "owner") {
    return reply(400, { error: "The owner's account can't be changed here." });
  }

  // ---- Turn an employee on or off -----------------------------
  if (action === "set_active") {
    if (typeof body.is_active !== "boolean") return reply(400, { error: "Say on or off." });
    const active: boolean = body.is_active;

    const { error: staffError } = await db
      .from("staff_members")
      .update({ is_active: active })
      .eq("account_id", employee.account_id);
    if (staffError) return reply(500, { error: "Could not update the employee." });

    await db
      .from("accounts")
      .update({ state: active ? "active" : "deactivated" })
      .eq("id", employee.account_id);

    // Sign a deactivated employee out everywhere
    if (!active) await db.auth.admin.signOut(employee.account_id).catch(() => {});

    await logActivity(active ? "Reactivated an employee" : "Deactivated an employee", employee.display_id);
    return reply(200, { ok: true });
  }

  // ---- New temporary password ---------------------------------
  if (action === "reset_password") {
    const password = temporaryPassword();
    const { error } = await db.auth.admin.updateUserById(employee.account_id, { password });
    if (error) return reply(500, { error: "Could not reset the password." });

    await db.from("accounts").update({ must_change_password: true }).eq("id", employee.account_id);
    await logActivity("Reset an employee's password", employee.display_id);
    return reply(200, { temporary_password: password });
  }

  // ---- Update license details (an admin must verify them again) --
  if (action === "update_license") {
    const no = String(body.prc_license_no ?? "");
    const expiry = String(body.prc_license_expiry ?? "");
    const errors: Record<string, string> = {};
    if (!prcRule.test(no)) errors.prc_license_no = "PRC license number: exactly 7 digits.";
    if (!dateRule.test(expiry)) errors.prc_license_expiry = "Pick the license expiry date.";
    else if (expiry < today()) errors.prc_license_expiry = "This license has already expired.";
    if (Object.keys(errors).length) {
      return reply(400, { error: "Check the highlighted fields.", fields: errors });
    }

    const { error } = await db
      .from("staff_members")
      .update({
        prc_license_no: no,
        prc_license_expiry: expiry,
        license_status: "pending",
        license_verified_by: null,
        license_verified_at: null,
      })
      .eq("account_id", employee.account_id);
    if (error) return reply(500, { error: "Could not save the license." });

    await logActivity("Updated an employee's license", employee.display_id, { expires: expiry });
    return reply(200, { ok: true });
  }

  // ---- Name on file (not username or role) -----------------------
  if (action === "update_profile") {
    const d = body as Record<string, string | undefined>;
    const errors: Record<string, string> = {};
    if (!nameRule.test(d.first_name ?? "")) errors.first_name = "First name: 2 to 50 letters.";
    if (!nameRule.test(d.last_name ?? "")) errors.last_name = "Last name: 2 to 50 letters.";
    const middle = (d.middle_name ?? "").trim();
    if (middle && !nameRule.test(middle)) {
      errors.middle_name = "Middle name: 2 to 50 letters.";
    }
    if (Object.keys(errors).length) {
      return reply(400, { error: "Check the highlighted fields.", fields: errors });
    }

    const { error } = await db
      .from("staff_members")
      .update({
        first_name: d.first_name!.trim(),
        middle_name: middle || null,
        last_name: d.last_name!.trim(),
      })
      .eq("account_id", employee.account_id);
    if (error) return reply(500, { error: "Could not save the profile." });

    await logActivity("Updated an employee profile", employee.display_id);
    return reply(200, { ok: true });
  }

  // ---- Contact email for password reset (owner sets for employees) -----
  if (action === "update_employee_email") {
    const rawEmail = String(body.email ?? "").trim();
    const errors: Record<string, string> = {};
    if (!emailRule.test(rawEmail)) errors.email = "Enter a valid email.";
    if (Object.keys(errors).length) {
      return reply(400, { error: "Check the highlighted fields.", fields: errors });
    }

    const { error: emailError } = await db.auth.admin.updateUserById(employee.account_id, {
      email: rawEmail,
      email_confirm: true,
    });
    if (emailError) {
      return reply(409, {
        error: "This email is already registered.",
        fields: { email: "Already registered." },
      });
    }

    await logActivity("Set employee contact email", employee.display_id);
    return reply(200, { ok: true });
  }

  return reply(400, { error: "Unknown action." });
});
