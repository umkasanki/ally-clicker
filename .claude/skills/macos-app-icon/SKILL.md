---
name: macos-app-icon
description: >
  Create a native-macOS-style app icon (squircle + gradient + glyph) and build the
  .icns, without any SVG rasterizer installed. Use when the user asks to design or
  regenerate an app/Dock/Launchpad icon "in the macOS style", make an .icns, or
  restyle an existing app icon. Renders via a small CoreGraphics Swift script (no
  rsvg/Inkscape/cairosvg needed), then sips + iconutil. Triggers: "иконка приложения",
  "app icon", "иконка для дока", ".icns", "нативный стиль иконок macOS".
---

# macOS app icon — design + build pipeline

Produces a Big-Sur-style icon: a rounded-square (squircle) tile with a vertical
gradient and a top sheen, plus a large centered glyph. Ships as `AppIcon.icns` in
the bundle. Works on a plain Mac — **no SVG rasterizer required** (we draw with
CoreGraphics, not by converting SVG).

## The look (design system)

- **Canvas** 1024×1024, transparent. The tile is inset ~96px on every side (body
  ≈ 832) so the icon has the standard breathing room next to native icons.
- **Squircle** rounded rect, corner radius ≈ 23% of the body (`rx = 46` in a
  200-unit design space).
- **Tile gradient** vertical, lighter top → darker bottom. Pick one hue; the
  AllyClicker example uses indigo `#A78BFA → #6D28D9`. Teal/blue/purple all read well.
- **Top sheen** a white overlay `rgba(255,255,255,0.35) → 0` over the upper half —
  gives the glassy Apple sheen.
- **Glyph** big, centered, white with a *subtle* vertical gradient
  (`#FFFFFF → #E2D9F5`) and a soft drop shadow (dy≈5, blur≈7, dark tint ~35%).
  Make it **plump/rounded** — draw the shape and stroke it with the *same* fill
  using `lineJoin/lineCap = round` and a fat stroke width; the round stroke both
  fattens and rounds the corners (envelope-like, à la macOS Mail).
- Optical centering beats mathematical: nudge the glyph a few % toward its visual
  mass. Iterate in small % steps with the user.

## Design space trick

Author in a 200×200, **y-down** space (matches SVG), then map onto the body:
`translate(inset, canvas-inset); scale(body/200, -body/200)`. Now the tile is
`0,0,200,200`, ring/glyph coordinates are small and readable, and it matches the
`.svg` source 1:1.

## Pipeline

1. **Design** an `AppIcon.svg` (source of truth, kept in `tools/`). Iterate the
   concept with the user as an inline SVG preview before building.
2. **Render** to `icon_1024.png` with a CoreGraphics Swift script that reproduces
   the SVG (see `tools/make-icon.swift` in this repo for a complete working example
   — squircle gradient, sheen, plump gradient cursor with shadow). Keep the SVG and
   the script in sync.
   ```bash
   swiftc make-icon.swift -o make-icon && ./make-icon icon_1024.png
   ```
3. **Build the .icns** with the stock tools (no Homebrew):
   ```bash
   mkdir AppIcon.iconset
   for s in 16 32 128 256 512; do
     sips -z $s $s icon_1024.png --out AppIcon.iconset/icon_${s}x${s}.png
     d=$((s*2)); sips -z $d $d icon_1024.png --out AppIcon.iconset/icon_${s}x${s}@2x.png
   done
   cp icon_1024.png AppIcon.iconset/icon_512x512@2x.png
   iconutil -c icns AppIcon.iconset -o AppIcon.icns
   ```
4. **Install**: put `AppIcon.icns` in the bundle's `Contents/Resources/` (or the
   source `Resources/` that the build copies) and set `CFBundleIconFile = AppIcon`
   in `Info.plist`.
5. **Refresh** if Finder shows a stale icon: `touch TheApp.app`, or
   `lsregister -f TheApp.app`
   (`/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister`).

## Xcode asset-catalog variant (no .icns)

If the app is an Xcode project, it uses `Assets.xcassets/AppIcon.appiconset/` instead
of an `.icns`. Render the 1024 master the same way, then `sips` it to the sizes the
set's `Contents.json` references and drop the PNGs in (filenames must match it):

```bash
ICO=Path/To/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  sips -z $s $s icon_1024.png --out "$ICO/AppIcon$s.png"
done
```

A macOS `Contents.json` maps these to 16/32/64/128/256/512 at 1x+2x (so 32/64/256/512/1024
double as the @2x entries). No `iconutil` — Xcode builds the icon from the set.
Real example: `ally-keyboard/tools/` + its `AppIcon.appiconset`.

## Gotchas

- **CoreGraphics gradient-filled glyph**: to fill a *stroked/plumped* shape with a
  gradient, build the fat outline via `path.copy(strokingWithWidth:lineCap:lineJoin:)`,
  then `addPath(original); addPath(fat); clip(using: .winding)` and draw the linear
  gradient. Do a first solid fill (with the shadow set) to cast the shadow, then the
  clipped gradient on top (shadow cleared).
- **Dock vs Applications**: a menu-bar app (`LSUIElement`/`setActivationPolicy(.accessory)`)
  shows **no Dock icon** but still appears in the Applications folder / Launchpad with
  this icon. To preview the icon in the Dock, temporarily set `.regular` — note
  `setActivationPolicy` in code **overrides** `Info.plist`'s `LSUIElement`.
- **No SVG→PNG CLI on stock macOS** — `qlmanage` is unreliable for SVG. Draw with
  CoreGraphics instead (this skill's approach). Only `sips` + `iconutil` are needed.

## Reference implementation

This repo's `tools/AppIcon.svg` + `tools/make-icon.swift` are a complete, working
example of the whole flow (AllyClicker's indigo cursor icon). Copy and adapt them.
