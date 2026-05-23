#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot installer for all bundled theming-far themes.

.DESCRIPTION
    Detects the local Far Manager install (via registry uninstall keys, falling
    back to typical paths), then copies every theme bundled in this repo into
    Far's Addons\Colors\ directory:

      * 6 interface palettes (Light + Dark, three acrylic variants each)
        into Addons\Colors\Interface\
      * Per-family Highlighting.farconfig copied 3x under each variant name
        into Addons\Colors\Default Highlighting\

    Themes are passive (Far reads them at startup, user picks from the menu)
    so installing all six is cheap. Pick the one you like in
    F9 -> Options -> Colors -> Themes after Far restarts.

    Writes under Program Files require Administrator rights. If the current
    process isn't elevated, the script self-elevates (prefers Windows 11
    24H2+ 'sudo'; falls back to UAC Start-Process -Verb RunAs).

.PARAMETER FarRoot
    Override Far's install directory. By default it's detected from the
    Uninstall registry key, with a fallback to C:\Program Files\Far Manager.

.PARAMETER ThemesRoot
    Override the source themes directory. Defaults to ..\themes\ next to
    this script.

.PARAMETER NoElevate
    Skip auto-elevation. The script will fail if not already elevated.
    Useful for testing or scripted invocations that handle UAC externally.

.EXAMPLE
    # The recommended path: from an unelevated PowerShell, will prompt UAC once.
    .\Install-AllThemes.ps1

.EXAMPLE
    # Already-elevated terminal, no UAC prompt:
    .\Install-AllThemes.ps1
#>
param(
    [string]$FarRoot,
    [string]$ThemesRoot = (Join-Path $PSScriptRoot '..\themes'),
    [switch]$NoElevate,
    [switch]$WaitOnExit  # internal: set when self-elevating via Start-Process so the new window
                         # doesn't close before the user reads the result
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Locate Far Manager
# ---------------------------------------------------------------------------

function Find-FarRoot {
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
        if ($f -and (Test-Path (Join-Path $f 'Far.exe'))) { return $f }
    }

    # 3. PATH lookup
    $cmd = Get-Command Far.exe -ErrorAction SilentlyContinue
    if ($cmd) { return (Split-Path $cmd.Source -Parent) }

    return $null
}

if (-not $FarRoot) { $FarRoot = Find-FarRoot }
if (-not $FarRoot -or -not (Test-Path (Join-Path $FarRoot 'Far.exe'))) {
    throw "Far Manager not found. Pass -FarRoot 'C:\path\to\Far Manager' to override."
}

$colorsRoot = Join-Path $FarRoot 'Addons\Colors'
$ifcDir     = Join-Path $colorsRoot 'Interface'
$defDir     = Join-Path $colorsRoot 'Default Highlighting'
foreach ($d in $ifcDir, $defDir) {
    if (-not (Test-Path $d)) { throw "Far theme dir missing: $d (broken Far install?)" }
}

# ---------------------------------------------------------------------------
# Auto-elevate
# ---------------------------------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate) {
    # Quick can-write probe so we elevate only when truly needed
    try {
        $probe = Join-Path $ifcDir ('.theming-far-write-test-{0}.tmp' -f [guid]::NewGuid())
        Set-Content -Path $probe -Value 'x' -ErrorAction Stop
        Remove-Item $probe -ErrorAction SilentlyContinue
        # Surprise: we can write without elevation. Proceed.
    }
    catch {
        Write-Host "Elevation required to write into $colorsRoot. Requesting..." -ForegroundColor Yellow

        $psExe = (Get-Process -Id $PID).Path

        # For sudo we pass an array — PowerShell handles quoting.
        $sudoArgs = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', $PSCommandPath
            '-FarRoot', $FarRoot
            '-ThemesRoot', $ThemesRoot
        )

        # Build the cmd line once - same for both RunAs paths.
        $runAsCmd = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', "`"$PSCommandPath`""
            '-FarRoot', "`"$FarRoot`""
            '-ThemesRoot', "`"$ThemesRoot`""
            '-WaitOnExit'
        ) -join ' '

        $elevated = $false

        # Prefer sudo (Windows 11 24H2+ built-in, or gsudo) - same terminal, no popup.
        # Windows sudo can be installed but DISABLED via Developer Settings; in that
        # case it exits non-zero immediately and we fall back to RunAs.
        $sudoExe = Get-Command sudo -ErrorAction SilentlyContinue
        if ($sudoExe) {
            & sudo $psExe @sudoArgs
            if ($LASTEXITCODE -eq 0) {
                $elevated = $true
            }
            else {
                Write-Host "sudo failed or is disabled — falling back to UAC..." -ForegroundColor Yellow
            }
        }

        if (-not $elevated) {
            # Spawn a new elevated window. -WaitOnExit makes the child window pause
            # before closing so the user sees the result.
            Start-Process $psExe -Verb RunAs -ArgumentList $runAsCmd -Wait
        }

        exit $LASTEXITCODE
    }
}

# ---------------------------------------------------------------------------
# Discover themes in this repo
# ---------------------------------------------------------------------------

if (-not (Test-Path $ThemesRoot)) { throw "Themes directory not found: $ThemesRoot" }

$themeFamilies = Get-ChildItem $ThemesRoot -Directory
if (-not $themeFamilies) { throw "No theme families under $ThemesRoot" }

Write-Host "Far Manager detected at: $FarRoot" -ForegroundColor Cyan
Write-Host "Installing themes from:  $ThemesRoot" -ForegroundColor Cyan
Write-Host ""

$installed = 0
$installedHl = 0
$skipped = 0

foreach ($family in $themeFamilies) {
    Write-Host "[$($family.Name)]" -ForegroundColor Cyan

    $highlighting = Join-Path $family.FullName 'Highlighting.farconfig'
    $hasHighlighting = Test-Path $highlighting

    $variants = Get-ChildItem $family.FullName -Filter '*.farconfig' |
                Where-Object { $_.Name -ne 'Highlighting.farconfig' }

    if (-not $variants) {
        Write-Host "  (no theme variants found)" -ForegroundColor DarkGray
        continue
    }

    foreach ($v in $variants) {
        try {
            Copy-Item $v.FullName (Join-Path $ifcDir $v.Name) -Force
            Write-Host "  + $($v.Name)" -ForegroundColor Green
            $installed++

            if ($hasHighlighting) {
                Copy-Item $highlighting (Join-Path $defDir $v.Name) -Force
                $installedHl++
            }
        }
        catch [System.UnauthorizedAccessException] {
            throw "Access denied writing to $colorsRoot. Re-run from an elevated PowerShell, or remove -NoElevate."
        }
        catch {
            Write-Host "  ! failed $($v.Name): $_" -ForegroundColor Red
            $skipped++
        }
    }
}

Write-Host ""
Write-Host "Installed $installed theme$(if($installed -ne 1){'s'}) + $installedHl highlighting file$(if($installedHl -ne 1){'s'})." -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host "Skipped $skipped due to errors." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next: restart Far, then F9 -> Options -> Colors -> Themes."
Write-Host "When applying a theme, Far asks which sections to use - tick"
Write-Host "Default Highlighting only if you want our file-coloring rules"
Write-Host "(directories/exec/archives) to replace your existing ones."

if ($WaitOnExit) {
    Write-Host ""
    Write-Host "Press Enter to close this window." -ForegroundColor DarkGray
    [void](Read-Host)
}
