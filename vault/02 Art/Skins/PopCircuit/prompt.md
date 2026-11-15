# Prompts for ChatGPT: PopCircuit

Keep one chat for PopCircuit. Attach these files for the text-only direction check.

1. `art-source/weapons/ModelSheets/Guardian_model_sheet.png`
2. `refs/style/01_pastel-metal-rifle.png`
3. `refs/style/02_neon-baseball-bat.png`
4. `refs/style/03_full-coverage-rifle.png`
5. `refs/texture/04_vinyl-on-metal-closeup.png`

## Prompt 1: direction check (text only)

```
I'm planning PopCircuit for my first-person shooter. The first attachment is my stock Guardian sheet. The other attachments are style and finish references.

Skin line: PopCircuit. An anime-pop finish with bright blue, pink and purple metallic colour blocks and original vinyl stickers.
Mood: playful, bright, bouncy, electric, glossy.

What each reference is for:
- 01_pastel-metal-rifle.png: Long blocks of pink, blue and violet with open space around a focal graphic. Ignore the character, lettering, exact sticker placement and promotional background.
- 02_neon-baseball-bat.png: The clear separation between a decorated barrel and dark wrapped handle, plus the small luminous accents. Ignore the exact cap and collar shapes, lettering, sticker artwork and full-length glow. The image shows the bat by itself.
- 03_full-coverage-rifle.png: How larger and smaller colour blocks carry the palette from front to rear. Ignore the character, brand graphics, exact artwork and pattern placement on the magazine and grip.
- 04_vinyl-on-metal-closeup.png: The contrast between glossy die-cut vinyl, clean sticker edges and tinted metal on compact faces. Ignore the portrait, lettering, barcodes and exact graphic shapes.

For the guns, preserve stock silhouettes, proportions and part positions. Keep the stylised low-poly look and clean colour boundaries.
Carry broad blue, pink and violet colour blocks along the full length of the gun, with glossy vinyl clusters on the widest Body and Panel faces. Use bubble rings, sparkles, halftone dots and comic speed marks for the anime-pop feel. Keep grips and other Dark parts in deep plum or indigo. Confine actual glow to small cyan strips and dots.
Use flat or gently curved faces for the main decals and keep their proportions consistent in every view. Align colour breaks across fixed seams and end stickers cleanly before moving or removable parts. Give the main sticker breathing room and use smaller decals to support it.
Proposed signature: A pink bubble bursting into three cyan sparkles, backed by a violet speed ring and finished with a pale die-cut border, sits on the player-facing left side.
Avoid anime characters or faces, warped or stretched stickers, drifting colour boundaries, mismatched seams, repetitive sticker clutter, tiny text, brand logos and copied graphics. Leave charms and add-ons out.

Give me three text-only directions. For each, describe the look in two sentences, give the hex colours and finishes for all nine roles, and explain the full-length colour placement, decal layout and left-side signature. Include a sentence on how the same stickers and colours would carry over to a stylised baseball bat for the melee slot. Recommend one direction and wait for approval before generating images.
```

## Prompt 2: hero gun sheet

Use this once the direction and design notes are agreed.

```
Go with direction:
Changes:

Proposed colours per role (apply the approved direction and changes above):
- Body: #539BFF, metal (satin electric-blue coated metal).
- Panel: #FF9DD8, metal (pearl pink with select violet blocks).
- Dark: #231B45, matte (deep indigo polymer).
- Grip: #29203C, textured (dark plum rubber with the stock grip texture).
- Metal: #6554C9, metal (satin violet anodised metal).
- Accent: #FF6ECA, metal (polished candy pink).
- Neon: #61F2FF, gloss (cyan on existing small strips and dots).
- Brass: #A8844E, metal (stock brass).
- Glass: #16202C, gloss (stock scope glass).

Pattern: Carry broad blue, pink and violet colour blocks along the full length of the gun, with glossy vinyl clusters on the widest Body and Panel faces. Use bubble rings, sparkles, halftone dots and comic speed marks for the anime-pop feel. Keep grips and other Dark parts in deep plum or indigo. Confine actual glow to small cyan strips and dots.
Signature detail: A pink bubble bursting into three cyan sparkles, backed by a violet speed ring and finished with a pale die-cut border, sits on the player-facing left side.
Decals: Use flat or gently curved faces for the main decals and keep their proportions consistent in every view. Align colour breaks across fixed seams and end stickers cleanly before moving or removable parts. Give the main sticker breathing room and use smaller decals to support it.
Avoid anime characters or faces, warped or stretched stickers, drifting colour boundaries, mismatched seams, repetitive sticker clutter, tiny text, brand logos and copied graphics. Leave add-ons, charms, custom gun animations and gun effects out.

Make a Guardian model sheet on a light grey background. Match the stock sheet with a large front-left three-quarter view, left, right and top views, detached magazine and round, rear sight and charm mount details, and nine labelled hex swatches.
For the guns, preserve stock silhouettes, proportions and part positions. Keep the stylised low-poly look and clean colour boundaries. Check that sticker shapes and colour boundaries agree across the views.
```

## Prompt 3: every other gun in the line

Attach the next gun's stock model sheet from `art-source/weapons/ModelSheets/`, then the approved PopCircuit Guardian sheet from `out/`. Use Prompt 4 for the melee slot.

```
Continue PopCircuit for the gun on the first sheet. Match the colours, metallic finishes and vinyl sticker style of the approved Guardian sheet. Adapt the bubble-burst sticker to a broad, player-facing Body or Panel face, with smaller sticker shapes spaced along the shell.
Use flat or gently curved faces for the main decals and keep their proportions consistent in every view. Align colour breaks across fixed seams and end stickers cleanly before moving or removable parts. Give the main sticker breathing room and use smaller decals to support it.
For the guns, preserve stock silhouettes, proportions and part positions. Keep the stylised low-poly look and clean colour boundaries. Avoid anime characters or faces, warped or stretched stickers, drifting colour boundaries, mismatched seams, repetitive sticker clutter, tiny text, brand logos and copied graphics. Leave add-ons, charms, custom gun animations and gun effects out.

Use the stock sheet layout with front-left three-quarter, left, right and top views, applicable ammunition and feed details, rear sight or scope, charm mount and labelled colour swatches.
```

## Prompt 4: PopCircuit Bat sheet

Use this once the bat design notes are agreed. Attach the approved PopCircuit Guardian sheet for the finish and `refs/style/02_neon-baseball-bat.png` for general styling.

```
Make a concept and first-person pose sheet for PopCircuit Bat, an original stylised baseball-bat model for my game's Knife slot. Use the approved Guardian for the colour and sticker style and the bat reference for broad prop styling. Create original geometry and decals. Avoid anime characters or faces, warped or stretched stickers, drifting colour boundaries, mismatched seams, repetitive sticker clutter, tiny text, brand logos and copied graphics.

The Knife slot gets an original stylised baseball bat with a rounded capped barrel, a tapered neck and a dark wrapped handle. Use the line's blue, pink and purple metallic finish, the bubble-burst sticker on the camera-facing barrel and a small cyan accent at the cap. Keep the grip clear of decals.
The current melee viewmodel is right-hand-led and positions the model from its grip. Propose a bat-specific primary grip pivot on the wrap near the knob, with a separate support-hand target on the same wrap toward the barrel. In first-person idle and light slashes the right hand stays anchored and the left rests low in frame. For the heavy pose, blend the left hand onto the support target before the downward animation, keep both hands attached through the motion, then return it to idle. Check wrist angles, hand spacing, clipping and centre-screen visibility with the actual rig.

Include left, right and three-quarter prop views, a grip close-up showing the proposed main and support hand anchors, and separate first-person pose thumbnails for idle, left slash, right slash, heavy and inspect. Keep the pose thumbnails and effect sketches separate from the turnaround.
- Primary (left click): Simple one-handed leftward and rightward slash clips, alternating on successive light inputs. Return to the same idle pose after each clip.
- Heavy (right click): Two-handed overhead-to-downward smash animation. The support hand joins before the downswing and releases during recovery.
- Inspect: A normal one-handed raise and turn to show the barrel and stickers, then settle back to idle.
- Light slash trail: A short blue, pink and violet ribbon follows the bat barrel during each light slash and fades by recovery.

Show the trail as a separate overlay for the two light slash poses. Use the same bat proportions, sticker placement and hand anchors across the sheet.
```

## Asking for changes

Specify the view, part and requested correction. For example:

```
Move the left Body sticker onto the flatter panel and keep its proportions consistent between the side and three-quarter views. Keep the palette and show the full sheet again.
```

Save the first hero sheet as `out/Guardian_v01.png` and the first melee sheet as `out/Bat_v01.png`. Use each other gun's stock sheet name with `_v01.png`. Increment the version for each revision and record the approved filename in `concept.md`.
