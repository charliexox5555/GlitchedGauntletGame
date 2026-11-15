# Prompts for ChatGPT: <Skin line name>

Fill every `<...>` from `concept.md`, then paste. Keep one chat per skin line so ChatGPT remembers the look.

**Attach, in this order, before pasting:**
1. the gun's model sheet: `art-source/weapons/ModelSheets/<Gun>_model_sheet.png`
2. the pictures from `refs/style/`
3. the pictures from `refs/texture/`

---

## Prompt 1: direction check (no picture yet)

```
I'm designing weapon skins for my own first-person shooter. The first image is the base model sheet of the <Gun>: every angle, its magazine, its round, its sights, its charm mount, and the nine colour roles with their hex values. The other images are references.

Skin line: <name>. <One line from concept.md.>
Mood: <mood words>.

What each reference is for:
- <file name>: take <...>, ignore <...>
- <file name>: take <...>, ignore <...>

Rules:
- The gun's shape does not change: same silhouette, proportions and part positions as the model sheet.
- A skin is colour, material and pattern on the nine roles (Body, Panel, Dark, Grip, Metal, Accent, Neon, Brass, Glass).
- Stylised low-poly with flat colour areas. No photoreal wear, no small text, no real brand logos.
- This must be an original design. Use the references for mood and level of finish only; do not copy any existing skin.

Before drawing anything, look at all the images and give me three different directions for this skin line. For each: a two-sentence description, the colour for each of the nine roles (hex), where the pattern goes, and the one signature detail. Then tell me which you would pick and why.
```

## Prompt 2: hero gun sheet

```
Go with direction <number>, with these changes: <changes, or "none">.

Colours per role:
- Body: <...>
- Panel: <...>
- Dark: <...>
- Grip: <...>
- Metal: <...>
- Accent: <...>
- Neon: <...>
- Brass: <keep the base colour>
- Glass: <keep the base colour>
Pattern: <where it goes and how big>.
Signature detail: <...>, on the left side (the side the player sees).
Add-on pieces: <none / what and where>. They must stay small: nothing in the rear sight window or on the line to the front post, nothing on the magazine or trigger, and the outline changes by no more than a tenth.
Do not: <list from concept.md>.

Now make the skin as a model sheet of the <Gun>, matching the base sheet's layout on a light grey background:
- large three-quarter view from the front left
- left side, right side and top
- the magazine out of the gun, and the round
- a close-up of the rear sight and of the charm mount
- a row of nine colour swatches labelled with the role names and hex values

Keep every part exactly where it is on the base sheet. Same stylised low-poly look, flat colour areas, clean edges.
```

## Prompt 3: every other gun in the line

Attach that gun's model sheet **and the approved hero sheet** from `out/`, then paste:

```
Same skin line, next gun. The first image is the base model sheet of the <Gun>. The second is the approved <hero gun> skin: match its colours per role, its finish and its pattern language exactly, so the two look like one set.

Carry the signature detail over in a way that fits this gun: <how, or "you choose and tell me where you put it">.
Keep this gun's shape and every part exactly as on its base sheet.

Make the same kind of model sheet as before: three-quarter front left, left, right, top, the magazine (or shells / cylinder / belt) and the round, the rear sight (or scope) and the charm mount, and the nine swatches.
```

## Asking for changes
Say what to change by role and by view, and what to keep:

```
Keep everything, but: make Panel one step darker, move the stripe so it stops before the magazine well, and remove the pattern from the stock. Show the full sheet again.
```

Save each result in `out/` as `<Gun>_v01.png`, `_v02.png`, and note the approved one in `concept.md`.
