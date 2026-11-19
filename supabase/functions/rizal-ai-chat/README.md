# `rizal-ai-chat` — TuklasRizal RAG tourism assistant

Deno/TypeScript Supabase Edge Function. It retrieves verified records from
`public.events`, `public.pois_logistics` and `public.municipalities` via
PostgREST, builds a grounded context, then asks Groq (falling back to Gemini).
If neither language model is reachable it still returns a database-only answer.

## Required Supabase secrets

Set them in the Supabase dashboard (Edge Functions → Secrets) or with the CLI:

```bash
supabase secrets set GROQ_API_KEY=... GEMINI_API_KEY=... \
  SUPABASE_URL=https://<project-ref>.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=...
```

- `GROQ_API_KEY` — primary LLM (tries `llama-3.3-70b-versatile`, then `openai/gpt-oss-120b`).
- `GEMINI_API_KEY` — fallback LLM (`gemini-2.5-flash`).
- `SUPABASE_URL` — used for the live PostgREST RAG queries.
- `SUPABASE_SERVICE_ROLE_KEY` — preferred for retrieval; falls back to
  `SUPABASE_ANON_KEY` if the service-role secret is not set.

No keys or tourism facts are hardcoded in `index.ts`.

Deploy:

```bash
supabase functions deploy rizal-ai-chat
```

## Guest / unauthenticated access

Guests (users without a Supabase Auth session) can call the function because
`supabase/config.toml` sets `verify_jwt = false` for it. The Flutter app calls
`Supabase.instance.client.functions.invoke('rizal-ai-chat', body: ...)` from
both Web and Android. Retrieval only reads public tourism records; if the
service-role secret is omitted and the anon key is used, RLS still applies.

## Invocation

```bash
curl -i "https://<project-ref>.supabase.co/functions/v1/rizal-ai-chat" \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Ano ang mga festival sa Tanay?",
    "history": [{ "role": "user", "text": "Kumusta!" }],
    "municipality": "Tanay"
  }'
```

Successful response:

```json
{
  "reply": "...",
  "sources": ["public.events — Tanay", "public.municipalities — Tanay"],
  "municipality": "Tanay",
  "provider": "groq",
  "model": "llama-3.3-70b-versatile"
}
```

`provider` is `groq`, `gemini`, or `database` (deterministic DB-only fallback).
Errors return `{ "error": "..." }` with an appropriate HTTP status. All
responses include permissive CORS headers, so a preflight `OPTIONS` returns `200`.
