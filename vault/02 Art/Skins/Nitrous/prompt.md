# Prompts for ChatGPT: Nitrous

Keep one chat for Nitrous. Attach these files for the text-only direction check.

1. `art-source/weapons/ModelSheets/Vandal_model_sheet.png`
2. `refs/style/01_geometric-metal-lineup.png`
3. `refs/texture/02_metallic-colour-block-rifle.png`

---

## Prompt 1: direction check (text only)

```
I'm developing a reskin for my first-person shooter. The first attachment is my stock Vandal model sheet. The next two images are style and finish references.

Skin line: Nitrous. A high-energy metallic reskin with an abstract burst of electric blue and hot orange over black-painted metal and brushed silver.
Mood: loud, vibrant, high-energy, graphic.

What each reference is for:
- 01_geometric-metal-lineup.png: The broad diagonal shapes, clear colour hierarchy, and consistent energy across different gun shapes. Ignore the yellow and purple palette, exact polygon layouts, numerals, and background.
- 02_metallic-colour-block-rifle.png: The clean paint edges, contrast between painted panels and exposed silver, and how graphics meet fixed seams. Ignore the specific stripe placement, lettering, chevron texture, and background.

Preserve the stock silhouette, proportions and part positions. Keep the stylised low-poly forms, flat colour areas and clean edges. Use original surface graphics. Leave add-ons and charms out.
Carry broad, hard-edged geometric blocks from front to rear across Body and Panel. Use black as the dominant field, brushed silver as open space between clusters, and electric blue (#2367F2) as the main painted colour. Concentrate hot orange (#FF631F) at the burst and echo it in a few sharp, solid paint flecks. Keep the Grip and Dark roles near-black.
Where a shape crosses adjacent fixed panels, align the angle, width and colour across the seam. End shapes cleanly at moving or removable parts. Keep the same landmarks in the left, right, top and three-quarter views so the layout reads as one surface treatment.
Proposed signature: On the left receiver, a compact orange splash breaks into a few angular flecks between outward blue wedges and a brushed-silver cutout.
Avoid uneven paint edges, colour bleed, drifting shapes between views, broken alignment at fixed seams, noisy speckling, photoreal wear, small text, real brand logos and copied skin layouts.

Give me three text-only directions within this brief. For each, give a two-sentence description, hex colours and finishes for all nine roles, the scale and placement of the shapes and paint flecks, and a left-side signature detail. Explain how the shapes would align at fixed seams. Recommend one direction and explain why. Wait for approval before generating an image.
```

## Prompt 2: hero gun sheet

Use this once the direction and design notes are agreed.

```
Go with direction:
Changes:

Proposed colours per role (apply the approved direction and changes above):
- Body: #15171D, satin (black-painted metal with blue and orange blocks).
- Panel: #BEC8D4, metal (brushed silver with selected painted blocks).
- Dark: #111216, matte (near-black magazine, pads and guards).
- Grip: #22252B, textured (charcoal-black with the stock grip texture).
- Metal: #596370, metal (satin gunmetal).
- Accent: #D1D9E2, metal (bright silver on existing controls).
- Neon: #3D9DFF, gloss (blue on existing thin strips and sight dots only).
- Brass: #A8844E, metal (stock brass).
- Glass: #16202C, gloss (stock scope glass).

Pattern: Carry broad, hard-edged geometric blocks from front to rear across Body and Panel. Use black as the dominant field, brushed silver as open space between clusters, and electric blue (#2367F2) as the main painted colour. Concentrate hot orange (#FF631F) at the burst and echo it in a few sharp, solid paint flecks. Keep the Grip and Dark roles near-black.
Signature detail: On the left receiver, a compact orange splash breaks into a few angular flecks between outward blue wedges and a brushed-silver cutout.
Alignment: Where a shape crosses adjacent fixed panels, align the angle, width and colour across the seam. End shapes cleanly at moving or removable parts. Keep the same landmarks in the left, right, top and three-quarter views so the layout reads as one surface treatment.
Add-on pieces and matching charm: none.
Avoid uneven paint edges, colour bleed, drifting shapes between views, broken alignment at fixed seams, noisy speckling, photoreal wear, small text, real brand logos and copied skin layouts. Leave custom animation and special visual effects out.

Make a Vandal model sheet matching the stock layout on a light grey background:
- Large front-left three-quarter view
- Left side, right side and top
- Detached magazine and round
- Close-ups of the rear sight and charm mount
- Nine swatches with role names and hex values, plus the blue and orange pattern colours

Preserve the stock silhouette, proportions and part positions. Keep the stylised low-poly forms, flat colour areas and clean edges. Check the seam alignment and colour boundaries across all views.
```

## Prompt 3: every other gun in the line

Attach the next gun's stock model sheet from `art-source/weapons/ModelSheets/`, then the approved Nitrous Vandal sheet from `out/`. This line covers all 17 guns and excludes Knife.

```
Continue the Nitrous line for the gun on the first sheet. Match the approved Nitrous Vandal's colours, material finishes and geometric paint style. Fit the orange burst, blue wedges and brushed-silver cutout to an existing player-facing Body or Panel face. Scale the shapes and flecks to the available surface, keeping enough black between clusters for a clear read.

Where a shape crosses adjacent fixed panels, align the angle, width and colour across the seam. End shapes cleanly at moving or removable parts. Keep the same landmarks in the left, right, top and three-quarter views so the layout reads as one surface treatment.
Preserve the stock silhouette, proportions and part positions. Keep the stylised low-poly forms, flat colour areas and clean edges. Leave add-ons, charms, custom animation and special visual effects out.

Make the same kind of sheet as the approved hero: front-left three-quarter view, left, right and top, applicable ammunition and feed details, rear sight or scope, charm mount and labelled swatches. Follow the stock sheet for the parts and detail panels this gun has.
```

## Asking for changes

Say what to change by role and view. For example:

```
Align the blue wedge across the fixed seam on the left Body face and move two orange flecks back from the edge. Carry the correction into the top and three-quarter views. Keep the other colour blocks and show the full sheet again.
```

Save the first hero sheet as `out/Vandal_v01.png`. For each other gun, use the name from its stock sheet followed by `_v01.png`. Increment the version for each revision and record the approved filename in `concept.md`.
