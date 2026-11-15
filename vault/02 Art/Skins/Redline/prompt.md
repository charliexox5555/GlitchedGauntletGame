# Prompts for ChatGPT: Redline

Keep one chat for Redline. Once the design notes are ready, attach the following files for the text-only direction check.

1. `art-source/weapons/ModelSheets/Phantom_model_sheet.png`
2. `refs/style/01_dark-crimson-lineup.png`
3. `refs/texture/02_subtle-blueprint-rifle.png`

---

## Prompt 1: direction check (text only)

```
I'm designing a reskin for my first-person shooter. The first attachment is my stock Phantom model sheet with the weapon views and colour roles. The next two attachments are style and texture references.

Skin line: Redline. A dark matte reskin that fades from charcoal into muted crimson, with fine surface grain and blueprint-style drafting lines.
Mood: industrial, restrained, technical, gritty.

What each reference is for:
- 01_dark-crimson-lineup.png: The balance of dark crimson shells and matte-black parts across several silhouettes. Ignore the exact colour placement, outlined edges, weapon shapes and promotional background.
- 02_subtle-blueprint-rifle.png: The low-contrast red drafting lines over a dark surface and the change in density across panels. Ignore the exact square grid, continuous red edge tracing and background grid.

Keep the stock silhouette, proportions and part positions. Apply the finish and markings as surface treatments within the existing part boundaries. Keep the look stylised and low-poly. Use the references for mood and finish and create original surface markings. Leave add-ons and charms out.

Run a broad charcoal-to-crimson gradient across most of the Body shell, with the darkest area toward the front and muted crimson toward the rear. Carry the colour shift into adjoining Panel faces in darker oxblood tones. Layer fine matte grain under sparse, broken drafting lines and short registration ticks on Body and Panel. Cluster the markings near selected seams and leave large clear areas so they read at first-person scale. Keep the magazine, grip and other Dark parts matte black.
Proposed signature: A thin muted-red drafting line on the left side takes one right-angle step at an existing panel break and ends in two short perpendicular ticks.
Avoid bright scarlet, glowing perimeter lines, a uniform grid, a flat recolour without drafting detail, busy markings, photoreal wear, tiny text, real brand logos, and copied skin layouts.

Give me three text-only directions within this brief. For each, give two sentences describing the look, hex values and finishes for all nine roles (Body, Panel, Dark, Grip, Metal, Accent, Neon, Brass, Glass), the gradient and line placement, and one left-side signature detail. Recommend one and explain why. Wait for approval before generating an image.
```

## Prompt 2: hero gun sheet

Use this when the direction and design notes have been agreed and you are ready to generate the first sheet.

```
Go with direction:
Changes:

Proposed colours per role (apply the approved direction and changes above):
- Body: #20191D to #741B2A, matte (charcoal-to-crimson gradient with fine dry grain).
- Panel: #33191F, textured (dark oxblood with a faint blueprint underprint).
- Dark: #141316, matte (near-black polymer).
- Grip: #1D1B1E, textured (charcoal with the stock grip texture).
- Metal: #333138, metal (dark gunmetal with subdued sheen).
- Accent: #4B4248, matte (smoked steel on existing controls).
- Neon: #A93D49, matte (muted red tint on existing tiny strips or dots at low intensity).
- Brass: #A8844E, metal (stock brass).
- Glass: #16202C, gloss (stock scope glass).

Pattern: Run a broad charcoal-to-crimson gradient across most of the Body shell, with the darkest area toward the front and muted crimson toward the rear. Carry the colour shift into adjoining Panel faces in darker oxblood tones. Layer fine matte grain under sparse, broken drafting lines and short registration ticks on Body and Panel. Cluster the markings near selected seams and leave large clear areas so they read at first-person scale. Keep the magazine, grip and other Dark parts matte black.
Signature detail: A thin muted-red drafting line on the left side takes one right-angle step at an existing panel break and ends in two short perpendicular ticks.
Add-on pieces and matching charm: none.
Avoid bright scarlet, glowing perimeter lines, a uniform grid, a flat recolour without drafting detail, busy markings, photoreal wear, tiny text, real brand logos, and copied skin layouts. Leave custom animation and special effects out.

Make a Phantom model sheet matching the stock sheet layout on a light grey background:
- Large front-left three-quarter view
- Left side, right side and top
- Detached magazine and round
- Rear sight and charm mount close-ups
- Nine labelled colour swatches with hex values, including both Body gradient endpoints

Keep the stock silhouette, proportions and part positions. Apply the finish and markings as surface treatments within the existing part boundaries. Keep the low-poly forms, clean edges and subtle matte surface grain.
```

## Prompt 3: every other weapon in the line

Attach the next weapon's stock model sheet from `art-source/weapons/ModelSheets/`, then the approved Redline Phantom sheet from `out/`.

```
Continue the Redline line for the weapon on the first sheet. Use the approved Phantom sheet for the role colours, matte finishes, gradient direction and blueprint markings. Place the stepped drafting line and paired ticks on an existing player-facing Body face. Scale the markings to each weapon and use its panel breaks to guide their placement.

Keep the stock silhouette, proportions and part positions. Apply the finish and markings as surface treatments within the existing part boundaries. Keep the stock grip texture and matte-black areas. Leave add-ons, charms, custom animations and special effects out.

Make a sheet with the front-left three-quarter view, left, right and top views, applicable ammunition or feed parts, rear sight or scope, charm mount and nine colour swatches. Follow the stock sheet for the parts and detail panels each weapon has.

For Knife: Apply the gradient and stepped drafting line to the player-facing blade face of the stock Knife, scaling the motif to fit. Keep the handle matte black and preserve the blade profile. Show the stock blade and handle views and label the colours used.
```

## Asking for changes

Say what to change by role and view. For example:

```
Deepen the rear Body gradient by one step and reduce the number of faint drafting lines on the left panel. Keep the stepped line, paired ticks and matte-black parts. Show the full sheet again.
```

Save the first hero sheet as `out/Phantom_v01.png`. For each other weapon, use its stock sheet name without `_model_sheet`, followed by `_v01.png`. Increment the version for each revision and record the approved filename in `concept.md`.
