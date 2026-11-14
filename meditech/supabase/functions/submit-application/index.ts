// Receives a pharmacy application: form details plus the LTO and storefront files
import { createClient } from "npm:@supabase/supabase-js@2";

const server = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const bucket = "pharmacy-documents";
const allowedTypes = ["image/jpeg", "image/png", "application/pdf"];
const maxSize = 5 * 1024 * 1024;

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

// Field rules, the same as the app's
const rules: Record<string, [RegExp, string]> = {
  pharmacy_name: [/^.{2,100}$/, "Enter the pharmacy name."],
  branch_name: [/^.{2,100}$/, "Enter the branch name."],
  address: [/^.{5,200}$/, "Enter the address as written on the LTO."],
  contact_number: [/^0[0-9]{9,10}$/, "Use digits only, like 0333201234 or 09171234567."],
  pharmacy_email: [/^[^@\s]+@[^@\s]+\.[^@\s]+$/, "Enter a valid pharmacy email."],
  lto_number: [/^.{3,40}$/, "Enter the FDA LTO number."],
  lto_expiry: [/^\d{4}-\d{2}-\d{2}$/, "Pick the LTO expiry date."],
  first_name: [/^[A-Za-zÑñ .'-]{2,50}$/, "First name: 2 to 50 letters."],
  last_name: [/^[A-Za-zÑñ .'-]{2,50}$/, "Last name: 2 to 50 letters."],
  mobile: [/^09[0-9]{9}$/, "Mobile number: 11 digits starting with 09."],
  email: [/^[^@\s]+@[^@\s]+\.[^@\s]+$/, "Enter a valid email."],
  username: [/^[A-Za-z0-9_]{4,20}$/, "Username: 4 to 20 letters, numbers, or underscores."],
  password: [/^(?=.*[A-Za-z])(?=.*[0-9]).{8,}$/, "Password: at least 8 characters with a letter and a number."],
};

// Check every field; return the errors found
function checkFields(d: Record<string, unknown>) {
  const errors: Record<string, string> = {};
  for (const [field, [pattern, message]] of Object.entries(rules)) {
    if (!pattern.test(String(d[field] ?? ""))) errors[field] = message;
  }
  if (d.middle_name && !/^[A-Za-zÑñ .'-]{2,50}$/.test(String(d.middle_name))) {
    errors.middle_name = "Middle name: 2 to 50 letters.";
  }
  const lat = Number(d.latitude), lng = Number(d.longitude);
  if (!(lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180)) {
    errors.location = "Set the store location.";
  }
  if (!Array.isArray(d.hours) || d.hours.length !== 7) {
    errors.hours = "Set the opening hours for every day.";
  }
  return errors;
}

// Check a file's type and size
function checkFile(file: unknown, label: string) {
  if (!(file instanceof File)) return `Upload the ${label}.`;
  if (!allowedTypes.includes(file.type)) return `${label}: use JPG, PNG, or PDF.`;
  if (file.size > maxSize) return `${label}: max 5 MB.`;
  return null;
}

// File extension from its type
const extension = (type: string) => (type === "application/pdf" ? "pdf" : type === "image/png" ? "png" : "jpg");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  // Read the form and the two files
  const form = await req.formData().catch(() => null);
  if (!form) return reply(400, { error: "Send the application as a form." });
  const data = JSON.parse(String(form.get("data") ?? "{}"));
  const ltoFile = form.get("lto_file");
  const storefrontFile = form.get("storefront_file");

  // Check everything before saving anything
  const errors = checkFields(data);
  const ltoError = checkFile(ltoFile, "LTO document");
  const storefrontError = checkFile(storefrontFile, "Storefront photo");
  if (ltoError) errors.lto_file = ltoError;
  if (storefrontError) errors.storefront_file = storefrontError;
  if (Object.keys(errors).length > 0) return reply(400, { error: "Fix the highlighted fields.", fields: errors });

  const lto = ltoFile as File;
  const storefront = storefrontFile as File;
  const branchId = crypto.randomUUID();
  const ltoPath = `${branchId}/lto/${crypto.randomUUID()}.${extension(lto.type)}`;
  const storefrontPath = `${branchId}/storefront/${crypto.randomUUID()}.${extension(storefront.type)}`;
  let userId: string | null = null;

  // Undo whatever was already done if a later step fails
  async function undo() {
    await server.storage.from(bucket).remove([ltoPath, storefrontPath]);
    if (userId) await server.auth.admin.deleteUser(userId);
  }

  try {
    // 1. Create the owner's sign-in
    const { data: created, error: userError } = await server.auth.admin.createUser({
      email: data.email,
      password: data.password,
      email_confirm: true,
    });
    if (userError) {
      return reply(409, { error: "This email is already registered.", fields: { email: "Already registered." } });
    }
    userId = created.user.id;

    // 2. Upload the two files
    const up1 = await server.storage.from(bucket).upload(ltoPath, lto, { contentType: lto.type });
    const up2 = await server.storage.from(bucket).upload(storefrontPath, storefront, { contentType: storefront.type });
    if (up1.error || up2.error) {
      await undo();
      return reply(500, { error: "Upload failed. Please try again." });
    }

    // 3. Save everything in one step
    const { data: displayId, error: saveError } = await server.rpc("create_pharmacy_application", {
      p: {
        ...data,
        password: undefined,
        account_id: userId,
        branch_id: branchId,
        lto_path: ltoPath, lto_mime: lto.type, lto_size: lto.size,
        storefront_path: storefrontPath, storefront_mime: storefront.type, storefront_size: storefront.size,
      },
    });

    if (saveError) {
      await undo();
      const msg = saveError.message;
      if (msg.includes("LTO_EXPIRED")) return reply(400, { error: "This LTO has expired.", fields: { lto_expiry: "Expired." } });
      if (msg.includes("lto_number")) return reply(409, { error: "This LTO number is already registered.", fields: { lto_number: "Already registered." } });
      if (msg.includes("username")) return reply(409, { error: "This username is taken.", fields: { username: "Already taken." } });
      return reply(500, { error: "Could not save the application. Please try again." });
    }

    return reply(201, { application_id: displayId, message: "Application submitted." });
  } catch (_e) {
    await undo();
    return reply(500, { error: "Something went wrong. Please try again." });
  }
});