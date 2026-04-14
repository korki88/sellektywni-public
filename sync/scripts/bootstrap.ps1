# Uruchom z katalogu głównego repozytorium:  .\sync\scripts\bootstrap.ps1
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $root

Write-Host "[sync/bootstrap] Root: $root"

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "[sync/bootstrap] Utworzono .env z .env.example — uzupełnij sekrety."
}

npm install
npm run dev:up
Start-Sleep -Seconds 6
npx prisma migrate deploy
npm run db:seed

Write-Host "[sync/bootstrap] Gotowe. Uruchom: npm run start:dev"
