# 04 · Acrylic blur in Windows Terminal

If you run Far Manager inside **Windows Terminal** with `useAcrylic: true`
(or `opacity < 100`), you've probably noticed that the blur effect almost
never shows through Far. Far paints opaque cells edge-to-edge, so WinTerm
has nothing to blur.

There's a simple way to fix that, using Far's "default color" mode.

## TL;DR

For any region you want acrylic to show through, set `background` to
**`FF800000`** with `flags="bgindex inherit"`. Far will draw those cells
using **Windows Terminal's scheme `background`** instead of a literal
RGB color, and WinTerm applies acrylic to that color.

Example, applied to the command line and Ctrl-O user screen:

```xml
<object name="CommandLine"            background="FF800000" foreground="FF3B3B3B" flags="bgindex inherit"/>
<object name="CommandLine.Prefix"     background="FF800000" foreground="FF005FB8" flags="bgindex inherit"/>
<object name="CommandLine.Selected"   background="FF800000" foreground="FFADD6FF" flags="bgindex inherit"/>
<object name="CommandLine.UserScreen" background="FF800000" foreground="FF3B3B3B" flags="bgindex inherit"/>
```

The `0x80` low byte is a sentinel meaning **"use the scheme default color
for this channel"**. With the `bgindex` flag set, Far reads this as
"background channel: use scheme default" and renders the cell with the
WinTerm scheme's background color — the same color WinTerm applies
acrylic to.

`foreground` is left as truecolor RGB; the cell text renders in your
theme's color on top of the acrylic-blurred background.

## The mental model

Each Far color cell has two channels (foreground, background), and each
channel is encoded in one of two ways:

| Encoding | Flag present | Color value |
|---|---|---|
| Truecolor RGB | none | `FFRRGGBB` — literal 24-bit color |
| Console palette index | `fgindex` / `bgindex` | low byte: `00..0F` = palette index 0..15, `80` = scheme default |

The flags are **per-channel and independent**. You can set `bgindex`
without `fgindex` (or vice versa). The skeleton-theme bundled in this
repo uses neither, i.e. pure truecolor everywhere.

The `0x80` sentinel only does anything useful when its `*index` flag
is set, and the host (Windows Terminal here) actually has a "scheme
default" notion. Inside legacy `conhost.exe`, the same encoding falls
back to the `HKCU\Console\ColorTable*` values.

## What was tested

| `background` | `foreground` | `flags` | Acrylic? | Text color |
|---|---|---|---|---|
| `FF800000` | `FF3B3B3B` (literal RGB) | `bgindex inherit` | ✅ | theme's `#3B3B3B` |
| `FFFF11FF` (literal RGB) | `FF800000` | `fgindex inherit` | ❌ | WinTerm scheme fg |
| `FF800000` | `FF800000` | `fgindex bgindex inherit` | ✅ | WinTerm scheme fg |
| `FFFFFFFF` (literal RGB) | `FF3B3B3B` (literal RGB) | `inherit` | ❌ | theme's `#3B3B3B` |

Tested on Far Manager 3.0.6666 x64 inside Windows Terminal with
`useAcrylic: true, opacity: 53`, scheme "One Half Light".

Conclusions:
- Acrylic is enabled **per cell, on the background channel only**, and
  only when that channel uses the `bgindex + 0x80` encoding.
- The foreground encoding is independent — set it to whatever color you
  want the text to be.
- The trick works on **any Far surface**, not just command line. Panel,
  Editor, Viewer, dialogs all accept the encoding.

## How to enable it in the GUI

In Far, `F9 → Options → Colors`, pick any element, then in the color
dialog choose **● Default** as the background. Confirm. That's exactly
the same as writing `background="FF800000" flags="bgindex inherit"` in
the `.farconfig`.

## How to enable acrylic in Windows Terminal

In `settings.json`, on the relevant profile (or under `profiles.defaults`):

```jsonc
{
  "useAcrylic": true,
  "opacity": 70   // 0..100; anything < 100 enables transparency
}
```

Notes:
- On Windows 11, acrylic is **active-only** by default — blur disappears
  when WinTerm loses focus. That's WinTerm behavior.
- `opacity < 100` without `useAcrylic` gives plain alpha transparency
  without blur (cheaper to render, sometimes preferred).
- WinTerm applies acrylic to the **scheme** background color. If you set
  a per-profile `background` override, that wins instead.

## Design tradeoffs

Going fully acrylic across all surfaces sounds great but in practice:

- **Panels with `bg=scheme-default`** lose the visual separation between
  the two file panels (they share a background) and between Far and
  whatever else is on screen. The frame box becomes the only contour.
- **Editor with acrylic background** has noticeable blur ghosting when
  you scroll — text being drawn on top of a blurred shifting background
  is less pleasant for long reading sessions than a flat surface.
- **WarnDialog** must remain solid: warning surfaces need to be visually
  loud, and a translucent red looks neither dangerous nor readable.

The themes in this repo make different choices:

- [FarLight2026.farconfig](../themes/FarLight-2026/FarLight2026.farconfig)
  — fully solid. `bg=#FFFFFF` everywhere. Looks the same regardless of
  WinTerm settings.
- [FarLight2026Acrylic.farconfig](../themes/FarLight-2026/FarLight2026Acrylic.farconfig)
  — minimal acrylic, only on the four `CommandLine.*` keys. The keybar
  and panels stay opaque for stability.

If you want a fully transparent variant, copy the Acrylic theme and add
`background="FF800000" flags="bgindex inherit"` to as many keys as you
like. Watch the readability checklist in
[03-palette-design.md](03-palette-design.md#contrast--readability-checklist).
