# MediPal expected behaviors

Implementation map for the customer AI assistant (`ai-assistant` edge function + Medipal UI).

| Area | Behavior |
|------|----------|
| Location | Client sends `location.status` (`granted`, `denied`, …). MediPal must not claim location is off when status is `granted`. |
| Nearby / open now | `handlers.ts` lists `nearby_pharmacies` with distance, hours, open/closed from `public_branch_hours`. |
| Directions | Guide user to Map tab; include branch address from facts. |
| Reservations | Full reservation rows (items, pharmacy, expiry, pickup code) in facts; disambiguation when multiple active. |
| Cancel | Pending-only cancellation guidance; alternatives when not allowed. |
| Medicine search | Word match on brand/generic; offers include price, availability, `stock_confirmed_at`. |
| Lowest price | Deterministic sort on live offers. |
| Substitutes | Never recommend therapeutic alternatives — other branches with same medicine only. |
| Context | `history` + Gemini `contents` for follow-ups. |
| Errors | 503 when Gemini unavailable; no fabricated inventory or reservations. |

Deploy after changes:

```bash
supabase functions deploy ai-assistant --project-ref <ref> --yes
```