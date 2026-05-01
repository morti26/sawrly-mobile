param(
    [string]$Server = "sawrly.com",
    [Parameter(Mandatory = $true)]
    [string]$User,
    [int]$Port = 22,
    [string]$RemotePath = "/mnt/disk-extra/hostingdata/cmnp2kdic001a4hr2yofnyk76/sawrly.com/public",
    [string]$IdentityFile = "",
    [string]$TargetPath = "",
    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workspaceRoot = Split-Path -Parent $projectRoot
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ($TargetPath.Trim().Length -eq 0) {
    $TargetPath = Join-Path $workspaceRoot "sawrly-server-snapshot-$timestamp"
}

$target = "$User@$Server"
$remoteArchive = "/tmp/sawrly-source-$timestamp.tar.gz"
$localArchive = Join-Path ([System.IO.Path]::GetTempPath()) "sawrly-source-$timestamp.tar.gz"

function Quote-Bash([string]$Value) {
    return "'" + $Value.Replace("'", "'\''") + "'"
}

function Invoke-LoggedStep([string]$Name, [scriptblock]$Step) {
    Write-Host ""
    Write-Host "==> $Name"
    & $Step
}

$sshArgs = @("-p", "$Port")
$scpArgs = @("-P", "$Port")
if ($IdentityFile.Trim().Length -gt 0) {
    $sshArgs += @("-i", $IdentityFile)
    $scpArgs += @("-i", $IdentityFile)
}

if ((Test-Path $TargetPath) -and -not $Overwrite) {
    throw "TargetPath already exists: $TargetPath. Use -Overwrite or choose another -TargetPath."
}

New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null

$remoteScript = @"
set -euo pipefail

REMOTE_PATH=$(Quote-Bash $RemotePath)
ARCHIVE=$(Quote-Bash $remoteArchive)

test -d "`$REMOTE_PATH"
tar \
  --exclude='./.git' \
  --exclude='./node_modules' \
  --exclude='./.next' \
  --exclude='./out' \
  --exclude='./dist' \
  --exclude='./build' \
  --exclude='./backups' \
  --exclude='./public/uploads' \
  --exclude='./public/legacy_wwwroot' \
  --exclude='./mobile/.dart_tool' \
  --exclude='./mobile/build' \
  --exclude='./mobile/.idea' \
  --exclude='./mobile/run.log' \
  --exclude='./mobile/.flutter-plugins-dependencies' \
  -czf "`$ARCHIVE" -C "`$REMOTE_PATH" .

echo "`$ARCHIVE"
"@

Invoke-LoggedStep "Creating source archive on $target" {
    $remoteScript | & ssh @sshArgs $target "bash -s"
}

Invoke-LoggedStep "Downloading archive" {
    & scp @scpArgs "${target}:$remoteArchive" $localArchive
}

Invoke-LoggedStep "Cleaning remote archive" {
    & ssh @sshArgs $target "rm -f $(Quote-Bash $remoteArchive)"
}

Invoke-LoggedStep "Extracting into $TargetPath" {
    & tar -xzf $localArchive -C $TargetPath
}

Write-Host ""
Write-Host "Snapshot downloaded to $TargetPath"
