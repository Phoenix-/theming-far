# 05 · Troubleshooting

Common ways things go sideways, and what to check.

## Theme doesn't appear in the Themes menu

The Themes menu lists **only** files in `Addons\Colors\Interface\`.
After copying and restarting Far:

1. **Is the file in `Program Files\Far Manager\Addons\Colors\Interface\`?**
   That's the only folder the menu scans. Files in `Default Highlighting\`
   or `Custom Highlighting\` never show up in the menu (they're for
   `-import`). Far does **not** read `%APPDATA%\Far Manager\Addons\Colors\`
   either — it must be the global install dir, which needs admin rights.
2. **Did you fully restart Far?** The Themes menu is built at startup.
   In-flight Far processes won't see new themes.
3. **File names with spaces or non-ASCII?** Usually fine in Far, but if
   nothing works, try a plain-ASCII filename to rule it out.

> You do **not** need matching files in all three folders for the theme to
> appear — only the `Interface\` file matters for the menu. (An earlier
> version of these docs claimed all three were required; that's wrong.)

## Theme appears but colors look wrong

1. **File-name colors (executables, archives) didn't change.** Expected:
   the Themes menu applies the interface palette **only**, never file
   highlighting. Apply the theme with `scripts/Import-Theme.ps1` (or
   `Far.exe -import` a combined farconfig) to get file coloring too. See
   [02-install.md](02-install.md).
2. **You pressed `Ctrl+R` and everything reset to bright console colors.**
   `Ctrl+R` in the file-highlighting dialog resets the predefined groups to
   Far's **indexed console defaults** (executables → light-green palette
   index 10, archives → magenta, temp → brown), *not* to your theme. Those
   are palette indices, so they render in your terminal's scheme colors, not
   your literal RGB. Re-import the theme to undo.
3. **Old colors persist after selecting the theme.** Some Far elements
   (Keybar, Clock, HMenu) cache their colors and only refresh on next
   restart. Exit Far completely, start again.
4. **Colors look "muddy" or "shifted".** Check that you used `flags="inherit"`
   (truecolor) and not `flags="fgindex bgindex inherit"` (palette index).
   Palette index mode resolves through the Windows console palette
   (`HKCU\Console`), not your literal RGB. Also make sure Far's **Virtual
   Terminal (VT) rendering is enabled** (Options → Interface settings) —
   without it Far approximates truecolor RGB to the nearest of 16 palette
   indices, so `#098658` shows up as a palette green instead.

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

## `Far.exe -import` doesn't seem to do anything

1. **Was Far running?** `-import` writes the SQLite config, but a running Far
   rewrites that config from its in-memory state on exit — silently discarding
   your import. **Close all Far instances before importing.**
   `scripts/Import-Theme.ps1` handles this (it waits for you to close Far).
2. **Build note.** `-import`/`-export` work on current Far (verified on
   **3.0.6699**). On the older 6666 build `-import` was reported to fail with
   `unknown argument`; if you hit that, use the GUI
   `F9 → Options → Configuration editor → Import` instead (applies all sections).

`-export` is the correct way to back up (Far closed, or it opens the GUI).

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
