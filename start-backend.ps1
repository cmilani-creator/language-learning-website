# Starts the LocalGuia backend on http://localhost:8000 (Windows PowerShell 5.1+).
# First run creates backend\.venv and installs dependencies; later runs start immediately.
# Usage:  powershell -ExecutionPolicy Bypass -File .\start-backend.ps1 [-WithNlp] [-WithAudio]
param([switch]$WithNlp, [switch]$WithAudio)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "backend")

# Keep the venv on a short path: deep project folders + compiled wheels (SQLAlchemy, pydantic-core)
# exceed Windows' 260-char MAX_PATH and fail with "The filename or extension is too long".
$venv = Join-Path $env:LOCALAPPDATA "LocalGuia\venv"
$py = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "Creating virtual environment in $venv ..." -ForegroundColor Cyan
    python -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "Could not create venv. Is Python 3.11+ installed and on PATH?" }
    & $py -m pip install --upgrade pip
    & $py -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw "pip install failed (see output above)" }
}
if ($WithNlp) {
    & $py -m pip install -r requirements-nlp.txt
    & $py -m spacy download es_core_news_sm
}
if ($WithAudio) { & $py -m pip install -r requirements-audio.txt }

Write-Host "Starting backend on http://localhost:8000 (API docs: /docs). Ctrl+C to stop." -ForegroundColor Green
& $py -m uvicorn app.main:app --port 8000
