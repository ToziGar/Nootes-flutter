# Nootes - Expanded MVP Roadmap

This document outlines a phased roadmap for the "Expanded MVP" feature set and adjacent infrastructure work. It's intended as a starting point — estimates are rough and should be validated with the team.

## Goals
- Stabilize core note editing and sharing flows.
- Provide robust offline-first sync and merge behavior.
- Improve sharing (leave/revoke) and server pagination for large note sets.
- Add polished editor UX (autosave, shortcuts, image caching) and advanced search.

---

## Phases

### Phase 0 — Prep (1–2 days)
- Create feature branch `feature/expanded-mvp` (done).
- Add testing harness for new editor behaviors and service injection (done).
- Add Sync Debug Page (done).

Acceptance criteria:
- CI runs unit/widget tests.
- Local dev can run headless widget tests reliably.


### Phase 1 — Editor Autosave & UX polish (3–5 days)
Deliverables:
- Autosave wired end-to-end (debounced + SaveIntent support) — done.
- Visual indicators for saving / unsaved state — done.
- Keyboard shortcuts for save, fullscreen, bold/italic — partially done.
- Responsive toolbar that avoids RenderFlex overflows — done.
- Widget tests covering autosave and editor UI states — done.

Acceptance criteria:
- Ctrl/Cmd+S triggers save, updates UI state, and calls `FirestoreService.updateNote`.
- Editor UI does not overflow in headless tests.
- Tests included and passing in CI.


### Phase 2 — Firestore save helpers, merge strategy & offline-first sync (5–10 days)
Deliverables:
- `FirestoreService` helpers for merge/update with transaction fallback (already implemented for updateNote).
- Client-side merge strategy and unit tests (LWW + list union semantics via `mergeNoteMaps`).
- Offline-first sync scaffolding and conflict resolution hooks.
- Integration tests with Firestore emulator for key flows.

Acceptance criteria:
- Updates are robust under concurrent writes (merge semantics covered by unit tests).
- Emulator-based integration tests confirm behavior.


### Phase 3 — Sharing improvements & server pagination (4–8 days)
Deliverables:
- Robust sharing leave/revoke behavior and UI flows.
- Sharing audit trail and validation for SharedItem (strict parsing + tests).
- Server-side paginated listing for notes (cursor/limit), with client helpers.

Acceptance criteria:
- Sharing revoke/leave operations remove access and are reflected in UI and Firestore rules.
- Pagination works for large note sets; client shows incremental loading.


### Phase 4 — Cached images, editor media UX & templates (4–7 days)
Deliverables:
- Image caching for remote images and uploaded media (use local cache + Storage rules).
- Improved media insertion UI and fullscreen media viewer.
- Templates and snippets support in editor.

Acceptance criteria:
- Images render from cache when offline.
- Media uploads robustly attach to notes with fallback for offline uploads.


### Phase 5 — Advanced search & indexing (4–7 days)
Deliverables:
- Advanced search with tokenization, filters, and fuzzy search (client + server / Algolia-like approach or Firestore composite indexes).
- Search indexing pipeline (incremental on update) and unit tests.

Acceptance criteria:
- Search returns relevant results quickly for large collections.
- Indexing handles concurrent updates and deletions.


### Phase 6 — Polish, accessibility, CI, release prep (3–5 days)
Deliverables:
- Accessibility improvements (a11y labels, keyboard nav).
- Performance tuning for editor and list pages.
- CI pipelines updated, release notes drafted.

Acceptance criteria:
- Lighthouse / accessibility checks pass thresholds.
- CI runs blue-green tests and deploy steps ready.

---

## Risks & Mitigations
- Firestore emulator mismatches production behavior: keep emulator-based tests for regression and rely on staged integration testing.
- Large code-surface changes: keep features behind feature flags when possible and add thorough tests.

## Immediate next steps (short-term)
- Finalize any toolbar UX decision (scroll vs overflow menu).
- Implement offline conflict resolution unit tests, and run emulator tests locally (requires FIRESTORE_EMULATOR_HOST).
- Start Phase 2: formalize merge strategy and add integration test harness.


---

If you want, I can convert this into GitHub issues and a project board (one card per deliverable) and open a PR for `feature/expanded-mvp` with the roadmap file.
