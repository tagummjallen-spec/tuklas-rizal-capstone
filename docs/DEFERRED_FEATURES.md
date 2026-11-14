# DEFERRED_FEATURES.md
# TuklasRizal — Data-Dependent Blockers & Mock Strategies

> These items are **deferred / blocked** and must NOT block mobile-app or backend development. They are tracked here with mock/stub strategies so the UI and flows can be built end-to-end now, then swapped in later.

---

## 1. Full Rizal Dataset (LGU interviews + web scraping in progress)

**Blocker:** Curated tourism dataset for all 14 Rizal municipalities is still being gathered via LGU interviews (Angono, Taytay, Binangonan, Capitolyo) and web scraping.

**Mock Strategy:** Seed realistic sample data for three pilot municipalities so UI and chat flow work end-to-end:
- **Angono** — Higantes Festival (Cultural/Festival), heritage homes, Balaw-Balaw restaurant
- **Binangonan** — Petroglyphs (Cultural/Heritage), lakeshore (Laguna de Bay), lakeshore dining
- **Taytay** — Tiangge (Fashion/Food/Heritage), garlic industry, Santa Ana Church

These mocks live in `dataset/` (JSON/CSV) and are loaded via a clean service interface behind a feature flag.

---

## 2. Llama LLM + RAG Pipeline (accuracy / relevance / clarity testing)

**Blocker:** The conversational AI assistant (Llama LLM + pgvector semantic search) requires the full dataset and accuracy/relevance/clarity testing before it can be considered production-grade.

**Mock Strategy:** Stub the RAG/Llama service with a clean interface returning canned, realistic answers for the three pilot municipalities (who, what, when, how to get there, coordinator contact details). The chat UI is built against this interface so the real pipeline can be swapped in later without UI changes.

---

## 3. Physical Geofence Testing

**Blocker:** Geofence welcome alerts require physical presence in each municipality (Binangonan, Angono, Morong, etc.), which is not feasible during development.

**Mock Strategy:** Add a developer **debug toggle** in the app to simulate municipal entry alerts. When enabled, the app can trigger a geofence welcome alert for any selected municipality, showcasing local attractions, events, unique foods, and step-by-step directions ("how to get there") without traveling.

---

## 4. Evaluations (ISO/IEC 25010:2023 + TAM)

**Blocker:** Formal software quality evaluation (ISO/IEC 25010:2023 characteristics: functional suitability, performance efficiency, compatibility, usability, reliability, security, maintainability, portability) and Technology Acceptance Model (TAM: perceived usefulness, perceived ease of use, attitude, behavioral intention) require a complete, tested system and real users.

**Mock Strategy:** Defer to Phase 4 / post-development. Build evaluation instruments (surveys, test cases, heuristics) now so they are ready to execute once the mobile app and backend are solid.

---

## 5. Web Admin Portal (Phase 4)

**Blocker:** Explicitly deferred per Form I rules — built LAST, after the mobile app and backend are solid.

**Mock Strategy:** None required now. The `web_admin/` directory is reserved; 4-tier RBAC rules are defined in `docs/CAPSTONE_REQUIREMENTS.md` and enforced in the Supabase schema.

---

## Tracking Table

| # | Deferred Item | Dependency | Mock / Stub Approach | Target Revisit |
|---|---|---|---|---|
| 1 | Full Rizal dataset (14 LGUs) | LGU interviews + scraping | Pilot dataset: Angono, Binangonan, Taytay | After dataset completion |
| 2 | Llama LLM + RAG accuracy | Full dataset + LLM access | Canned RAG service interface | After dataset ready |
| 3 | Physical geofence testing | Travel to municipalities | Dev debug toggle to simulate entry | Field-test phase |
| 4 | ISO/IEC 25010:2023 + TAM eval | Complete system + real users | Evaluation instruments prepared now | Phase 4 / post-launch |
| 5 | Web Admin Portal | Mobile app + backend solid | Not built yet (Phase 4) | Phase 4 |
