#Requires -Version 5.1
<#
    _FarCommon.ps1 — shared helpers for the theming-far scripts.

    Dot-source this file, don't run it:  . "$PSScriptRoot\_FarCommon.ps1"

    Provides:
      Find-FarRoot        Locate the Far Manager install directory.
      Get-FarExe          Full path to Far.exe under a given root.
      Test-FarRunning     Is a Far process currently running?
      Wait-FarClosed      Interactively wait until the user closes Far.
#>

Set-StrictMode -Version Latest

function Find-FarRoot {
    <#
    .SYNOPSIS
        Locate Far Manager's install directory.
    .DESCRIPTION
        Tries, in order: the Uninstall registry keys (system-wide + per-user),
        typical fixed install paths, then a PATH lookup. Returns $null if not
        found. A caller-supplied -Override short-circuits everything (used to
        honor a -FarRoot script parameter).
    #>
    [CmdletBinding()]
    param([string]$Override)

    if ($Override) {
        if (Test-Path (Join-Path $Override 'Far.exe')) { return $Override.TrimEnd('\','/') }
        throw "Far.exe not found under -FarRoot '$Override'."
    }

    # 1. Registry uninstall keys (system-wide + per-user)
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($p in $regPaths) {
        $hits = Get-ChildItem $p -ErrorAction SilentlyContinue | ForEach-Object {
            $i = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if (-not $i) { return }
            $dn = $i.PSObject.Properties['DisplayName']
            $il = $i.PSObject.Properties['InstallLocation']
            if ($dn -and $il -and $dn.Value -like '*Far Manager*' -and $il.Value) {
                $loc = $il.Value.TrimEnd('\','/')
                if (Test-Path (Join-Path $loc 'Far.exe')) { $loc }
            }
        }
        if ($hits) { return ($hits | Select-Object -First 1) }
    }

    # 2. Typical fixed paths
    $fallbacks = @(
        "$env:ProgramFiles\Far Manager",
        "${env:ProgramFiles(x86)}\Far Manager",
        "$env:LOCALAPPDATA\Far Manager"
    )
    foreach ($f in $fallbacks) {
        if ($f -and (Test-Path (Join-Path $f 'Far.exe'))) { return $f.TrimEnd('\','/') }
    }

    # 3. PATH lookup
    $cmd = Get-Command Far.exe -ErrorAction SilentlyContinue
    if ($cmd) { return (Split-Path $cmd.Source -Parent) }

    return $null
}

function Get-FarExe {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FarRoot)
    $exe = Join-Path $FarRoot 'Far.exe'
    if (-not (Test-Path $exe)) { throw "Far.exe not found at '$exe'." }
    return $exe
}

function Test-FarRunning {
    [OutputType([bool])]
    param()
    [bool](Get-Process -Name 'Far' -ErrorAction SilentlyContinue)
}

function Wait-FarClosed {
    <#
    .SYNOPSIS
        Block until no Far process is running, prompting the user to close it.
    .DESCRIPTION
        Importing config while Far is open is unsafe: Far rewrites its SQLite
        DBs from in-memory state on exit, silently discarding the import. So we
        never kill Far — we ask the user to close it and wait. Returns $true if
        Far is closed (ready to import), $false if the user cancelled.
    #>
    [OutputType([bool])]
    param()

    if (-not (Test-FarRunning)) { return $true }

    Write-Host ''
    Write-Host 'Far Manager is currently running.' -ForegroundColor Yellow
    Write-Host 'Importing while Far is open would be discarded when Far exits.' -ForegroundColor Yellow
    Write-Host 'Please close all Far windows, then press Enter to continue (Esc to cancel).' -ForegroundColor Yellow

    while (Test-FarRunning) {
        if ([Console]::IsInputRedirected) {
            # No interactive console — can't prompt; bail rather than loop forever.
            Write-Host 'Far is still running and input is non-interactive — aborting.' -ForegroundColor Red
            return $false
        }
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') { return $false }
        if ($key.Key -eq 'Enter') {
            if (Test-FarRunning) {
                Write-Host 'Far is still running. Close it and press Enter again (Esc to cancel).' -ForegroundColor Yellow
            }
        }
    }
    return $true
}
