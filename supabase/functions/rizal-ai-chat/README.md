# `rizal-ai-chat` — TuklasRizal AI Tour Guide (RAG Edge Function)

Deno/TypeScript Supabase Edge Function. It answers practical Rizal tourism
questions (and capstone-defense questions about the tourism directory) by
grounding the language model on **two** verified sources:

1. **Live Supabase records** — approved `events`, `pois_logistics` and
   `municipalities` (with tourism-office contacts) retrieved via PostgREST.
2. **Verified reference guide** — `rizal_knowledge.ts`, a hand-compiled,
   source-cited module covering:
   - **Commute corridors** from Metro Manila (jeepney / UV Express / bus /
     LRT-2 Marikina-Pasig & Antipolo stations) and key transfer hubs
     (Tanay Public Market, Binangonan/Cardona ports, Masinag Junction).
   - **Entrance & guide fee benchmarks + operating hours** for flagship spots
     (Hinulugang Taktak, Pinto Art Museum, Daranak/Batlag Falls, Calinawan
     Cave, Mt. Daraitan & Tinipak River, Regina RICA, Pililla Wind Farm).
   - **Rizal's 5 Tourism Pillars (FFAAN)** — the DOT Green Corridor Initiative
     Faith / Food / Art / Adventure / Nature circuit — plus cultural etiquette
     and trail/cave/waterfall safety.
   - **Town-by-town food & pasalubong** for all 14 municipalities.
   - **Proximity-based multi-town loops** (Art & Pilgrimage, Lakeshore
     Heritage, Highlands & Windmill).

Every fact in `rizal_knowledge.ts` carries a source-URL comment (Province of
Rizal, DOT, LRTA, municipal tourism offices, and reputable published guides).
Peso amounts and travel times are **benchmarks** — the assistant always tells
visitors to confirm current rates/hours/status before travelling.

## System prompt — five mandatory rules

1. **Strict grounding & zero guessing** — never invent dates, prices, or
   schedules absent from the retrieved records / reference guide; when a
   detail is unavailable, say so and give the exact Municipal Tourism Office
   email/phone for verification.
2. **Explainable "hidden gem" promotion** — pair a popular hub (Antipolo /
   Tanay) with at least one under-represented town (Jala-Jala, Cardona,
   Pililla, Morong, Teresa) and explain *why* it fits the visitor's interests.
3. **Automatic language mirroring** — reply in English, Tagalog, or Taglish,
   keeping official venue / festival / municipality names intact.
4. **Out-of-scope & travel-safety guardrails** — steer off-topic prompts back
   to Rizal tourism; remind hikers/waterfall visitors to check weather and LGU
   trail advisories, register, and hire mandatory guides.
5. **Privacy & AI transparency (RA 10173 / NPC Advisory No. 2024-04)** — never
   ask for sensitive personal info (home address, phone, government IDs) in
   chat; attribute recommendations to TuklasRizal's municipal tourism directory.

## LLM chain

- **Groq (primary):** `openai/gpt-oss-120b` → `openai/gpt-oss-20b`
  (`reasoning_effort: low` so the visible answer is not truncated).
- **Gemini (fallback):** `gemini-3.8-flash` with `thinkingConfig.thinkingBudget: 0`
  (older `gemini-2.5-flash` / `gemini-2.0-flash` are retired for this key).
- **Database-only fallback:** if no model is reachable, a deterministic answer
  is assembled from the verified DB rows (provider `database`).

Each LLM call has a 30 s timeout. The grounding context is **token-budgeted**
(bounded DB rows + clipped descriptions + a capped reference-guide block) to
stay inside the Groq on-demand tier's ~8000 tokens-per-minute request ceiling.

## Required Supabase secrets

Set them in the dashboard (Edge Functions → Secrets) or with the CLI:

```bash
supabase secrets set GROQ_API_KEY=... GEMINI_API_KEY=... \
  SUPABASE_URL=https://<project-ref>.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=...
```

- `GROQ_API_KEY` — primary LLM.
- `GEMINI_API_KEY` — fallback LLM.
- `SUPABASE_URL` — used for the live PostgREST RAG queries.
- `SUPABASE_SERVICE_ROLE_KEY` — preferred for retrieval; falls back to
  `SUPABASE_ANON_KEY` if the service-role secret is not set.

No API keys are hardcoded. Tourism facts live only in the live database and the
source-cited `rizal_knowledge.ts` reference module.

Deploy:

```bash
npx supabase functions deploy rizal-ai-chat --project-ref dhqzhlhyblcziouyoltp
```

## Guest / unauthenticated access

Guests (users without a Supabase Auth session) can call the function because
`supabase/config.toml` sets `verify_jwt = false` for it. The Flutter app calls
`Supabase.instance.client.functions.invoke('rizal-ai-chat', body: ...)` from
both Web and Android. Retrieval only reads public tourism records; if the
service-role secret is omitted and the anon key is used, RLS still applies.

## Invocation

```bash
curl -i "https://dhqzhlhyblcziouyoltp.supabase.co/functions/v1/rizal-ai-chat" \
  -H "Authorization: Bearer <SUPAB...KEY>" \
  -H "apikey: <SUPAB...EY>" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Paano pumunta sa Daranak Falls galing Cubao, at magkano ang entrance fee?",
    "history": [{ "role": "user", "text": "Kumusta!" }],
    "municipality": "Tanay"
  }'
```

Successful response:

```json
{
  "reply": "...",
  "sources": ["public.events — Tanay", "public.municipalities — Tanay",
              "TuklasRizal verified reference guide (rizalprovince.ph / DOT / LRTA / LGU tourism offices)"],
  "items": [{ "id": "...", "type": "poi", "title": "Daranak Falls", "municipality": "Tanay" }],
  "municipality": "Tanay",
  "provider": "groq",
  "model": "openai/gpt-oss-20b"
}
```

`provider` is `groq`, `gemini`, or `database` (deterministic DB-only fallback).
`items` are the verified records behind the answer (tappable cards in the mobile
app). Errors return `{ "error": "..." }` with an appropriate HTTP status. All
responses include permissive CORS headers, so a preflight `OPTIONS` returns `200`.
