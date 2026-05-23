<#
.SYNOPSIS
    Audit a Far Manager theme for low-contrast cells.

.DESCRIPTION
    Computes WCAG-style luminance contrast for every <object> in the
    <colors> section and reports cells with ratio < 3.0:1. The 3.0:1
    threshold is WCAG AA for "large text" - terminal cells aren't tiny,
    so 3:1 is a reasonable floor.

    Some cells are intentionally low-contrast and are excluded from the
    audit:
      * *.Disabled  - disabled UI elements (by design)
      * *.GrayText  - inactive items (by design)
      * *.Box       - subtle frame borders (by design)
      * *.DragText  - drag-preview ghosting (by design)
      * CustomColor* - generic palette slots, no fixed semantics
      * Cells where bg=fg (decorative spacers like Keybar.Background)
      * Cells using 0x80 scheme-default sentinel (resolved at runtime)

.PARAMETER Theme
    Path to a theme .farconfig file.

.PARAMETER Threshold
    Minimum acceptable contrast ratio. Default: 3.0.

.EXAMPLE
    .\audit-contrast.ps1 ..\themes\FarDark-2026\FarDark2026.farconfig

.EXAMPLE
    .\audit-contrast.ps1 ..\themes\FarLight-2026\FarLight2026.farconfig -Threshold 4.5
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Theme,

    [double]$Threshold = 3.0
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Theme)) { throw "Not found: $Theme" }

function Get-Luminance([string]$hex) {
    $hex = $hex -replace '^FF', ''
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255
    function Adjust($c) {
        if ($c -le 0.03928) { return $c / 12.92 }
        return [Math]::Pow(($c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * (Adjust $r) + 0.7152 * (Adjust $g) + 0.0722 * (Adjust $b)
}

function Get-Contrast($bg, $fg) {
    $l1 = Get-Luminance $bg
    $l2 = Get-Luminance $fg
    $hi = [Math]::Max($l1, $l2)
    $lo = [Math]::Min($l1, $l2)
    return ($hi + 0.05) / ($lo + 0.05)
}

$content = Get-Content $Theme -Raw
$rx = [regex]'<object name="([^"]+)"\s+background="(FF[0-9A-F]{6})"\s+foreground="(FF[0-9A-F]{6})"'

$results = @()
$skipped = 0
foreach ($m in $rx.Matches($content)) {
    $name = $m.Groups[1].Value
    $bg = $m.Groups[2].Value
    $fg = $m.Groups[3].Value

    # Decorative spacers (bg=fg by design)
    if ($bg -eq $fg) { $skipped++; continue }
    # Generic palette slots
    if ($name -like 'CustomColor*') { $skipped++; continue }
    # Intentionally low-contrast by semantics
    if ($name -like '*Disabled*' -or $name -like '*GrayText*' -or
        $name -like '*.Box' -or $name -like '*.DragText') {
        $skipped++
        continue
    }
    # 0x80 sentinel cells resolve at runtime through WinTerm scheme
    if ($bg -eq 'FF800000' -or $fg -eq 'FF800000') { $skipped++; continue }

    $ratio = [Math]::Round((Get-Contrast $bg $fg), 2)
    $results += [pscustomobject]@{
        Key   = $name
        BG    = "#$($bg.Substring(2))"
        FG    = "#$($fg.Substring(2))"
        Ratio = $ratio
        Pass  = $ratio -ge $Threshold
    }
}

$failing = $results | Where-Object { -not $_.Pass }
$passing = ($results | Where-Object Pass).Count

Write-Host "Theme: $Theme"
Write-Host "Threshold: $Threshold`:1"
Write-Host ""
Write-Host "Audited: $($results.Count) cells (skipped $skipped by-design / decorative)"
Write-Host "Passing: $passing" -ForegroundColor Green
if ($failing) {
    Write-Host "Failing: $($failing.Count)" -ForegroundColor Yellow
    Write-Host ""
    $failing | Sort-Object Ratio | Format-Table -AutoSize
    exit 1
}
else {
    Write-Host "Failing: 0" -ForegroundColor Green
    exit 0
}
