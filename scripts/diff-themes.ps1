<#
.SYNOPSIS
    Diff two .farconfig themes by color key.

.DESCRIPTION
    Parses the <colors> section of both files and reports keys whose
    background, foreground, or flags differ. Useful when authoring a
    variant theme (e.g. comparing FarLight2026 to FarLight2026Acrylic).

    Also reports keys present in one file but missing from the other —
    handy for catching incomplete themes against the 162-key reference.

.PARAMETER A
    First .farconfig file.

.PARAMETER B
    Second .farconfig file.

.EXAMPLE
    .\diff-themes.ps1 ..\themes\FarLight-2026\FarLight2026.farconfig ..\themes\FarLight-2026\FarLight2026Acrylic.farconfig
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string]$A,
    [Parameter(Mandatory, Position = 1)] [string]$B
)

$ErrorActionPreference = 'Stop'

function Parse-Colors([string]$path) {
    if (-not (Test-Path $path)) { throw "Not found: $path" }
    $text = Get-Content $path -Raw
    $secMatch = [regex]::Match($text, '(?s)<colors>(.*?)</colors>')
    if (-not $secMatch.Success) { throw "No <colors> section in $path" }
    $body = $secMatch.Groups[1].Value

    $map = @{}
    $lineRx = [regex]'<object\s+([^/>]+)/>'
    $attrRx = [regex]'(\w+)="([^"]*)"'
    foreach ($lm in $lineRx.Matches($body)) {
        $attrs = @{}
        foreach ($am in $attrRx.Matches($lm.Groups[1].Value)) {
            $attrs[$am.Groups[1].Value] = $am.Groups[2].Value
        }
        if ($attrs.ContainsKey('name')) {
            $map[$attrs['name']] = [pscustomobject]@{
                bg    = $attrs['background']
                fg    = $attrs['foreground']
                flags = $attrs['flags']
            }
        }
    }
    return ,$map
}

$ma = Parse-Colors $A
$mb = Parse-Colors $B

$keys = (@($ma.Keys) + @($mb.Keys)) | Sort-Object -Unique
$onlyA = @(); $onlyB = @(); $diff = @()
foreach ($k in $keys) {
    if (-not $ma.ContainsKey($k)) { $onlyB += $k; continue }
    if (-not $mb.ContainsKey($k)) { $onlyA += $k; continue }
    $va = $ma[$k]; $vb = $mb[$k]
    if ($va.bg -ne $vb.bg -or $va.fg -ne $vb.fg -or $va.flags -ne $vb.flags) {
        $diff += [pscustomobject]@{
            Key      = $k
            A_bg     = $va.bg
            A_fg     = $va.fg
            A_flags  = $va.flags
            B_bg     = $vb.bg
            B_fg     = $vb.fg
            B_flags  = $vb.flags
        }
    }
}

Write-Host "A: $A  ($($ma.Count) keys)"
Write-Host "B: $B  ($($mb.Count) keys)"
Write-Host ""

if ($onlyA) {
    Write-Host "Only in A ($($onlyA.Count)):" -ForegroundColor Yellow
    $onlyA | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}
if ($onlyB) {
    Write-Host "Only in B ($($onlyB.Count)):" -ForegroundColor Yellow
    $onlyB | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}
if ($diff) {
    Write-Host "Differing keys ($($diff.Count)):" -ForegroundColor Cyan
    $diff | Format-Table -AutoSize
} else {
    Write-Host "No value differences." -ForegroundColor Green
}
