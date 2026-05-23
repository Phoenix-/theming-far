<#
.SYNOPSIS
    Install a Far Manager theme into Program Files\Far Manager\Addons\Colors\.

.DESCRIPTION
    Copies the Interface .farconfig into Addons\Colors\Interface\. Optionally
    also installs a Default Highlighting file (file-panel coloring rules).

    Highlighting handling:
      * If a 'Highlighting.farconfig' exists next to the Interface file,
        it is auto-installed under the same theme name into Default Highlighting\.
      * Otherwise, no highlighting is installed. Far falls back to the user's
        existing rules, which is usually what you want.
      * Override with -Highlighting <path> to use a specific file.
      * Pass -NoHighlighting to suppress auto-detection.

    Custom Highlighting is intentionally not installed: it's user-specific
    territory and most themes don't ship one.

    Far does NOT require a full triplet. Interface alone is enough for the
    theme to appear in F9 -> Options -> Colors -> Themes and apply correctly.

    Requires Administrator rights (write access to Program Files).

.PARAMETER InterfaceFile
    Path to the Interface .farconfig (the file with the <colors> section).
    The filename (without directory) becomes the theme name in Far's menu.

.PARAMETER Highlighting
    Optional path to a Default Highlighting .farconfig. If omitted, the
    script looks for a 'Highlighting.farconfig' next to InterfaceFile.

.PARAMETER NoHighlighting
    Skip the Highlighting install entirely (even if auto-detected).

.PARAMETER FarRoot
    Far installation directory. Default: C:\Program Files\Far Manager.

.EXAMPLE
    .\install-theme.ps1 ..\themes\FarLight-2026\FarLight2026.farconfig
    # Auto-detects ..\themes\FarLight-2026\Highlighting.farconfig and uses it.

.EXAMPLE
    .\install-theme.ps1 ..\themes\FarDark-2026\FarDark2026Acrylic.farconfig -NoHighlighting
    # Installs the interface, leaves existing file-panel coloring untouched.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$InterfaceFile,

    [string]$Highlighting,
    [switch]$NoHighlighting,

    [string]$FarRoot = 'C:\Program Files\Far Manager'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InterfaceFile)) { throw "Not found: $InterfaceFile" }
if (-not (Test-Path $FarRoot))       { throw "Far root not found: $FarRoot" }

$colorsRoot = Join-Path $FarRoot 'Addons\Colors'
$ifcDir     = Join-Path $colorsRoot 'Interface'
$defDir     = Join-Path $colorsRoot 'Default Highlighting'

foreach ($d in @($ifcDir, $defDir)) {
    if (-not (Test-Path $d)) { throw "Far theme dir missing: $d (broken Far install?)" }
}

$themeName    = [IO.Path]::GetFileName($InterfaceFile)
$themeFolder  = [IO.Path]::GetDirectoryName($InterfaceFile)

# Auto-detect highlighting if not specified
if (-not $Highlighting -and -not $NoHighlighting) {
    $auto = Join-Path $themeFolder 'Highlighting.farconfig'
    if (Test-Path $auto) { $Highlighting = $auto }
}

# Install Interface
try {
    Copy-Item $InterfaceFile (Join-Path $ifcDir $themeName) -Force
}
catch [System.UnauthorizedAccessException] {
    throw "Access denied writing to $colorsRoot. Re-run from an elevated PowerShell."
}
Write-Host "Installed interface:" -ForegroundColor Green
Write-Host "  $ifcDir\$themeName"

# Install Highlighting (if applicable)
if ($Highlighting -and -not $NoHighlighting) {
    if (-not (Test-Path $Highlighting)) { throw "Highlighting not found: $Highlighting" }
    Copy-Item $Highlighting (Join-Path $defDir $themeName) -Force
    Write-Host "Installed highlighting:" -ForegroundColor Green
    Write-Host "  $defDir\$themeName"
} else {
    Write-Host "No highlighting installed (using your existing file-panel coloring)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Restart Far, then: F9 -> Options -> Colors -> Themes"
