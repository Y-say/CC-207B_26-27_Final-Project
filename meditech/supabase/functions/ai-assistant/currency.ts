/** Clean MediPal replies: peso currency, no markdown asterisks, tidy spacing. */
export function normalizePesoReply(text: string): string {
  return text
    .replace(/\$(\d+(?:\.\d{1,2})?)/g, "₱$1")
    .replace(/\bUSD\b/gi, "PHP")
    .replace(/\bdollars?\b/gi, "pesos");
}

export function polishAssistantReply(text: string): string {
  let out = normalizePesoReply(text);
  out = out.replace(/\*\*([^*\n]+)\*\*/g, "$1");
  out = out.replace(/__([^_\n]+)__/g, "$1");
  out = out.replace(/(?<!\w)\*([^*\n]+)\*(?!\w)/g, "$1");
  out = out.replace(/^\s*[*•]\s+/gm, "- ");
  out = out.replace(/\n{3,}/g, "\n\n");
  return out.trim();
}