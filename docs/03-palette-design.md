# 03 · Designing a palette

Far's color model is **per-element**, not semantic. There's no
`editor.background` token that propagates everywhere — every key is its
own RGB pair, and you set each one explicitly. That's a lot of keys (162)
but it gives precise control once you map them out.

## The strategy: design a small palette, project it onto keys

You don't pick 162 colors. You pick **~12 semantic colors** (background,
text, accent, selection, ...), then **assign** each of the 162 keys to
one of those 12 from your palette. The keys are dumb pointers; the
intelligence is in the palette.

### Step 1 — define the semantic palette

For FarLight 2026 (inspired by VS Code Light Modern):

```
bg.editor       #FFFFFF   editor / panel background
bg.titlebar     #DDDDDD   top menu strip
bg.accent       #005FB8   status bar / accent (also fg.accent)
bg.selection    #ADD6FF   editor / input selection
bg.listsel      #0060C0   active list selection (slightly darker)
bg.hover        #E8E8E8   panel cursor row
bg.warn         #A1260D   warning dialog surface
bg.highlight    #FFE082   yellow accent (used inside warn)

fg.text         #3B3B3B   primary text
fg.subtle       #616161   labels, hints
fg.disabled     #A0A0A0   grayed out
fg.accent       #005FB8   hotkey letters, links
fg.white        #FFFFFF
fg.border       #E5E5E5   panel borders, scrollbars
```

13 colors. Everything in the theme reuses these.

### Step 2 — group the 162 keys by Far's UI element

See [reference/far-3.0.6666-keys.txt](../reference/far-3.0.6666-keys.txt).
The groups are: `Clock`, `CommandLine`, `CustomColor`, `Dialog`, `Editor`,
`HMenu`, `Help`, `Keybar`, `Menu`, `Panel`, `Viewer`, `WarnDialog`.

Within each group, naming is consistent:
- `<Group>.Text` — normal cell
- `<Group>.Text.Selected` — same cell, selected
- `<Group>.Highlight` — hotkey-letter (the `&` character in Far menus)
- `<Group>.Highlight.Selected` — hotkey on selected item
- `<Group>.GrayText` — disabled
- `<Group>.Arrows` — scrollbar arrows
- `<Group>.Scrollbar` — scrollbar track
- `<Group>.Box` / `<Group>.Box.Title` — the border line and its label

Once you internalize this pattern, painting a new dialog group is just
mechanical assignment from the palette.

### Step 3 — assign keys to palette colors

Open [reference/theme-skeleton.farconfig](../reference/theme-skeleton.farconfig)
in your editor. The skeleton has all 162 keys preset to white-on-black —
work through them, changing colors in groups.

A worked example for the `Menu` group (drop-down menus):

```xml
<object name="Menu.Box"                background="FFFFFFFF" foreground="FF3B3B3B" flags="inherit"/>  <!-- bg.editor / fg.text -->
<object name="Menu.Box.Title"          background="FFFFFFFF" foreground="FF616161" flags="inherit"/>  <!-- bg.editor / fg.subtle -->
<object name="Menu.Text"               background="FFFFFFFF" foreground="FF3B3B3B" flags="inherit"/>  <!-- bg.editor / fg.text -->
<object name="Menu.Text.Selected"      background="FF0060C0" foreground="FFFFFFFF" flags="inherit"/>  <!-- bg.listsel / fg.white -->
<object name="Menu.Highlight"          background="FFFFFFFF" foreground="FF005FB8" flags="inherit"/>  <!-- bg.editor / fg.accent -->
<object name="Menu.Highlight.Selected" background="FF0060C0" foreground="FFADD6FF" flags="inherit"/>  <!-- bg.listsel / bg.selection -->
<object name="Menu.GrayText"           background="FFFFFFFF" foreground="FFA0A0A0" flags="inherit"/>  <!-- bg.editor / fg.disabled -->
<object name="Menu.GrayText.Selected"  background="FF0060C0" foreground="FFD0D0D0" flags="inherit"/>
<object name="Menu.Arrows"             background="FFFFFFFF" foreground="FF005FB8" flags="inherit"/>
<object name="Menu.Arrows.Selected"    background="FF0060C0" foreground="FFFFFFFF" flags="inherit"/>
<object name="Menu.Scrollbar"          background="FFE5E5E5" foreground="FF616161" flags="inherit"/>
```

The same mapping applies almost identically to `Dialog.List.*`, `Dialog.Combo.*`,
`Help.*`. Copy and adjust.

## Tricky bits

### Panel.Text.Selected — file marked with Insert

The classic Far choice is **bright yellow** (`#FFFF00`) for marked files.
On a white background, yellow is unreadable. We reuse the warning red
`#A1260D` here — it doubles as a single "important/dangerous" cue.

### Editor.Status / Viewer.Status — the status bar

Use the **accent color** (`#005FB8` + white text). It's the equivalent
of VS Code's blue status bar. This is the only place where the accent
color covers a large area.

### WarnDialog.* — warning surfaces

Far inverts the surface on warnings (a different background color for
the whole dialog). On a light theme, use a saturated red (`#A1260D`)
with white text. Buttons on warnings invert again: button background
becomes light, foreground red.

### CustomColor0..15

These are 16 generic slots used by macros and plugins (LF, NetBox,
Colorer). They're not bound to specific elements. Populate them with
your palette colors so plugins don't render with leftover bright values
from a previously-installed theme.

### Hotkey/highlight letters

Far uses `&` in menu/button labels to mark the keyboard shortcut letter,
e.g. `&Copy` displays `<u>C</u>opy`. The `<Group>.Highlight` keys color
that letter. Make it your **accent color** so the hotkey jumps out.

## Contrast / readability checklist

Before declaring a theme done:

1. Open a long file in F4 editor — read a paragraph. Does it tire your
   eyes after 30 seconds?
2. Open Options (F9 → Options → Interface settings). Tab through the
   dialog with arrow keys — every focused field should be obviously
   focused.
3. Open a warn dialog (e.g. F8 to delete a file). Yes/No buttons must
   look different from each other; one is the default.
4. Hit `Ctrl-O` for the user screen. With Light themes — check that
   text from prior shell output is still legible against your CommandLine
   background. If you use the [scheme-default trick](04-acrylic-trick.md)
   for acrylic, your CommandLine paints with WinTerm's scheme background
   instead and that part is moot.
5. Mark a few files with Insert. They should be clearly distinct from
   non-marked, and from the cursor row.
