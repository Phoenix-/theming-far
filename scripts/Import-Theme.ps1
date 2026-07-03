#Requires -Version 5.1
<#
.SYNOPSIS
    Apply a theming-far theme (interface palette + file highlighting) in one shot.

.DESCRIPTION
    Far Manager's built-in Themes menu (F9 -> Options -> Colors -> Themes) applies
    ONLY the interface palette (the <colors> section of a file in Addons\Colors\
    Interface\). It never applies file highlighting (the <highlight> section) — that
    is by design in Far's source (setcolor.cpp: apply_external_theme reads only
    "colors"). File highlighting can only be applied via Far's CLI config import,
    which pulls EVERY section present in the file (configdb.cpp:
    config_provider::Import).

    So this script:
      1. Lets you pick a theme (interactive arrow-key menu, or -Theme <name>).
      2. Builds a COMBINED farconfig in memory: the chosen variant's <colors>
         section + its family's <highlight> section, inside one <farconfig>.
      3. Runs `Far.exe -import <combined>` (Far must be closed) so BOTH the
         palette and the file coloring land in one action.

    The repo keeps colors and highlighting in SEPARATE files (themes\<Family>\
    <Variant>.farconfig + themes\<Family>\Highlighting.farconfig); the combined
    file is generated on the fly and deleted afterwards. No duplication.

.PARAMETER Theme
    Apply this variant non-interactively (e.g. 'FarLight2026Acrylic'). Skips the
    menu. Matching is case-insensitive.

.PARAMETER ThemesRoot
    Source themes directory. Defaults to ..\themes\ next to this script.

.PARAMETER FarRoot
    Override Far's install directory (else auto-detected).

.EXAMPLE
    .\Import-Theme.ps1
    # Interactive: pick a theme with Up/Down, Enter to apply, Esc to cancel.

.EXAMPLE
    .\Import-Theme.ps1 -Theme FarDark2026
    # Non-interactive: apply FarDark2026 directly.
#>
param(
    [string]$Theme,
    [string]$ThemesRoot = (Join-Path $PSScriptRoot '..\themes'),
    [string]$FarRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\_FarCommon.ps1"

# ---------------------------------------------------------------------------
# Discover themes
# ---------------------------------------------------------------------------

if (-not (Test-Path $ThemesRoot)) { throw "Themes directory not found: $ThemesRoot" }

# A "theme" = one interface-palette variant. Each family folder holds several
# variant .farconfig files plus a single shared Highlighting.farconfig.
function Get-Themes {
    param([string]$Root)
    foreach ($family in Get-ChildItem $Root -Directory | Sort-Object Name) {
        $highlight = Join-Path $family.FullName 'Highlighting.farconfig'
        $variants = Get-ChildItem $family.FullName -Filter '*.farconfig' |
                    Where-Object { $_.Name -ne 'Highlighting.farconfig' } |
                    Sort-Object Name
        foreach ($v in $variants) {
            [pscustomobject]@{
                Family        = $family.Name
                Name          = [IO.Path]::GetFileNameWithoutExtension($v.Name)
                InterfacePath = $v.FullName
                HighlightPath = if (Test-Path $highlight) { $highlight } else { $null }
            }
        }
    }
}

$themes = @(Get-Themes -Root $ThemesRoot)
if (-not $themes) { throw "No theme variants found under $ThemesRoot" }

# ---------------------------------------------------------------------------
# Combined-farconfig generation
# ---------------------------------------------------------------------------

function New-CombinedFarconfig {
    <#
        Merge a variant's <colors> file with its family's <highlight> file into
        one <farconfig> written to a temp path. Returns the temp path.

        We parse as XML rather than string-splice so malformed input fails loudly
        and namespaces/encoding are handled correctly. The interface file is the
        base (it carries <farconfig> + <colors>); we graft the <highlight> node in.
    #>
    param(
        [Parameter(Mandatory)][string]$InterfacePath,
        [string]$HighlightPath
    )

    [xml]$doc = Get-Content -LiteralPath $InterfacePath -Raw -Encoding UTF8
    if (-not $doc.farconfig) { throw "No <farconfig> root in $InterfacePath" }

    if ($HighlightPath) {
        [xml]$hl = Get-Content -LiteralPath $HighlightPath -Raw -Encoding UTF8
        $hlNode = $hl.farconfig.highlight
        if ($hlNode) {
            $imported = $doc.ImportNode($hlNode, $true)
            $null = $doc.farconfig.AppendChild($imported)
        }
        else {
            Write-Host "  (warning: no <highlight> in $HighlightPath — palette only)" -ForegroundColor Yellow
        }
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("theming-far-{0}.farconfig" -f [guid]::NewGuid())
    $doc.Save($tmp)
    return $tmp
}

# ---------------------------------------------------------------------------
# Interactive arrow-key menu (zero-dependency, PS 5.1 + 7)
# ---------------------------------------------------------------------------

function Show-ThemeMenu {
    <#
        Render $themes grouped by family with header rows, let the user move a
        highlight bar with Up/Down, Enter to select, Esc to cancel. Header rows
        are skipped during navigation. Returns the chosen theme object, or $null.

        Falls back to a numbered prompt when input is redirected (CI / pipe).
    #>
    param([array]$Items)

    # --- Build the display rows: header rows + selectable theme rows ---
    $rows = [System.Collections.Generic.List[object]]::new()
    $lastFamily = $null
    foreach ($t in $Items) {
        if ($t.Family -ne $lastFamily) {
            $rows.Add([pscustomobject]@{ IsHeader = $true;  Text = $t.Family; Theme = $null })
            $lastFamily = $t.Family
        }
        $rows.Add([pscustomobject]@{ IsHeader = $false; Text = $t.Name;   Theme = $t })
    }
    $selectable = @(0..($rows.Count - 1) | Where-Object { -not $rows[$_].IsHeader })

    # --- Non-interactive fallback ---
    if ([Console]::IsInputRedirected) {
        Write-Host 'Available themes:'
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $Items[$i].Name)
        }
        $ans = Read-Host 'Enter theme number'
        if ($ans -as [int] -and [int]$ans -ge 1 -and [int]$ans -le $Items.Count) {
            return $Items[[int]$ans - 1]
        }
        return $null
    }

    # --- Interactive render loop ---
    $cur = 0  # index into $selectable
    $startRow = [Console]::CursorTop
    $width = [Console]::WindowWidth

    $draw = {
        [Console]::SetCursorPosition(0, $startRow)
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $row = $rows[$i]
            if ($row.IsHeader) {
                $line = ("  {0}" -f $row.Text).PadRight($width - 1)
                Write-Host $line -ForegroundColor Cyan
            }
            else {
                $isSel = ($selectable[$cur] -eq $i)
                $marker = if ($isSel) { '>' } else { ' ' }
                $line = ("  {0} {1}" -f $marker, $row.Text).PadRight($width - 1)
                if ($isSel) {
                    Write-Host $line -ForegroundColor Black -BackgroundColor White
                }
                else {
                    Write-Host $line
                }
            }
        }
        Write-Host ''
        Write-Host '  Up/Down: move   Enter: apply   Esc: cancel' -ForegroundColor DarkGray
    }

    try {
        [Console]::CursorVisible = $false
        while ($true) {
            & $draw
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($cur -gt 0) { $cur-- } else { $cur = $selectable.Count - 1 } }
                'DownArrow' { if ($cur -lt $selectable.Count - 1) { $cur++ } else { $cur = 0 } }
                'Enter'     { return $rows[$selectable[$cur]].Theme }
                'Escape'    { return $null }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Resolve which theme to apply
if ($Theme) {
    $chosen = $themes | Where-Object { $_.Name -ieq $Theme } | Select-Object -First 1
    if (-not $chosen) {
        $names = ($themes.Name -join ', ')
        throw "Theme '$Theme' not found. Available: $names"
    }
}
else {
    $chosen = Show-ThemeMenu -Items $themes
    if (-not $chosen) {
        Write-Host 'Cancelled.' -ForegroundColor DarkGray
        return
    }
}

# Locate Far
$root = Find-FarRoot -Override $FarRoot
if (-not $root) { throw "Far Manager not found. Pass -FarRoot 'C:\path\to\Far Manager'." }
$farExe = Get-FarExe -FarRoot $root

# Far must be closed for the import to stick
if (-not (Wait-FarClosed)) {
    Write-Host 'Cancelled — Far still running.' -ForegroundColor DarkGray
    return
}

Write-Host ''
Write-Host "Applying theme: $($chosen.Name)" -ForegroundColor Cyan
Write-Host "  Far:       $farExe" -ForegroundColor DarkGray
Write-Host "  palette:   $($chosen.InterfacePath)" -ForegroundColor DarkGray
if ($chosen.HighlightPath) {
    Write-Host "  highlight: $($chosen.HighlightPath)" -ForegroundColor DarkGray
}

$combined = $null
try {
    $combined = New-CombinedFarconfig -InterfacePath $chosen.InterfacePath -HighlightPath $chosen.HighlightPath
    $p = Start-Process $farExe -ArgumentList '-import', "`"$combined`"" -PassThru -Wait -NoNewWindow
    if ($p.ExitCode -ne 0) {
        throw "Far import exited with code $($p.ExitCode)."
    }
}
finally {
    if ($combined -and (Test-Path $combined)) { Remove-Item $combined -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Done — palette and file highlighting applied for $($chosen.Name)." -ForegroundColor Green
Write-Host 'Start Far to see it. If colors look approximated to 16 palette entries,' -ForegroundColor DarkGray
Write-Host 'enable truecolor: Far -> Options -> Interface settings -> Virtual Terminal (VT).' -ForegroundColor DarkGray
