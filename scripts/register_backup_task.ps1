param(
    [string]$TaskName = "Sorely-DB-Backup",
    [string]$DailyAt = "02:30",
    [string]$KeepDays = "14"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$backupScript = Join-Path $projectRoot "scripts\backup_postgres.ps1"

if (-not (Test-Path $backupScript)) {
    throw "Backup script not found: $backupScript"
}

$powershellPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$taskCommand = "`"$powershellPath`" -NoProfile -ExecutionPolicy Bypass -File `"$backupScript`" -KeepDays $KeepDays"

Write-Host "Registering scheduled task '$TaskName' at $DailyAt ..."
schtasks /Create /F /SC DAILY /TN $TaskName /TR $taskCommand /ST $DailyAt | Out-Null

Write-Host "Task registered successfully."
Write-Host "You can verify with: schtasks /Query /TN $TaskName /V /FO LIST"
