<#
Run Firestore emulator and integration tests (Windows PowerShell helper).

Usage (from repository root):
  pwsh .\scripts\run_emulator_and_tests.ps1

What the script does:
- Verifies Java is present (attempts winget install of Temurin JDK 21 if missing).
- Verifies firebase CLI is available (tries to install via npm if node is present).
- Runs `firebase emulators:exec` to start the Firestore emulator and execute
  the two integration tests.

Notes:
- This script assumes you have administrative rights when running winget
  installs, and that `flutter` is available on PATH. If winget/npm are not
  available, follow the manual instructions in the project README.
#>

function Write-Info($m){ Write-Host "[info] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[warn] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[error] $m" -ForegroundColor Red }

Write-Info "Starting emulator+integration test helper"

# Check java
try {
  $javaVersion = & java --version 2>&1
  if ($LASTEXITCODE -ne 0) { throw "java-not-found" }
  Write-Info "java available:`n$javaVersion"
} catch {
  Write-Warn "Java not found or not usable. Attempting to install Temurin JDK 21 via winget..."
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Info "Running: winget install -e --id EclipseAdoptium.Temurin.21.JDK"
    winget install -e --id EclipseAdoptium.Temurin.21.JDK
    Write-Info "Re-checking java..."
    Start-Sleep -Seconds 2
    try { & java --version; if ($LASTEXITCODE -ne 0) { throw } } catch { Write-Err "Please ensure Java is installed and on PATH. Exiting."; exit 1 }
  } else {
    Write-Err "winget not available. Please install a JDK 21+ manually (Temurin/Adoptium recommended). Exiting."; exit 1
  }
}

# Check firebase CLI
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Warn "firebase CLI not found. Trying to install via npm (requires node + npm)."
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install -g firebase-tools
  } else {
    Write-Err "npm not found. Please install firebase-tools manually (npm i -g firebase-tools) or install Node.js. Exiting."; exit 1
  }
}

# Ensure flutter is available
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Err "flutter not found on PATH. Please install Flutter and ensure 'flutter' is available in this shell. Exiting."; exit 1
}

Write-Info "All prerequisites appear available. Running emulator and integration tests..."

# Use emulators:exec so the emulator lifecycle is tied to the test run
$tests = 'test/integration/update_note_service_emulator_test.dart test/integration/update_note_emulator_test.dart'
# Build the emulators:exec command using single quotes to avoid nested double-quote parsing issues
$cmd = 'firebase emulators:exec --only firestore -- flutter test ' + $tests
Write-Info "Executing: $cmd"

Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) { Write-Info "Integration tests finished OK." } else { Write-Err "Integration tests exited with code $LASTEXITCODE"; exit $LASTEXITCODE }
