CI guide - tests for Nootes-flutter

This document explains how to run tests locally and in CI. There are two test styles in this repo:

- Mocked REST tests: fast, do not need the Firestore emulator. They use MockClient and are ideal for CI.
- Emulator-backed tests: exercise the Firestore emulator and security rules. These require the emulator and a modern JDK (>=21).

Quick local commands

Run mocked integration tests only:

```powershell
flutter test test/integration_mocked -r expanded
```

Run full test suite:

```powershell
flutter test -r expanded
```

Emulator-backed local run

1) Ensure JDK 21 is available and set JAVA_HOME (example on Windows):

```powershell
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21'
```

2) Install firebase-tools (requires npm):

```powershell
npm install -g firebase-tools
```

3) Start the Firestore emulator and set FIRESTORE_EMULATOR_HOST:

```powershell
firebase emulators:start --only firestore --project your-project-id &
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
```

4) Run tests:

```powershell
flutter test -r expanded
```

CI notes

- Prefer the mocked tests as the default job in CI (fast and deterministic).
- If you need emulator-backed validation in CI, ensure the runner has JDK21 and firebase-tools installed. See the example workflow in `.github/workflows/flutter-tests.yml`.
