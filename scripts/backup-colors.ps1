<#
.SYNOPSIS
    Export Far Manager's current configuration to a timestamped .farconfig.

.DESCRIPTION
    Calls Far.exe /export to produce a full configuration snapshot (colors plus
    everything else). Useful before installing a new theme so you can roll back.

    Output filename includes a timestamp so each run produces a new file.

.PARAMETER OutputDir
    Where to save the backup. Default: Desktop.

.PARAMETER FarExe
    Path to Far.exe. Default: 'C:\Program Files\Far Manager\Far.exe'.

.EXAMPLE
    .\backup-colors.ps1

.EXAMPLE
    .\backup-colors.ps1 -OutputDir .\backups
#>
[CmdletBinding()]
param(
    [string]$OutputDir = [Environment]::GetFolderPath('Desktop'),
    [string]$FarExe    = 'C:\Program Files\Far Manager\Far.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FarExe))    { throw "Not found: $FarExe" }
if (-not (Test-Path $OutputDir)) { $null = New-Item -ItemType Directory -Path $OutputDir }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out   = Join-Path $OutputDir "far-config-backup-$stamp.farconfig"

$proc = Start-Process -FilePath $FarExe -ArgumentList '/export', "`"$out`"" `
    -PassThru -WindowStyle Hidden -Wait
if ($proc.ExitCode -ne 0) { throw "Far /export failed (exit $($proc.ExitCode))" }
if (-not (Test-Path $out))  { throw "Far reported success but no output file at $out" }

$size = [Math]::Round((Get-Item $out).Length / 1KB, 1)
Write-Host "Backup saved:" -ForegroundColor Green
Write-Host "  $out  ($size KB)"
Write-Host ""
Write-Host "To restore: open Far, then F9 -> Options -> Configuration editor -> Import."
