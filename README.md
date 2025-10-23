# Nootes — Flutter Offline‑First Notes App (Expanded MVP)

A compact, production‑minded README crafted for contributors and maintainers of the Nootes Flutter project.

---

## Table of contents

- About
- Goals & MVP
- Architecture overview
- Key components and contracts
- Local development (setup)
- Running the demo
- Running tests & analyzer
- Sync design (queue, backoff, dead-letter)
- Providers & dependency wiring
- Important files and folders
- Common tasks
- Roadmap & next steps
- Contributing
- Troubleshooting

---

## About

Nootes is a Flutter note-taking app focused on resilient offline-first behavior, safe remote sync with Firestore, and an enriched editor UX. This repository contains the app (mobile, web, desktop) and a feature branch `feature/expanded-mvp` that implements an expanded MVP with a local sync queue, dead-letter handling, a demo-only in-memory Firestore backend, and supportive developer tooling.

This README documents the project's structure, how to run the demo, the sync architecture, tests, and the key integration points you should know as a contributor.

---

## Goals & MVP (what this branch aims to deliver)

Primary goals:
- Local editing and reliable sync to Firestore via a local queue.
- Safe write centralization to prevent cross-note overwrites.
- Simple local DB abstraction (in-memory now; Isar planned) with a clear migration path.
- Developer-friendly demo (`main_demo.dart`) that runs without Firebase.
- Deterministic unit tests for sync behavior (including backoff and dead-letter).

Success criteria (examples):
- Create a note offline → it is queued locally and synced when online.
- A single buggy write cannot accidentally overwrite other notes.
- Persistent queue on native platforms (via secure storage) so a restart doesn't lose pending writes.

---

## Architecture overview

High level layers:

- domain/: business models (e.g., `Note`) and pure logic.
- data/: repository interfaces and in-memory/Isar repository implementations.
- services/: external integrations (Firestore abstraction, SyncService, QueueStorage).
- widgets/: UI components and small reusable widgets.
- pages/: full-screen pages and navigation.
- test/: unit and integration tests.

Key decisions:
- Riverpod for DI and state management (`flutter_riverpod`).
- `FirestoreService` as a single abstraction point to centralize and secure remote writes.
- `SyncService` implements the offline queue, exponential backoff retries, and a dead-letter queue.
- `QueueStorage` abstraction with `InMemoryQueueStorage` (web/dev) and `SecureQueueStorage` (mobile/desktop) for persistence.

---

## Key components and contracts

- Note model: `lib/domain/note.dart` — canonical shape for notes, with `toMap()` / `fromMap()`.
- NoteRepository: `lib/data/note_repository.dart` — defines how notes are persisted locally (in-memory for tests/demo; Isar planned).
- FirestoreService: `lib/services/firestore_service.dart` — single place for all Firestore reads/writes.
- DevFirestoreService: `lib/services/firestore_dev.dart` — in-memory, lightweight Firestore replacement for demos and tests.
- SyncService: `lib/services/sync_service.dart` — the offline queue + worker that pushes local changes to `FirestoreService`.
- QueueStorage: `lib/services/queue_storage.dart` — persistor interface and implementations.
- Providers: `lib/services/providers.dart` — Riverpod wiring for injection (queue storage, sync service, firestore service, etc.).

Contract highlights for SyncService:
- enqueue(Note): queues a note locally and persists the queue.
- loadFromStorage(): reloads persisted queue & dead-letter.
- start()/stop(): control the worker.
- processOnce(ignoreSchedule:): deterministic test hook that processes queued items immediately.
- dead-letter APIs: getDeadLetter(), retryDeadLetter(index), removeDeadLetter(index).

---

## Local development (quick start)

Prerequisites
- Flutter (stable channel recommended) installed and on PATH.
- A modern OS (Windows/macOS/Linux). This repo supports web, mobile and desktop targets.

Clone and get dependencies

```bash
git clone <repo-url>
cd Nootes-flutter
flutter pub get
```

Run the demo (no Firebase required)

```bash
# Runs the demo app which uses the in-memory DevFirestoreService
flutter run -t lib/main_demo.dart -d chrome
```

Notes
- The demo app wires `DevFirestoreService` through Riverpod overrides so you can run without Firebase credentials.
- Use the FAB in the demo to enqueue demo notes; open DevTools console or check the terminal to see logs.

---

## Running tests & analyzer

Run analyzer:

```bash
flutter analyze
```

Run unit tests (examples):

```bash
# run all tests
flutter test

# run a single test file for quick iteration
flutter test test/demo_sync_integration_test.dart -r expanded
```

The project contains deterministic tests for SyncService (enqueue, retries, dead-letter). Tests use `InMemoryQueueStorage` and `DevFirestoreService` to avoid external dependencies.

---

## Sync design (summary)

SyncService implements a conservative and testable sync pattern:

- Local writes (note edits) are enqueued via `enqueue(note)`.
- Each queue item is: { note, retries, nextAttempt } and persisted via `QueueStorage`.
- A worker (Timer) processes the queue periodically, honoring `nextAttempt`.
- On failure, the service uses exponential backoff (1 << retries, capped) and increments retries.
- Items exceeding `maxRetries` are moved to a dead-letter queue for manual review.
- Exposed APIs: retryDeadLetter(index) to requeue an item, removeDeadLetter(index) to discard it.

This keeps the sync logic isolated and deterministic for tests (via `processOnce(ignoreSchedule:true)`).

---

## Providers & wiring

`lib/services/providers.dart` contains the main Riverpod bindings:
- `queueStorageProvider` — returns `InMemoryQueueStorage` on web, `SecureQueueStorage` on native.
- `noteRepositoryProvider` — default `InMemoryNoteRepository` (swap with `IsarNoteRepository` later).
- `firestoreServiceProvider` — throws by default; override in `main.dart` or `main_demo.dart`.
- `syncServiceProvider` — constructs `SyncService`, calls `loadFromStorage()` and `start()` asynchronously, and stops on dispose.
- `syncStatusProvider` — StreamProvider that maps `SyncService.statusStream` to a `SyncStatus` domain object used by `SyncStatusWidget`.

---

## Important files & folders

- `lib/main.dart` — entrypoint for the full app (needs production `FirestoreService` wiring).
- `lib/main_demo.dart` — demo entrypoint that overrides providers to run without Firebase.
- `lib/services/sync_service.dart` — sync queue implementation (core of offline-first).
- `lib/services/firestore_service.dart` — Firestore abstraction used throughout the app.
- `lib/services/firestore_dev.dart` — in-memory Firestore used for local development.
- `lib/services/queue_storage.dart` — queue persistence abstractions.
- `lib/widgets/sync_status_widget.dart` — simple UI to show queue/dead-letter counts.
- `lib/widgets/dead_letter_widget.dart` — UI to inspect, retry and discard dead-letter items.
- `test/` — unit and integration tests. See `test/demo_sync_integration_test.dart` as an example.

---

## Common tasks (cheat sheet)

- Start demo locally (web):

```bash
flutter run -t lib/main_demo.dart -d chrome
```

- Run tests quickly for a single file:

```bash
flutter test test/path_to_test.dart -r expanded
```

- Run analyzer:

```bash
flutter analyze
```

- Create a new branch for a feature/fix:

```bash
git checkout -b feat/your-feature-name
```

---

## Roadmap & next steps (short to mid-term)

The `ROADMAP.md` contains detailed milestones. Highlights:

1. Persisted local DB using Isar (or a fallback such as Hive) and `IsarNoteRepository`.
2. Migrate the demo in-memory repository to production-ready local DB with migrations.
3. Integration tests against Firestore emulator to validate real sync and security rules.
4. Editor improvements (autosave, markdown/rtf mixed support) and UX polish.
5. Production `FirestoreService` wiring and Firebase auth (Google sign-in flow).
6. Security: optional per-note encryption and key storage using `flutter_secure_storage`.

---

## Contributing

- Fork the repo, create a branch, open a PR against `feature/expanded-mvp` (or `main` if appropriate).
- Run `flutter analyze` and unit tests before opening the PR.
- Keep changes small and focused. For large refactors (Isar integration) open a design PR first.

---

## Troubleshooting

- If `flutter pub get` fails due to incompatible package versions, run `flutter pub outdated` to inspect mismatches.
- If tests unexpectedly launch a browser/device, ensure `TestWidgetsFlutterBinding.ensureInitialized()` is used in test setup.
- For Firestore emulator integration, follow official Firebase docs to install and run the emulator locally.

---

## Contact / Maintainers

- Repo owner: `ToziGar` (GitHub)
- For quick help, open an issue with steps to reproduce and relevant logs.

---

Thank you for contributing. If you want, I can also:
- Add a CI workflow (`.github/workflows/ci.yml`) that runs analyzer + tests.
- Create a CONTRIBUTING.md with code style and PR guidelines.
- Generate small HOWTO docs (e.g., "Add Isar schema and run codegen").

Tell me which of those you'd like next and I’ll implement it.
