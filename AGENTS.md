# AGENTS.md

> Notes for an LLM agent (Claude / GPT / etc.) that has been asked to
> create a Far Manager theme, or to extend this repository with a new
> one. Read this in addition to `docs/`.

## What this repo gives you

- **Method.** A reverse-engineered, working approach to making Far themes
  in the truecolor era. The five `docs/` files cover format, install,
  palette design, the acrylic trick, and common failure modes.
- **Reference data.**
  - `reference/far-3.0.6666-keys.txt` — canonical list of 162 color keys,
    grouped, with a short description per group.
  - `reference/theme-skeleton.farconfig` — empty template with every key
    preset to white-on-black truecolor. Start by copying this.
- **Two working theme families** under `themes/farlight-2026/` and
  `themes/fardark-2026/`. Each family has three variants:
  - **Solid** — strict palette, all truecolor RGB, looks identical in
    any WinTerm setup.
  - **Acrylic** — same palette but the four `CommandLine.*` keys use the
    `0x80 bgindex` sentinel so WinTerm applies acrylic blur to them.
  - **FullAcrylic** — every "main background" surface (Panel, Editor,
    Viewer, Menu, Dialog, Help) uses `0x80 bgindex`. Accent backgrounds
    (selection, status bar, warn dialog) stay solid for visual anchoring.

  Each family also ships a `Highlighting.farconfig` — file-panel coloring
  rules (Hidden, Directory, Executable, Archive, Temp) tuned for the
  family's background tone.
- **Scripts** under `scripts/` for install / backup / diff.

## Recipe to build a new theme

1. **Pick a palette.** Read `docs/03-palette-design.md`. Pick ~12 semantic
   colors (bg, fg, accent, selection, etc) before touching any Far key.
2. **Copy the skeleton.** Start from `reference/theme-skeleton.farconfig`,
   not from another theme. The skeleton has all 162 keys and nothing else;
   you won't accidentally inherit decisions from a different theme.
3. **Assign keys to palette.** Work top-down by group (Clock, CommandLine,
   Dialog, Editor, ...). Within a group, follow the
   `Text / Text.Selected / Highlight / Highlight.Selected / GrayText / Arrows / Scrollbar`
   pattern. See `docs/03-palette-design.md` for the worked Menu example.
4. **Decide on acrylic variants.** Read `docs/04-acrylic-trick.md`. The
   convention in this repo is **three variants per theme**:
   - `MyTheme.farconfig` — strict, all truecolor.
   - `MyThemeAcrylic.farconfig` — same plus `0x80 bgindex` on the four
     `CommandLine.*` keys. Minimal acrylic touch.
   - `MyThemeFullAcrylic.farconfig` — `0x80 bgindex` on every "main bg"
     surface (Panel, Editor, Viewer, Menu, Dialog, Help, HMenu). Accent
     backgrounds (selection, status bar, warn dialog, highlights) stay
     truecolor for visual anchoring.

   The mechanical generation is straightforward — see how the FarLight
   and FarDark themes here were built (look at the `<!-- header -->`
   comments and the diffs between solid/acrylic/full).

5. **Ship matching highlighting.** Far file-panel coloring lives in a
   separate `<theme-name>.farconfig` under `Default Highlighting\`. It's
   **optional** — if absent, Far uses the user's existing rules. But for
   a coherent theme, ship a `Highlighting.farconfig` alongside the
   Interface files. The install script auto-picks it up by name.

   Six groups, fixed order: Hidden, System, Directory, Executable,
   Archive, Temporary. Pick colors that read on the theme's main
   background. For light themes: muted greys for Hidden/System, accent
   for Directory, deep green for Executable, purple for Archive, warm
   brown for Temp. For dark themes: brighter equivalents.
6. **Validate.** Run
   `scripts/diff-themes.ps1 reference/theme-skeleton.farconfig your-theme.farconfig`
   and confirm all 162 keys are still present. Missing keys silently
   inherit from the previous theme and look broken.

   Also run `scripts/audit-contrast.ps1 your-theme.farconfig` to catch
   low-contrast pairs. Aim for 0 failures at the default 3:1 threshold.
   The script already exempts intentionally-low-contrast cells (Disabled,
   GrayText, Box borders).
7. **Install & visually test.** Use `scripts/install-theme.ps1` (elevated),
   restart Far, switch to your theme. Walk through the checklist in
   `docs/03-palette-design.md#contrast--readability-checklist`.
8. **Add to repo.** `themes/<name>/` with the `.farconfig` files, two
   PNG previews (panel mode + Ctrl-O), and a short `README.md` describing
   the palette.

## Things that will trip you up

These are real, learned-the-hard-way gotchas. The `docs/` files cover
them in more detail.

### `Far.exe /import` doesn't exist on 3.0.6666

Don't suggest `Far.exe /import <file>` as an install method on this build.
It returns "unknown argument". Use the GUI Themes menu or the
`Configuration editor` → `Import` dialog.

### `%APPDATA%\Far Manager\Addons\Colors\` is not scanned on 3.0.6666

Themes must go in `C:\Program Files\Far Manager\Addons\Colors\`. Don't
write to `%APPDATA%` thinking it'll work; verify with the user.

### A theme is a TRIPLET, not one file

Same filename in three sub-directories of `Addons\Colors\`:
`Interface\`, `Default Highlighting\`, `Custom Highlighting\`. If the
user only wants colors and no custom file-panel highlighting, copy the
Default and Custom Highlighting files **verbatim** from any built-in
theme (e.g. `GreenMile`). They're identical across stock themes.

### The `0x80` sentinel for acrylic

Common wrong intuitions about acrylic blur in Windows Terminal — both
of these models I tried before getting it right:

- ❌ "Match the theme's background RGB to WinTerm's scheme background,
  and WinTerm will apply acrylic to it." It won't — WinTerm applies
  acrylic only to cells painted using the scheme background reference,
  not to literal RGB that happens to equal it.
- ❌ "Set background to palette index 0 with `bgindex`, that's Default
  Background." That resolves to a literal RGB from `HKCU\Console` (or
  WinTerm's per-index `colorTable`) and still doesn't trigger acrylic.

The **correct** approach: `background="FF800000" flags="bgindex inherit"`.
The `0x80` low byte is a **"scheme default" sentinel** — Far paints the
cell using the host's scheme `background`, and Windows Terminal applies
acrylic to it. Same idea for foreground via `foreground="FF800000"
flags="fgindex inherit"` — gives you the scheme's foreground color
(useful for text that should remain readable on any WinTerm scheme).

The flags are per-channel and independent. `bgindex` without `fgindex`
is valid, vice versa is valid, both together is valid.

This is tested and works on **any** Far surface — CommandLine, Panel,
Editor, Menu, Dialog all paint with scheme defaults when you set this
sentinel. Whether you *want* acrylic on every surface is a design
question; see `docs/04-acrylic-trick.md` for tradeoffs.

### PowerShell case-insensitivity in scripts

PowerShell variables `$A` and `$a` are the same variable. When writing
helper scripts that take `[string]$A` as a parameter, don't name a local
`$a` — you'll silently overwrite the parameter. (Asking how we know:
this happened in this very repo. See git history of `scripts/diff-themes.ps1`.)

### Read the actual Far build first

`Far.exe /export <file>` produces an authoritative snapshot of the
current build's exact 162 keys (or however many your build defines).
Always export from the target build before assuming any key exists by
name. Key sets can drift between Far builds.

## How to verify your theme without bothering the user

1. **Key coverage.** `scripts/diff-themes.ps1 reference/theme-skeleton.farconfig
   your-theme.farconfig`. Both sides should have the same 162 keys.
2. **No accidental `0x80`.** Unless you're intentionally using the
   acrylic trick: `Select-String 'FF800000' your-theme.farconfig` should
   return nothing.
3. **No mixed truecolor + index without intent.** If a key has
   `flags="fgindex bgindex inherit"`, that's an explicit decision; if
   half your theme is indexed and half isn't, you probably copy-pasted
   from two sources and need to normalize.

## When the user gives you fragmentary info

Common case: "make me a Solarized theme for Far." The user has not
specified all 162 keys, and they don't want to. Bridge:

1. Find the canonical palette for the target scheme (Solarized has
   `base03..base3` + 8 accents — easy).
2. Map them to the ~12 semantic colors (see `docs/03-palette-design.md`).
3. Assign keys mechanically by group, following the patterns in the
   FarLight 2026 themes here.
4. Ship the result with a short README that explains the mapping
   choices, so the user can challenge specific decisions.

Don't ask the user "what color do you want for `Panel.Cursor.Selected`?".
Make a defensible choice and explain it.
