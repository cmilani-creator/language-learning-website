# Starts the LocalGuia frontend on http://localhost:3000 (Windows PowerShell 5.1+).
# Requires Node.js 20+:  winget install OpenJS.NodeJS.LTS   (then open a NEW terminal)
# Usage:  powershell -ExecutionPolicy Bypass -File .\start-frontend.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "frontend")

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    # winget installs here; a terminal opened before the install won't have it on PATH yet.
    $nodeDir = "C:\Program Files\nodejs"
    if (Test-Path (Join-Path $nodeDir "node.exe")) { $env:Path = "$nodeDir;$env:Path" }
    else { throw "Node.js is not installed. Run:  winget install OpenJS.NodeJS.LTS  then open a new terminal." }
}

# Trust the Windows certificate store (needed behind corporate TLS-inspecting proxies;
# otherwise npm fails with UNABLE_TO_GET_ISSUER_CERT_LOCALLY). Requires Node 22.15+/23.8+.
$env:NODE_OPTIONS = "--use-system-ca"

if (-not (Test-Path "node_modules\next")) {
    Write-Host "Installing frontend dependencies (first run only)..." -ForegroundColor Cyan
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed (see output above)" }
}

Write-Host "Starting frontend on http://localhost:3000 (backend must be running on :8000). Ctrl+C to stop." -ForegroundColor Green
npm run dev
