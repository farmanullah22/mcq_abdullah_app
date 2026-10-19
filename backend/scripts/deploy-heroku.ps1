# One-shot Heroku deploy for the MCQ backend (monorepo friendly).
#
# Prerequisites:
#   $env:HEROKU_API_KEY  - Heroku API key (Dashboard -> Account -> API Key)
#   backend/.env         - source of MONGO_URI (or set $env:MONGO_URI)
#
# Usage:
#   $env:HEROKU_API_KEY = 'xxxx'
#   powershell -File scripts/deploy-heroku.ps1 -App abdullahcarpets-f997ce1dad43
#
# What it does:
#   1. verifies the CLI session
#   2. sets production config vars (MONGO_URI, NODE_ENV, JWT_SECRET, JWT_EXPIRES_IN)
#   3. splits backend/ into a deploy branch and pushes it to Heroku
param(
  [Parameter(Mandatory = $true)][string]$App,
  [string]$MongoUri,
  [string]$JwtSecret,
  [switch]$SkipConfig
)

$ErrorActionPreference = 'Stop'
$backendDir = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendDir

if (-not $env:HEROKU_API_KEY) { throw 'HEROKU_API_KEY is not set.' }

Write-Host '==> Verifying Heroku session' -ForegroundColor Cyan
heroku auth:whoami

Write-Host "==> Checking app $App" -ForegroundColor Cyan
$apps = heroku apps:list --json | ConvertFrom-Json
if (-not ($apps | Where-Object { $_.name -eq $App })) {
  throw "App '$App' not found. Available: $($apps.name -join ', ')"
}

if (-not $SkipConfig) {
  Write-Host '==> Setting config vars' -ForegroundColor Cyan
  if (-not $MongoUri) {
    $envFile = Join-Path $backendDir '.env'
    if (-not (Test-Path $envFile)) { throw 'MONGO_URI not provided and backend/.env not found.' }
    $line = Get-Content $envFile | Where-Object { $_ -match '^\s*MONGO_URI\s*=' } |
      Where-Object { $_ -notmatch '^\s*#' } | Select-Object -First 1
    if (-not $line) { throw 'MONGO_URI not found in backend/.env.' }
    $MongoUri = ($line -split '=', 2)[1].Trim()
  }
  if (-not $JwtSecret) {
    $JwtSecret = node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
    Write-Host '    (generated a new JWT_SECRET for production)' -ForegroundColor DarkGray
  }
  heroku config:set -a $App "NODE_ENV=production" "MONGO_URI=$MongoUri" "JWT_SECRET=$JwtSecret" "JWT_EXPIRES_IN=7d"
}

Write-Host '==> Building deploy branch from backend/ (git subtree split)' -ForegroundColor Cyan
Push-Location $repoRoot
try {
  git branch -D heroku-deploy 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { $global:LASTEXITCODE = 0 }
  git subtree split --prefix backend -b heroku-deploy
  if ($LASTEXITCODE -ne 0) { throw 'git subtree split failed.' }

  Write-Host '==> Pushing to Heroku (this triggers the build)' -ForegroundColor Cyan
  git remote | Where-Object { $_ -eq 'heroku' } | ForEach-Object { git remote remove heroku }
  heroku git:remote -a $App
  git push heroku heroku-deploy:main --force
  if ($LASTEXITCODE -ne 0) { throw 'Push to Heroku failed.' }
} finally {
  Pop-Location
}

Write-Host '==> Release info' -ForegroundColor Cyan
heroku releases -a $App | Select-Object -First 5

Write-Host "`nDone. Health URL: https://$App.herokuapp.com/api/health" -ForegroundColor Green
