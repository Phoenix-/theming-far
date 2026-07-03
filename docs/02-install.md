# 02 · Installing a theme

A full theme has **two** independent parts, and Far applies them through
**two different mechanisms**. Getting this right is the whole trick:

| Part | farconfig section | How Far applies it |
|------|-------------------|--------------------|
| Interface palette (Panel, Editor, Menu, dialogs, …) | `<colors>` | Themes menu **or** `-import` |
| File-panel coloring (executables, archives, dirs, …) | `<highlight>` | **`-import` only** |

> **The Themes menu applies the interface palette ONLY.** It never applies
> file highlighting. This is confirmed in Far's source
> (`setcolor.cpp` → `apply_external_theme` reads only the `colors` node and
> feeds `palette::LoadTheme`; the highlighting folders are never read by the
> menu). So "pick a theme from the menu" changes your UI palette but leaves
> the file-name colors untouched.

To apply **both** in one action, use `-import` (see below), which pulls
every section present in the file (`configdb.cpp` →
`config_provider::Import`).

## The easy path: `Import-Theme.ps1`

```powershell
.\scripts\Import-Theme.ps1                          # interactive picker
.\scripts\Import-Theme.ps1 -Theme FarLight2026Acrylic   # direct
```

This generates a **combined** farconfig on the fly (the chosen variant's
`<colors>` + its family's `<highlight>`, in one `<farconfig>`) and runs
`Far.exe -import`. Result: palette **and** file coloring applied together.

- The interactive menu uses arrow keys (↑/↓), Enter to apply, Esc to cancel.
- **Far must be closed.** Importing while Far is open is silently discarded —
  Far rewrites its SQLite config from in-memory state on exit. The script
  detects a running Far and waits for you to close it (it never kills Far).
- The repo keeps colors and highlighting in **separate** files; the combined
  file is temporary and deleted afterward. No duplication.

## The Themes menu (palette only)

If you only want the interface palette to show up in
`F9 → Options → Colors → Themes`, drop the Interface `.farconfig` into:

```
C:\Program Files\Far Manager\Addons\Colors\Interface\
  MyTheme.farconfig            ← this is all the Themes menu reads
```

`scripts/Install-AllThemes.ps1` does this for every bundled variant (and
also copies the highlighting files into `Default Highlighting\` so they're
on disk for `-import`). Run it from a normal PowerShell — it self-elevates
(prefers Windows 11 24H2+ `sudo`, falls back to UAC `RunAs`) because
`Program Files` needs admin rights.

### About the three `Addons\Colors\` sub-folders

```
Addons\Colors\
  Interface\               ← UI palette; the ONLY folder the Themes menu reads
  Default Highlighting\    ← predefined file-coloring groups (for -import)
  Custom Highlighting\     ← extended/user file-coloring groups (for -import)
```

- The **Themes menu reads only `Interface\`.** `Default Highlighting\` and
  `Custom Highlighting\` are payloads for `-import`; the menu ignores them.
- **`Descript.ion` is irrelevant to the menu** — it's ordinary file-description
  metadata, never parsed when listing/applying themes. A theme not listed in
  `Descript.ion` still shows up and applies fine. (Verified in source.)
- There is **no dialog asking which sections to apply.** No such UI exists in
  mainline Far — not in the menu, not on `-import`.

## Where is `Addons\Colors\` on disk?

- **`C:\Program Files\Far Manager\Addons\Colors\`** — this is what Far scans.
  Requires Administrator rights to write.
- **`%APPDATA%\Far Manager\Addons\Colors\`** — not scanned; don't put themes
  there.

## `Far.exe -import` / `-export`

Both **work** on current Far (verified on build **3.0.6699**):

```powershell
& "C:\Program Files\Far Manager\Far.exe" -import "path\to\Theme.farconfig"
& "C:\Program Files\Far Manager\Far.exe" -export "$env:USERPROFILE\Desktop\backup.farconfig"
```

Single dash `-import` (double-slash `/import` is also accepted). **Close Far
first** for `-import` — otherwise the change is discarded on Far's exit, and
`-export` will open the GUI and hang instead of writing.

> Older note: on build 6666 `-import` was reported broken. It works on 6699.
> If you're on a build where it genuinely fails, fall back to
> `F9 → Options → Configuration editor → Import` (GUI, applies all sections).

## Backing up before you change themes

```powershell
& "C:\Program Files\Far Manager\Far.exe" -export "$env:USERPROFILE\Desktop\my-old-far-colors.farconfig"
```

This writes your full current configuration (colors, highlighting, and
everything else) to one file. To roll back: `-import` it (Far closed), or
delete `%APPDATA%\Far Manager\Profile\colors.db` / `highlight.db` while Far
is closed — Far rebuilds them with built-in defaults on next start.

> **Do not press `Ctrl+R` in the file-highlighting dialog** (Options → File
> highlighting) expecting it to load a theme. `Ctrl+R` resets the predefined
> groups to Far's **indexed console defaults** (executables → light-green
> palette index 10, etc.), not to any theme. It overwrites imported colors.

## Per-user installs without admin rights

- **Apply only, no menu entry.** `Far.exe -import <file>` (or
  `Configuration editor → Import`) loads a theme into the active config
  without the file living in `Program Files`. The theme won't appear in the
  Themes menu, but it's applied. Use a combined farconfig to get both palette
  and highlighting.
- **Portable Far.** Far runs portably; if you control the install directory,
  you control its `Addons\Colors\`.
