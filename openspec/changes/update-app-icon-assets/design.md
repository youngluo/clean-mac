## Context

See `proposal.md` for the motivation and scope. The target is the approved green leaf artwork from the current design iteration. The project uses the `AppIcon` asset catalog for the application icon and `menubar-icon` as a separate template image; the Xcode project already points at `AppIcon`, so no build-setting or Swift change is needed.

The approved preview is a raster image without an alpha channel. Its rounded-square artwork must therefore be treated as a bounded foreground shape, with the four outside corners made transparent before producing the asset-catalog files. The approved raster is the visual source of truth; manually recreated leaf geometry is not acceptable because it changes the proportions and internal planes that the user selected.

## Goals / Non-Goals

**Goals:**

- Establish one canonical 1024 × 1024 PNG matching the approved warm-green background, white leaf, pale inner leaf plane, and green midrib exactly.
- Make pixels outside the rounded-square background transparent at every App Icon size.
- Produce consistent App Icon sizes according to the existing `Contents.json` mapping.
- Derive a simple black, transparent-background template leaf for the menu bar at 18 × 18 and 36 × 36.
- Keep the asset catalog self-contained and verifiable by Xcode and the Debug build.

**Non-Goals:**

- Do not change the approved leaf artwork, application behavior, Swift code, or build settings.
- Do not add another App Icon set or switch the target to `AppIcon-v2`.
- Do not introduce a runtime image-processing dependency.

## Decisions

1. **Use the approved raster as the canonical App Icon artwork.**

   Use the user-confirmed artwork directly for `icon_1024.png`, then derive the smaller App Icon sizes from that exact image. This preserves the selected leaf proportions, tip position, stem, inner pale plane, and background treatment without introducing a second interpretation of the design.

2. **Use explicit rounded-corner transparency.**

   The background shape will be drawn as a rounded rectangle inside the 1024 × 1024 canvas, leaving the outside of the path transparent. Each PNG will be generated from that master and checked at all four corners for zero alpha rather than relying on a black or visually similar background color.

3. **Preserve the existing asset-catalog size mapping.**

   Keep the current `Contents.json` entries and filenames. Generate the distinct files at 16, 32, 64, 128, 256, 512, and 1024 pixels; the existing 1x/2x entries continue to point to the appropriate files.

4. **Keep the menu bar resource monochrome and independent.**

   Derive a simplified, bold black leaf silhouette from the approved white leaf mask, on a transparent canvas, and keep `template-rendering-intent` set to `template`. Fit the visible silhouette to roughly 15–16 × 15–16 pixels on the 18 × 18 canvas, with a sufficiently thick body and a short vein cutout so it remains legible in the menu bar. Remove the old unassigned SVG source files so the asset catalog contains only the PNG resources it maps.

5. **Verify resources before building.**

   Check dimensions, alpha presence, and transparent corners for every generated PNG; validate the asset-catalog JSON; run the repository Debug build; then restart CleanMac with the latest build so the icon can be visually checked in the app and menu bar.

## Risks / Trade-offs

- [Small-size detail loss] → Keep the central midrib bold and simplify the menu bar silhouette; inspect the 16/18 px outputs explicitly.
- [Source/PNG drift] → Generate all PNGs from the approved 1024 px raster and avoid manually redrawing or separately editing individual sizes.
- [Anti-aliased corner pixels] → Apply the rounded-rectangle clip before rasterization and verify corner alpha is zero, not merely visually dark.
- [Approved preview differs from vector recreation] → Treat the approved preview as the visual reference and keep any vector simplification limited to geometry required for deterministic scaling.

## Migration Plan

1. Replace the App Icon PNG sizes using the approved raster and transparent-corner mask.
2. Regenerate the monochrome menu bar PNGs from the approved leaf mask and remove obsolete unassigned SVG sources.
3. Validate dimensions, alpha, JSON, and Debug build output.
4. If the visual result is unacceptable, restore the asset files from the pre-change Git state; no application code or persisted data is involved.

## Open Questions

None. The approved artwork, affected asset catalogs, and transparency requirement are defined.
