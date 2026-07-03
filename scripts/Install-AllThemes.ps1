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
# Locate Far Manager  (Find-FarRoot lives in the shared _FarCommon.ps1)
# ---------------------------------------------------------------------------

. "$PSScriptRoot\_FarCommon.ps1"

$FarRoot = Find-FarRoot -Override $FarRoot
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

# ---------------------------------------------------------------------------
# Colorer schemes (optional — only if FarColorer plugin is installed)
# ---------------------------------------------------------------------------

$colorerBase    = Join-Path $FarRoot 'Plugins\FarColorer\base'
$colorerCatalog = Join-Path $colorerBase 'catalog.xml'
$colorerHrdDir  = Join-Path $colorerBase 'hrd\rgb'

if (Test-Path $colorerCatalog) {
    Write-Host ""
    Write-Host "FarColorer detected — installing syntax-highlighting schemes" -ForegroundColor Cyan

    if (-not (Test-Path $colorerHrdDir)) {
        $null = New-Item -ItemType Directory -Path $colorerHrdDir -Force
    }

    # Collect (family, hrd-file) pairs
    $hrdSchemes = foreach ($family in $themeFamilies) {
        $hrd = Join-Path $family.FullName 'Colorer.hrd'
        if (Test-Path $hrd) {
            # Theme name = capitalised family name (FarLight-2026 -> FarLight2026)
            $schemeName = ($family.Name -split '-' | ForEach-Object {
                if ($_ -match '^\d') { $_ } else {
                    [char]::ToUpper($_[0]) + $_.Substring(1)
                }
            }) -join ''
            [pscustomobject]@{
                Family     = $family.Name
                Source     = $hrd
                SchemeName = $schemeName
                Target     = Join-Path $colorerHrdDir "$schemeName.hrd"
            }
        }
    }

    if ($hrdSchemes) {
        # 1a. Remove any existing FarLight/FarDark .hrd files first. On NTFS
        #     (case-insensitive) Copy-Item -Force overwrites contents but keeps
        #     the OLD filename casing — so if an earlier run created
        #     "Farlight2026.hrd", a later run with target "FarLight2026.hrd"
        #     would not actually rename it. Delete-then-copy fixes this.
        $existingFar = Get-ChildItem $colorerHrdDir -Filter 'Far*2026*.hrd' -ErrorAction SilentlyContinue
        $currentTargetExact = $hrdSchemes.Target | ForEach-Object { Split-Path $_ -Leaf }
        foreach ($f in $existingFar) {
            # Case-sensitive comparison — Farlight2026.hrd != FarLight2026.hrd.
            $isWrongCase = -not ($currentTargetExact -ccontains $f.Name)
            Remove-Item $f.FullName -Force
            if ($isWrongCase) {
                Write-Host "  - removed stale: hrd\rgb\$($f.Name)" -ForegroundColor DarkGray
            }
        }

        # 1b. Copy HRD files
        foreach ($s in $hrdSchemes) {
            Copy-Item $s.Source $s.Target -Force
            Write-Host "  + hrd\rgb\$($s.SchemeName).hrd" -ForegroundColor Green
        }

        # 2. Patch catalog.xml — idempotently register our schemes
        $catalog = Get-Content $colorerCatalog -Raw

        # Back up the original ONCE (next to it; not overwritten on re-runs)
        $backup = "$colorerCatalog.theming-far.bak"
        if (-not (Test-Path $backup)) {
            Copy-Item $colorerCatalog $backup -Force
            Write-Host "  + catalog.xml backed up to $(Split-Path $backup -Leaf)" -ForegroundColor DarkGray
        }

        # Remove any prior block we inserted (delimited by our markers), then re-insert.
        # This keeps the patch idempotent. We also consume one preceding line of
        # whitespace so we don't accumulate blank lines on repeat runs, but we do
        # NOT eat whitespace AFTER the end-marker — that's the indent for </hrd-sets>.
        $beginMark = '<!-- theming-far:begin -->'
        $endMark   = '<!-- theming-far:end -->'
        $blockRx   = "(?s)\r?\n[ \t]*$([regex]::Escape($beginMark)).*?$([regex]::Escape($endMark))"
        $catalog = [regex]::Replace($catalog, $blockRx, '')

        # Build our block — every line indented 8 spaces to match siblings.
        $blockLines = @("        $beginMark")
        foreach ($s in $hrdSchemes) {
            $desc = "$($s.SchemeName) (theming-far)"
            $blockLines += "        <hrd class=`"rgb`" name=`"$($s.SchemeName)`" description=`"$desc`">"
            $blockLines += "            <location link=`"hrd/rgb/$($s.SchemeName).hrd`"/>"
            $blockLines += "        </hrd>"
        }
        $blockLines += "        $endMark"
        $block = $blockLines -join "`r`n"

        # Insert before </hrd-sets>. Capture the existing closing tag with its
        # leading whitespace and prepend our block. This is a concrete (non-lookahead)
        # match so it fires exactly once.
        if ($catalog -match '(\s*)</hrd-sets>') {
            $catalog = [regex]::Replace($catalog, '(\s*)</hrd-sets>', {
                param($m)
                "`r`n$block$($m.Groups[1].Value)</hrd-sets>"
            })
            Set-Content -Path $colorerCatalog -Value $catalog -Encoding UTF8 -NoNewline
            Write-Host "  + catalog.xml patched: $($hrdSchemes.Count) scheme(s) registered" -ForegroundColor Green
        }
        else {
            Write-Host "  ! catalog.xml has no </hrd-sets> tag — skipped registration" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host ""
    Write-Host "FarColorer plugin not found — skipping syntax-highlighting schemes." -ForegroundColor DarkGray
    Write-Host "(That's fine if you don't use F4 editor with syntax highlighting.)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Next:"
Write-Host "  1. Restart Far."
Write-Host "  2. Pick a theme. Two ways, with an IMPORTANT difference:"
Write-Host "     a) F9 -> Options -> Colors -> Themes -> <pick> applies the"
Write-Host "        INTERFACE PALETTE ONLY. Far's Themes menu never applies file"
Write-Host "        highlighting (executables/archives coloring) — that's by design."
Write-Host "     b) To apply the palette AND the file highlighting in one shot, run:"
Write-Host "           .\Import-Theme.ps1            (interactive picker)"
Write-Host "           .\Import-Theme.ps1 -Theme FarLight2026Acrylic"
Write-Host "        It imports a combined config via 'Far.exe -import' (Far must be"
Write-Host "        closed). Do NOT press Ctrl+R in the file-highlighting dialog — it"
Write-Host "        resets colors to Far's indexed console defaults, not this theme."
if (Test-Path $colorerCatalog) {
    Write-Host "  3. For F4 editor syntax colors:"
    Write-Host "     F11 -> FarColorer -> Settings -> Main settings"
    Write-Host "     Tick [x] TrueMod Enable, then pick FarLight2026 (or FarDark2026)"
    Write-Host "     in the TrueMod color style dropdown."
}

if ($WaitOnExit) {
    Write-Host ""
    Write-Host "Press Enter to close this window." -ForegroundColor DarkGray
    [void](Read-Host)
}
