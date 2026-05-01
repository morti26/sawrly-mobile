param(
    [string]$DatabaseUrl = $env:DATABASE_URL,
    [string]$OutputDir = "$PSScriptRoot\..\backups",
    [int]$KeepDays = 14
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
    throw "DATABASE_URL is missing. Pass -DatabaseUrl or set env:DATABASE_URL."
}

# Some app DATABASE_URL values include query keys used by app clients only
# (for example `schema=public`) that pg_dump does not accept.
if ($DatabaseUrl -match '^postgres(ql)?://') {
    $uriBuilder = [System.UriBuilder]::new($DatabaseUrl)
    if (-not [string]::IsNullOrWhiteSpace($uriBuilder.Query)) {
        $pairs = $uriBuilder.Query.TrimStart('?') -split '&' | Where-Object { $_ -ne '' }
        $filtered = @()
        foreach ($pair in $pairs) {
            $key = ($pair -split '=', 2)[0]
            if ($key -ne 'schema') {
                $filtered += $pair
            }
        }
        $uriBuilder.Query = [string]::Join('&', $filtered)
        $DatabaseUrl = $uriBuilder.Uri.AbsoluteUri
    }
}

$pgDumpCmd = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $pgDumpCmd) {
    throw "pg_dump was not found in PATH. Install PostgreSQL client tools first."
}

$resolvedOutputDir = Resolve-Path -LiteralPath $OutputDir -ErrorAction SilentlyContinue
if (-not $resolvedOutputDir) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $resolvedOutputDir = Resolve-Path -LiteralPath $OutputDir
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sqlFile = Join-Path $resolvedOutputDir.Path "backup_$timestamp.sql"
$zipFile = Join-Path $resolvedOutputDir.Path "backup_$timestamp.zip"

Write-Host "Creating PostgreSQL backup..."
& $pgDumpCmd.Source `
    --no-owner `
    --no-privileges `
    --encoding UTF8 `
    --format plain `
    --file $sqlFile `
    $DatabaseUrl

if ($LASTEXITCODE -ne 0) {
    throw "pg_dump failed with exit code $LASTEXITCODE."
}

Write-Host "Compressing backup..."
Compress-Archive -LiteralPath $sqlFile -DestinationPath $zipFile -Force
Remove-Item -LiteralPath $sqlFile -Force

Write-Host "Pruning backups older than $KeepDays days..."
$cutoff = (Get-Date).AddDays(-1 * [math]::Abs($KeepDays))
Get-ChildItem -LiteralPath $resolvedOutputDir.Path -File -Filter "backup_*.zip" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force

Write-Host "Backup ready: $zipFile"
