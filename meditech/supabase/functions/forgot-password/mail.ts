import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

function resetEmailHtml(code: string, recipient: string) {
  return `<h2>Reset your MediTech password</h2>
<p>This code is for the MediTech account <strong>${recipient}</strong>. Enter it in the app under Forgot password → Enter the code.</p>
<p style="font-size:28px;font-weight:700;letter-spacing:6px;">${code}</p>
<p>The code expires in 1 hour. If you did not request this, ignore this email.</p>`;
}

async function sendWithResend(to: string, code: string): Promise<string | null> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return "Missing RESEND_API_KEY.";

  const from = Deno.env.get("RESET_EMAIL_FROM") ?? "MediTech <onboarding@resend.dev>";
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Your MediTech password reset code",
      html: resetEmailHtml(code, to),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    return `Could not send the code. ${body}`;
  }
  return null;
}

function parseFromAddress(raw: string, smtpUser: string): string {
  const value = raw.trim();
  if (value.includes("<") && value.includes(">")) return value;
  if (value.includes("@")) return value;
  return smtpUser;
}

async function sendWithSmtp(to: string, code: string): Promise<string | null> {
  const user = Deno.env.get("RESET_SMTP_USER");
  const pass = Deno.env.get("RESET_SMTP_PASS");
  if (!user || !pass) return "Missing RESET_SMTP_USER or RESET_SMTP_PASS.";
  if (!to.includes("@")) return "Could not send the code. Invalid recipient.";

  const host = Deno.env.get("RESET_SMTP_HOST") ?? "smtp.gmail.com";
  const port = Number(Deno.env.get("RESET_SMTP_PORT") ?? "465");
  const from = parseFromAddress(Deno.env.get("RESET_EMAIL_FROM") ?? user, user);

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port,
      tls: true,
      auth: { username: user, password: pass },
    },
  });

  try {
    await client.send({
      from,
      to,
      subject: "Your MediTech password reset code",
      content: "Enter this code in MediTech to reset your password.",
      html: resetEmailHtml(code, to),
    });
    await client.close();
    return null;
  } catch (error) {
    await client.close();
    const message = error instanceof Error ? error.message : String(error);
    return `Could not send the code. ${message}`;
  }
}

export async function sendResetCodeEmail(to: string, code: string): Promise<string | null> {
  if (Deno.env.get("RESEND_API_KEY")) {
    return await sendWithResend(to, code);
  }
  if (Deno.env.get("RESET_SMTP_USER") && Deno.env.get("RESET_SMTP_PASS")) {
    return await sendWithSmtp(to, code);
  }
  return "Reset email is not set up. Configure RESEND_API_KEY or RESET_SMTP_USER on Supabase.";
}