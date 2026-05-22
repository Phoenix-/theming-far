# 01 · The `.farconfig` format

Far Manager themes are stored as **`.farconfig` files** — XML with a fixed
structure that Far parses internally. There is no published schema; the
format is documented here from reverse-engineering Far 3.0.6666 exports.

## Top-level structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<farconfig version="3.0">
    <colors>
        <!-- color objects go here -->
    </colors>
</farconfig>
```

A theme `.farconfig` only needs the `<colors>` section. Real Far exports also
include `<generalconfig>`, `<localconfig>`, `<highlight>` and others — Far
will silently ignore sections it doesn't expect, and import only what's there.

## A color object

Every UI element is a `<object>` line:

```xml
<object name="Editor.Text" background="FFFFFFFF" foreground="FF3B3B3B" flags="inherit"/>
```

| Attribute | Meaning |
|---|---|
| `name`       | Stable Far key, e.g. `Editor.Text`, `Panel.Cursor.Selected`. Far 3.0.6666 defines exactly **162 keys** — full list in [reference/far-3.0.6666-keys.txt](../reference/far-3.0.6666-keys.txt). |
| `background` | Background color, `AARRGGBB` hex. Alpha is **always `FF`** (Far doesn't use real transparency in color values). |
| `foreground` | Text color, `AARRGGBB`. |
| `flags`      | Render mode. See below. |

## The `flags` attribute

`flags` is a space-separated list. The two important words:

- **`inherit`** — almost always present; lets the cell inherit attributes from
  its parent context. Keep it.
- **`fgindex` / `bgindex`** — switch foreground/background from truecolor
  RGB to **palette index mode** (0..15 console palette + the special `0x80`
  marker — see [04-acrylic-trick.md](04-acrylic-trick.md)).

### Truecolor (recommended)

```xml
flags="inherit"
background="FFFFFFFF"   <!-- #FFFFFF white background -->
foreground="FF3B3B3B"   <!-- #3B3B3B dark gray text -->
```

This is what you want for a modern theme. Both color components are literal
24-bit RGB. Requires Far 3.0 build 5400 or newer.

### Palette index mode

```xml
flags="fgindex bgindex inherit"
background="FF000007"   <!-- index 7 = LightGray -->
foreground="FF000000"   <!-- index 0 = Black -->
```

When `bgindex` is present, only the **low byte** of `background` is read —
the rest must stay zero. Indices 0..15 map to the standard Windows console
palette. This is what legacy Far themes (GreenMile, VaxColors, etc.) use,
because they pre-date truecolor support.

The index palette is **not** Far's own — it comes from `HKCU\Console` (the
classic Windows console palette) or, when Far runs inside Windows Terminal,
from WinTerm's currently active color scheme.

### The `0x80` "scheme default" sentinel

Setting the low byte to `0x80` (e.g. `background="FF800000"`) **with
its `bgindex`/`fgindex` flag** is not an index into the 0..15 palette —
it's a sentinel meaning **"use the host's scheme default for this
channel"**.

- Inside legacy `conhost.exe`, the host's defaults come from
  `HKCU\Console` `ScreenColors` / `PopupColors`.
- Inside Windows Terminal, the host's defaults come from the active
  color scheme's `background` and `foreground`.

This matters because **Windows Terminal applies acrylic blur to scheme
background pixels**. Setting `background="FF800000" flags="bgindex inherit"`
on a Far cell makes that cell paint with the scheme background, which
WinTerm then blurs. See [04-acrylic-trick.md](04-acrylic-trick.md) for
the working theory and the experiments.

The same sentinel on the foreground channel (`foreground="FF800000"`
with `fgindex`) renders text in the scheme foreground color — useful
when you want a theme element to stay readable regardless of the user's
WinTerm scheme (light or dark).

In Far's GUI color editor, this sentinel is the **● Default** radio
button under "Text" or "Background".

## What's `version="3.0"` on `<farconfig>`?

The version attribute targets Far's own config schema, not your theme. Just
copy it verbatim — Far will reject files that lack it on some builds.

## Why no XSD/DTD?

There is none. Far parses `.farconfig` with a handwritten reader that
tolerates extra attributes and missing keys. Validators like VS Code's
XML extension will warn ("No grammar constraints") — ignore those.
