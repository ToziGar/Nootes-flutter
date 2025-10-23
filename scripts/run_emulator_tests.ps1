Write-Host "Running emulator-backed integration tests via wrapper"
# The Firebase emulator will inject FIRESTORE_EMULATOR_HOST and other env vars.
# Run the Flutter test command for the emulator integration tests.
flutter test test/_integration_clean -r expanded
