# 02 · Installing a theme

Far Manager's "Themes" menu (`F9 → Options → Colors → Themes`) shows every
theme it finds at startup. To put your theme there, drop one or more
`.farconfig` files into Far's `Addons\Colors\` directory.

## What Far actually needs

Far recognizes **three** parallel sub-directories under `Addons\Colors\`,
one per theme aspect:

```
Addons\Colors\
  Interface\                   ← UI palette (Panel, Editor, Menu, ...)
    MyTheme.farconfig
  Default Highlighting\        ← file-panel coloring rules
    MyTheme.farconfig          (optional)
  Custom Highlighting\         ← extra file-coloring (rarely used)
    MyTheme.farconfig          (optional)
```

**Only the Interface file is required.** If you drop just an Interface
`.farconfig`, the theme will appear in the Themes menu and apply
correctly. Far falls back to the user's existing file-panel coloring,
which is usually the right behavior — most users have a custom
highlighting set up and don't want a theme to overwrite it.

Author your own **Default Highlighting** when you want file colors to
harmonize with the theme (e.g. directories blue on a Light background,
or yellow-ish on Dark). See the FarLight / FarDark themes in this repo —
each ships a `Highlighting.farconfig` alongside the Interface variants.

**Custom Highlighting** is for user-specific overrides (e.g. coloring
`*.test.ts` differently). Themes don't typically ship one.

Each `Addons\Colors\<sub-dir>` also has a **`Descript.ion`** file mapping
filename to a description shown in some Far dialogs. Adding a line is
polite but not required.

## Where is `Addons\Colors\` on disk?

On Far 3.0.6666 (tested):

- **`C:\Program Files\Far Manager\Addons\Colors\`** — works. This is the
  global install directory and Far scans it at startup.
- **`%APPDATA%\Far Manager\Addons\Colors\`** — does **not** work on
  3.0.6666. Some older builds picked this up; this one doesn't.

So installing a theme **requires Administrator rights** (write access to
`Program Files`). Easiest path:

- **`scripts/Install-AllThemes.ps1`** — run from a normal PowerShell. It
  detects the Far install via the Uninstall registry key, self-elevates
  (prefers Windows 11 24H2+ `sudo`; falls back to UAC `RunAs`), then
  copies every bundled theme + matching highlighting in one shot. Themes
  are passive; installing all variants is cheap.
- **`scripts/install-theme.ps1 <path>`** — for installing one specific
  variant. Has to be run from an already-elevated PowerShell.

Or just copy the files manually if you'd rather.

## After installing

1. **Restart Far completely.** The Themes menu is built at startup. If
   Far is open while you copy files, it won't see them.
2. Open `F9 → Options → Colors → Themes`. Your theme should appear in
   the list.
3. Select it. Far will ask which parts to apply (Interface / Default
   Highlighting / Custom Highlighting). If you don't want to overwrite
   your file-highlighting rules, untick those — apply only **Interface**.
4. Some elements (keybar, clock, top menu) cache their colors and only
   refresh on the next Far restart. If something looks half-applied,
   exit Far and start it again.

## Backing up before you change themes

```powershell
& "C:\Program Files\Far Manager\Far.exe" /export "$env:USERPROFILE\Desktop\my-old-far-colors.farconfig"
```

This writes your full current configuration (colors plus everything else)
to a single file. To roll back: import it through the Themes menu, or
delete `%APPDATA%\Far Manager\Profile\colors.db` while Far is closed —
Far rebuilds it with built-in defaults on next start.

## What about `Far.exe /import`?

`Far.exe /import <file>` exists in the command-line help but **fails on
3.0.6666** (`Error processing "/import": unknown argument`). Import is
GUI-only on this build:

- `F9 → Options → Colors → Themes` (theme menu), **or**
- `F9 → Options → Configuration editor → Import` (low-level config import).

## Per-user theme installs

If you don't have administrator rights and can't write to `Program Files`,
your options are:

- **Apply only.** Open `Configuration editor → Import` and point it at the
  `.farconfig` directly. Far loads it into the active configuration without
  needing the file on disk in `Addons\Colors\`. The theme won't appear in
  the Themes menu, but it will be applied.
- **Portable Far.** Far runs portably from any directory. If you can drop
  Far into `%LOCALAPPDATA%\Far Manager\` and use that copy, you control
  the `Addons\Colors\` directory inside it.
