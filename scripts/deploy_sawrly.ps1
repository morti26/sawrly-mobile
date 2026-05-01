param(
    [string]$Server = "sawrly.com",
    [Parameter(Mandatory = $true)]
    [string]$User,
    [int]$Port = 22,
    [string]$RemotePath = "/mnt/disk-extra/hostingdata/cmnp2kdic001a4hr2yofnyk76/sawrly.com/public",
    [string]$IdentityFile = "",
    [string]$Pm2Name = "sawrly-web",
    [switch]$SkipLocalChecks,
    [switch]$SkipRemoteInstall,
    [switch]$SkipRemoteBuild,
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archive = Join-Path ([System.IO.Path]::GetTempPath()) "sawrly-deploy-$timestamp.tar.gz"
$remoteArchive = "/tmp/sawrly-deploy-$timestamp.tar.gz"
$target = "$User@$Server"

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

if (-not $SkipLocalChecks) {
    Invoke-LoggedStep "Running local tests" {
        Push-Location $projectRoot
        try {
            npm run test
        } finally {
            Pop-Location
        }
    }

    Invoke-LoggedStep "Building locally" {
        Push-Location $projectRoot
        try {
            npm run build
        } finally {
            Pop-Location
        }
    }
}

$excludeArgs = @(
    "--exclude=.git",
    "--exclude=node_modules",
    "--exclude=.next",
    "--exclude=out",
    "--exclude=dist",
    "--exclude=build",
    "--exclude=backups",
    "--exclude=devserver*.log",
    "--exclude=npm-debug.log*",
    "--exclude=yarn-debug.log*",
    "--exclude=yarn-error.log*",
    "--exclude=pnpm-debug.log*",
    "--exclude=.env",
    "--exclude=.env.local",
    "--exclude=.env.*.local",
    "--exclude=public/uploads",
    "--exclude=public/legacy_wwwroot",
    "--exclude=NUL",
    "--exclude=mobile/.dart_tool",
    "--exclude=mobile/build",
    "--exclude=mobile/.idea",
    "--exclude=mobile/run.log",
    "--exclude=mobile/.flutter-plugins-dependencies"
)

Invoke-LoggedStep "Creating deploy archive" {
    if (Test-Path $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
    $tarArgs = @("-czf", $archive) + $excludeArgs + @("-C", $projectRoot, ".")
    & tar @tarArgs
}

Invoke-LoggedStep "Uploading archive to $target" {
    & scp @scpArgs $archive "${target}:$remoteArchive"
}

$skipInstall = if ($SkipRemoteInstall) { "1" } else { "0" }
$skipBuild = if ($SkipRemoteBuild) { "1" } else { "0" }
$skipRestart = if ($NoRestart) { "1" } else { "0" }

$remoteScript = @"
set -euo pipefail

REMOTE_PATH=$(Quote-Bash $RemotePath)
ARCHIVE=$(Quote-Bash $remoteArchive)
BACKUP="/tmp/sawrly-public-backup-$timestamp.tar.gz"
PM2_NAME=$(Quote-Bash $Pm2Name)
SKIP_INSTALL="$skipInstall"
SKIP_BUILD="$skipBuild"
NO_RESTART="$skipRestart"

mkdir -p "`$REMOTE_PATH"

if [ -d "`$REMOTE_PATH" ]; then
  tar -czf "`$BACKUP" -C "`$REMOTE_PATH" .
  echo "Backup created: `$BACKUP"
fi

tar -xzf "`$ARCHIVE" -C "`$REMOTE_PATH"
rm -f "`$ARCHIVE"

cd "`$REMOTE_PATH"

if [ "`$SKIP_INSTALL" != "1" ]; then
  npm install
fi

if [ "`$SKIP_BUILD" != "1" ]; then
  npm run build
fi

if [ "`$NO_RESTART" != "1" ]; then
  if command -v pm2 >/dev/null 2>&1; then
    pm2 restart "`$PM2_NAME" || pm2 start npm --name "`$PM2_NAME" -- start
    pm2 save || true
  else
    echo "pm2 not found; restart the app manually."
  fi
fi

echo "Deploy completed in `$REMOTE_PATH"
"@

Invoke-LoggedStep "Deploying on remote server" {
    $remoteScript | & ssh @sshArgs $target "bash -s"
}

Invoke-LoggedStep "Checking public site" {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Method Head -Uri "https://sawrly.com/" -TimeoutSec 20
        Write-Host "https://sawrly.com/ responded with $($response.StatusCode)"
    } catch {
        Write-Warning "Could not verify https://sawrly.com/: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Done."
