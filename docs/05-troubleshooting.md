# 05 · Troubleshooting

Common ways things go sideways, and what to check.

## Theme doesn't appear in the Themes menu

After copying the triplet and restarting Far:

1. **Did you put files in `Program Files\Far Manager\Addons\Colors\`?**
   Far 3.0.6666 does **not** read user-profile `%APPDATA%\Far Manager\Addons\Colors\`.
   The files must be in the global install directory. This requires
   Administrator rights.
2. **Are all three files present?** Each `.farconfig` must exist in
   `Interface\`, `Default Highlighting\`, and `Custom Highlighting\`
   sub-directories with the **same exact filename**. Missing one and
   the theme won't show up.
3. **Did you fully restart Far?** The Themes menu is built at startup.
   In-flight Far processes won't see new themes.
4. **File names with spaces or non-ASCII?** Usually fine in Far, but if
   nothing works, try a plain-ASCII filename to rule it out.

## Theme appears but colors look wrong

1. **Old colors persist after selecting the theme.** Some Far elements
   (Keybar, Clock, HMenu) cache their colors and only refresh on next
   restart. Exit Far completely, start again.
2. **Some colors apply, others don't.** When selecting a theme, Far asks
   which sections to apply (Interface / Default Highlighting / Custom
   Highlighting). If you accidentally unticked Interface, only file-
   panel highlighting changes.
3. **Colors look "muddy" or "shifted".** Check that you used `flags="inherit"`
   (truecolor) and not `flags="fgindex bgindex inherit"` (palette index).
   Palette index mode resolves through the Windows console palette
   (`HKCU\Console`), not your literal RGB.

## Acrylic doesn't show through

1. **WinTerm settings.** Verify `useAcrylic: true` (or `opacity: 70` etc.)
   in the active profile in `settings.json`. The Far profile may not
   inherit from `profiles.defaults` — set explicitly if unsure.
2. **Did you use `0x80` (scheme default), not palette index 0?**
   `background="FF000000" flags="bgindex inherit"` resolves to console
   palette index 0 (literal RGB from the host palette) and does **not**
   trigger acrylic. You need `background="FF800000" flags="bgindex inherit"` —
   that's the "scheme default" sentinel WinTerm applies acrylic to.
   See [04-acrylic-trick.md](04-acrylic-trick.md).
3. **Window not focused.** On Windows 11, acrylic is active-only —
   blur disappears when WinTerm loses focus. Click into the window to
   confirm.
4. **`opacity: 100`.** Acrylic requires opacity strictly less than 100,
   even with `useAcrylic: true`. Try `opacity: 70`.

## Far hangs / `colors.db` is locked

The configuration is a SQLite database in
`%APPDATA%\Far Manager\Profile\colors.db`. When Far is running, the file
is locked. To make external changes (manually swap themes, restore from
backup), close **all** Far instances first.

If Far won't start after a corrupt `colors.db`, delete the file while
Far is closed — Far recreates it with built-in defaults on next launch.
You lose only your color selections; other settings live in separate `.db`
files.

## `Far.exe /import` says "unknown argument"

`/import` was advertised in older builds but **doesn't exist in 3.0.6666**.
Use the GUI: `F9 → Options → Colors → Themes`, or
`F9 → Options → Configuration editor → Import`.

`/export` does work, and is the correct way to back up.

## Exported `.farconfig` has weird color values like `FF800000`

That's the "scheme default" sentinel
(see [04-acrylic-trick.md](04-acrylic-trick.md)) when the cell has a
`bgindex`/`fgindex` flag — Far paints with the host's scheme default
instead of a literal RGB. Without those flags, `FF800000` is just a
dark-red truecolor. Check `flags` to disambiguate.

## Listed colors don't match what I see on screen

Far's truecolor cells render exactly as written. But if you're using
indexed colors (`fgindex` / `bgindex`), the actual on-screen color
depends on:

1. **The Windows console palette** (`HKCU\Console` ColorTable00..15).
   You can inspect it with PowerShell:
   ```powershell
   0..15 | ForEach-Object {
     $v = Get-ItemProperty "HKCU:\Console" -Name "ColorTable$('{0:00}' -f $_)"
     $val = $v."ColorTable$('{0:00}' -f $_)"
     '{0,2}: #{1:X2}{2:X2}{3:X2}' -f $_, ($val -band 0xFF), (($val -shr 8) -band 0xFF), (($val -shr 16) -band 0xFF)
   }
   ```
2. **Windows Terminal's scheme** (if running inside WinTerm). WinTerm
   may override the console palette per-profile. Check
   `settings.json → profiles → list[].colorScheme`.

## I want to diff two themes

Use `scripts/diff-themes.ps1`:

```powershell
.\scripts\diff-themes.ps1 themes\FarLight-2026\FarLight2026.farconfig themes\FarLight-2026\FarLight2026Acrylic.farconfig
```

It compares the `<colors>` sections key-by-key and shows only differing
entries.
