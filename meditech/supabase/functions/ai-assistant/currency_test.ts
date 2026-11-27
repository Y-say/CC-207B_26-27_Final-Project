import { assertEquals } from "jsr:@std/assert@1";
import { normalizePesoReply, polishAssistantReply } from "./currency.ts";

Deno.test("rewrites dollar amounts to peso", () => {
  assertEquals(normalizePesoReply("It costs $12.50 at the branch."), "It costs ₱12.50 at the branch.");
});

Deno.test("strips markdown asterisks", () => {
  assertEquals(
    polishAssistantReply("**Biogesic** is *available*.\n* Item one"),
    "Biogesic is available.\n- Item one",
  );
});