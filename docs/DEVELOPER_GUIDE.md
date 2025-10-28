# Developer guide

This document explains how to run tests, the Firestore emulator, and the sync worker locally.

Running unit tests
------------------

- Install dependencies:

```pwsh
flutter pub get
```

- Run tests:

```pwsh
flutter test
```

Firestore emulator (optional)
-----------------------------

If you want to run integration tests against a local Firestore emulator:

1. Install the Firebase CLI: https://firebase.google.com/docs/cli
2. Start the emulator in the project root (assumes firebase.json is present):

```pwsh
firebase emulators:start --only firestore
```

3. Export the emulator host for the tests (PowerShell):

```pwsh
$env:FIRESTORE_EMULATOR_HOST = 'localhost:8080'
flutter test test/integration/sync_emulator_test.dart
```

Notes
-----
- The sync worker runs in the `SyncService` provider. In `main_demo.dart` the provider is initialized automatically.
- Use the `Sync Queue` UI from the demo to inspect and retry failing items.
