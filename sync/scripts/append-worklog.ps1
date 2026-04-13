param(
  [Parameter(Mandatory = $true)]
  [string]$Message
)
$ErrorActionPreference = "Stop"
$log = Join-Path $PSScriptRoot "..\WORKLOG.md"
$utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
$block = @"

## $utc UTC (auto)

- $Message

"@
Add-Content -Path $log -Value $block -Encoding utf8
Write-Host "[sync/log] Appended to WORKLOG.md"
