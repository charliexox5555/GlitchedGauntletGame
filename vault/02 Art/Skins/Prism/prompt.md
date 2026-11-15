# Prompts for ChatGPT: Prism

Keep one chat for Prism. For Prompt 1, attach these files in order.

1. `art-source/weapons/ModelSheets/Vandal_model_sheet.png`
2. `refs/style/01_glossy-pink-rifle.png`
3. `refs/style/02_pink-black-lineup.png`
4. `refs/texture/03_pink-gloss-closeup.png`

---

## Prompt 1: direction check (no picture yet)

```
I'm designing weapon skins for my own first-person shooter. The first image is the base model sheet of my Vandal. It shows the weapon views, magazine, round, sights, charm mount and nine colour roles. The other images are style and finish references.

Skin line: Prism. A glassy black-and-pink reskin line that gives the stock guns and basic knife a polished prism finish.
Mood: slick, glossy, prismatic, clean.

What each reference is for:
- 01_glossy-pink-rifle.png: take broad glossy pink faces against dark functional parts. Ignore the exact colour breaks, orange trim, weapon geometry and background.
- 02_pink-black-lineup.png: take consistent pink-to-black balance across different weapon classes. Ignore the exact colour placements, silhouettes, promotional layout and background.
- 03_pink-gloss-closeup.png: take the sharp specular edge and contrast between glossy surfaces and dark polymer. Ignore the exact highlight shape, warm edge colours and surface layout.

Rules:
- Match the stock silhouette, proportions and part positions. Minor surface refinements may follow existing planes and bevels within the stock outline. Keep the sight picture and functional parts clear.
- Use a stylised low-poly look with flat colour areas and clean reflections. No add-on pieces, charm, custom animation or special effects.
- Use the references for mood and finish only. Keep the surface treatment original.
- Dull or muddy pink, busy decals, photoreal wear, small text on the weapon, real brand logos and copied skin layouts should stay out of the design.

Before drawing anything, give me three directions within the glassy black-and-pink brief. Start from glossy magenta Body, deep plum Panel and near-black Grip and Dark. For each direction, give a two-sentence description, hex colours and finishes for all nine roles (Body, Panel, Dark, Grip, Metal, Accent, Neon, Brass, Glass), where the colour blocks go and one left-side signature detail. Recommend one direction and explain your choice.
```

## Prompt 2: hero gun sheet

```
Go with direction:
Changes:

Proposed colours per role (apply my selected direction and changes above):
- Body: #C62878, gloss (saturated magenta).
- Panel: #541438, gloss (deep plum).
- Dark: #15141A, matte (near-black polymer).
- Grip: #211E27, textured (charcoal black).
- Metal: #3F3945, metal (satin gunmetal).
- Accent: #A6718C, metal (polished rose-tinted metal).
- Neon: #FF79B8, gloss (pink on existing thin strips and sight dots only).
- Brass: #A8844E, metal (base colour).
- Glass: #16202C, gloss (base colour).

Pattern: Carry the palette across each weapon in broad, part-sized colour blocks. Give Body large glossy magenta faces and Panel deep plum inset faces. Keep Grip and Dark near-black. Use the existing planes to break up the reflections. Use solid colour blocks with clean, stylised reflections.
Signature detail: One long, pale-pink specular highlight across the left Body face that breaks at an existing panel seam.
Add-on pieces and matching charm: none.
Do not include: dull or muddy pink, busy decals, photoreal wear, small text on the weapon, real brand logos and copied skin layouts, custom animations or special visual effects.

Make a Vandal model sheet matching the base sheet layout on a light grey background:
- Large three-quarter view from the front left
- Left side, right side and top
- The detached magazine and round
- Close-ups of the rear sight and charm mount
- Nine swatches labelled with the role names and hex values

Match the stock silhouette, proportions and part positions. Minor surface refinements may follow existing planes and bevels within the stock outline. Keep the sight picture and functional parts clear. Keep the stylised low-poly look, flat colour areas and clean edges.
```

## Prompt 3: every other weapon in the line

Attach the next weapon's base sheet from `art-source/weapons/ModelSheets/` first, then the approved Vandal sheet from `out/`. Use the weapon name in the base sheet filename to select the matching sheet.

```
Continue the Prism line for the weapon identified in the first image. The second image is the approved Prism Vandal sheet. Match its colours per role, material finishes and broad colour blocks. Carry the pale-pink reflection onto an existing player-facing Body plane and use an existing seam or change of plane to break the highlight.

Match the stock silhouette, proportions and part positions. Minor surface refinements may follow existing planes and bevels within the stock outline. Keep the sight picture and functional parts clear. Keep the stylised low-poly look. Use existing parts and materials for the reskin. Leave add-ons, charms, custom animations and special visual effects out.

Make the same kind of model sheet as before: front-left three-quarter view, left, right, top, detached magazine or applicable ammunition feed, round, rear sight or scope, charm mount and nine swatches. Follow the attached base sheet for which details exist.

For Knife, reskin the basic knife: carry the approved glossy colours onto the existing blade faces and use the approved near-black tones on the handle. Show the blade and handle in the base sheet views and omit gun-only detail panels. Label the colours used on the knife.
```

## Asking for changes

Say what to change by role and view. For example:

```
Make Panel one step darker and shorten the left-side Body highlight to end at the first panel seam. Keep the other colours, finishes and part positions. Show the full sheet again.
```

Save the first hero result as `out/Vandal_v01.png`. For other weapons, use the weapon name from the base sheet, followed by `_v01.png`. Increment the version for each revision and record the approved filename in `concept.md`.
