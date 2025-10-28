PR Title:
chore(sync): fix SyncService, make SecureQueueStorage testable, add tests and analyzer fixes

PR Description (copy into GitHub PR):
See CHANGELOG.md for details.

Summary:
- Restored and fixed `SyncService` (queue persistence, backoff, dead-letter).
- Made `SecureQueueStorage` testable by adding `SecureKeyValueStorage` abstraction and an in-memory fake.
- Added unit tests for queue storage and `SyncService` (including scheduling/backoff/dead-letter).
- Removed analyzer warnings across UI files (replaced unused double-underscore params).
- Updated lockfile for several non-breaking dependency updates.
- All tests pass locally and `flutter analyze` reports no issues.

Verification:
- `flutter analyze` — No issues.
- `flutter test` — All tests passed.

Checklist:
- [ ] Code compiles & analyzer clean
- [ ] Unit tests added and passing
- [ ] CHANGELOG.md included
- [ ] Review and approve changes
- [ ] Merge into `main`

PR link (open to create):
https://github.com/ToziGar/Nootes-flutter/pull/new/feat/sync-queue-testable
