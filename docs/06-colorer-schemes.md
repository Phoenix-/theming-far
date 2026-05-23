# 06 · Colorer schemes (F4 editor syntax highlighting)

Far Manager's built-in editor (F4) doesn't do syntax highlighting on its
own. That's the job of the **FarColorer** plugin, which ships with
modern Far Manager (3.0.3200+) out of the box.

This repo includes two Colorer schemes — one per theme family — so the
F4 editor matches your panel/interface theme.

## What's in a Colorer scheme

A Colorer scheme is a **`.hrd` file** (XML) that maps semantic tokens to
colors:

```xml
<assign name="def:Keyword"  fore="#0000FF" style="1"/>
<assign name="def:Comment"  fore="#008000"/>
<assign name="def:String"   fore="#A31515"/>
<assign name="def:Function" fore="#795E26"/>
...
```

~50 semantic keys cover the language-agnostic categories: text, numbers,
strings, comments, keywords (with sub-flavors: type-, class-, function-),
identifiers, tags, operators, errors, TODO, bracket matching, diff blocks.

The keys map closely to **TextMate / VS Code scopes**, so VS Code themes
can be ported one-to-one. The bundled schemes are direct ports of VS Code's
**Light Modern** and **Dark Modern** syntax palettes.

## How FarColorer discovers schemes

- The plugin reads its catalog from
  `Plugins\FarColorer\base\catalog.xml`.
- The catalog references the built-in console + RGB schemes via entities
  pointing into `common.zip`.
- It also accepts external `<hrd>` entries in the same `catalog.xml`,
  which is how this repo adds its schemes.

```xml
<hrd-sets>
    &catalog-console;
    &catalog-rgb;
    &catalog-text;
    <!-- theming-far:begin -->
    <hrd class="rgb" name="FarLight2026" description="FarLight2026 (theming-far)">
        <location link="hrd/rgb/FarLight2026.hrd"/>
    </hrd>
    <hrd class="rgb" name="FarDark2026" description="FarDark2026 (theming-far)">
        <location link="hrd/rgb/FarDark2026.hrd"/>
    </hrd>
    <!-- theming-far:end -->
</hrd-sets>
```

The `<!-- theming-far:begin/end -->` markers let the install script
re-patch the catalog idempotently without duplicating blocks. A one-time
backup of the original is kept at `catalog.xml.theming-far.bak` next to
the patched file.

## How to install

The bundled `scripts/Install-AllThemes.ps1` handles Colorer schemes
automatically — it copies the `.hrd` files into `Plugins\FarColorer\base\hrd\rgb\`
and patches `catalog.xml`. If FarColorer isn't installed, the script
silently skips this step.

## How to activate

After install + Far restart:

1. Open the F4 editor on any file (any source file works).
2. **F11 → FarColorer → Settings → Main settings** (Настройки → Основные настройки).
3. In the **Style settings** section:
   - Make sure **`[x] TrueMod Enable`** is ticked. This switches the
     plugin from the 16-color console palette to 24-bit RGB rendering —
     which is what our schemes target.
   - Find the **TrueMod color style** dropdown (just below the TrueMod
     checkbox) and pick **FarLight2026 (theming-far)** or
     **FarDark2026 (theming-far)**.
4. Confirm with **OK**. Colors update immediately and persist across Far
   sessions.

Note: there are **two** style dropdowns in this dialog:

- **Color style** — the 16-color console palette, used when TrueMod is
  off (e.g. in legacy `conhost.exe`). We don't ship a scheme here yet.
- **TrueMod color style** — the 24-bit RGB palette. This is the one our
  schemes register into. Make sure you change this one, not the other.

## How to write your own Colorer scheme

1. Copy [`reference/colorer-skeleton.hrd`](../reference/colorer-skeleton.hrd)
   (if present) or one of the bundled themes
   ([Light](../themes/FarLight-2026/Colorer.hrd),
    [Dark](../themes/FarDark-2026/Colorer.hrd))
   as a starting point. They have the full key set already.
2. Change the `fore=` / `back=` / `style=` attributes on each `<assign>`.
3. Save as `themes/<your-theme>/Colorer.hrd`. The install script will
   pick it up automatically based on filename.

### Style values

| `style="..."` | Meaning |
|---|---|
| `1` | Bold |
| `2` | Italic |
| `3` | Bold + italic |
| `4` | Underline |

Most keys leave `style` unset (regular weight).

### Key naming convention

The format is `<namespace>:<TokenName>`:

- `def:*` — built-in semantic tokens used by all parsers
- `diff:*` — git/diff-specific (added, removed, modified lines)
- `xml:*`, `c:*`, ... — language-specific overrides

You only need to set `def:*` and `diff:*` for a useful theme. Language-
specific keys override the corresponding `def:*` defaults if you want
extra polish on specific file types.

## Limitations

- **Editor only.** FarColorer doesn't apply to the F3 viewer (the
  plugin's README is explicit: "no API for F3").
- **Colors only.** FarColorer doesn't change the editor's frame, status
  bar, or scrollbar — those are governed by `Editor.*` keys in your
  `.farconfig` interface theme.
- **Restart required.** Switching HRD schemes inside FarColorer's GUI
  applies immediately, but installing a new `.hrd` (from a file) requires
  restarting Far so the plugin re-reads the catalog.

## Uninstall

If you want to remove our schemes:

1. Close Far.
2. Restore `Plugins\FarColorer\base\catalog.xml` from
   `catalog.xml.theming-far.bak` (the install script's one-time backup).
3. Delete `Plugins\FarColorer\base\hrd\rgb\FarLight2026.hrd` and
   `FarDark2026.hrd`.

Or, simpler: pick a different HRD scheme in FarColorer's GUI. Our
schemes stay registered but become inactive.
