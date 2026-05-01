param(
    [Parameter(Mandatory = $true)]
    [Alias("Host")]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$User,

    [Parameter(Mandatory = $true)]
    [string]$RemotePath,

    [int]$Port = 22,

    [string]$IdentityFile,

    [string]$BaseHref = "/",

    [switch]$SkipBuild,

    [switch]$NoRemoteBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Quote-Remote {
    param([string]$Value)

    return "'" + $Value.Replace("'", "'\''") + "'"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot "build\web"
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$archive = Join-Path ([System.IO.Path]::GetTempPath()) "sawrly-web-$timestamp.tar.gz"
$remote = "$User@$Server"
$remotePathClean = $RemotePath.TrimEnd("/")
$remoteTempPath = "$remotePathClean.__upload_$timestamp"
$remoteBackupPath = "$remotePathClean.__backup_$timestamp"
$remoteArchive = "/tmp/sawrly-web-$timestamp.tar.gz"

if ([string]::IsNullOrWhiteSpace($remotePathClean) -or $remotePathClean -eq "/") {
    throw "Refusing to deploy to the remote root path. Set -RemotePath to the website directory, for example /var/www/sawrly."
}

Require-Command ssh
Require-Command scp
Require-Command tar

if (-not $SkipBuild) {
    Require-Command flutter

    Push-Location $projectRoot
    try {
        flutter pub get
        flutter build web --release --base-href $BaseHref
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $buildDir)) {
    throw "Build folder was not found: $buildDir"
}

if (Test-Path $archive) {
    Remove-Item -LiteralPath $archive -Force
}

tar -C $buildDir -czf $archive .

$sshArgs = @()
$scpArgs = @()

if ($Port -ne 22) {
    $sshArgs += @("-p", "$Port")
    $scpArgs += @("-P", "$Port")
}

if ($IdentityFile) {
    $sshArgs += @("-i", $IdentityFile)
    $scpArgs += @("-i", $IdentityFile)
}

scp @scpArgs $archive "${remote}:$remoteArchive"

$remotePathQ = Quote-Remote $remotePathClean
$remoteTempPathQ = Quote-Remote $remoteTempPath
$remoteBackupPathQ = Quote-Remote $remoteBackupPath
$remoteArchiveQ = Quote-Remote $remoteArchive

$backupCommand = if ($NoRemoteBackup) {
    "true"
}
else {
    "if [ -d $remotePathQ ] && [ `"`$(ls -A $remotePathQ 2>/dev/null)`" ]; then rm -rf $remoteBackupPathQ && mkdir -p $remoteBackupPathQ && cp -a $remotePathQ/. $remoteBackupPathQ/; fi"
}

$remoteCommand = @"
set -e
rm -rf $remoteTempPathQ
mkdir -p $remoteTempPathQ
tar -xzf $remoteArchiveQ -C $remoteTempPathQ
$backupCommand
mkdir -p $remotePathQ
find $remotePathQ -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a $remoteTempPathQ/. $remotePathQ/
rm -rf $remoteTempPathQ $remoteArchiveQ
"@

ssh @sshArgs $remote $remoteCommand

Remove-Item -LiteralPath $archive -Force

Write-Host "Deployed Flutter web build to ${remote}:$remotePathClean"
if (-not $NoRemoteBackup) {
    Write-Host "Remote backup path: $remoteBackupPath"
}
