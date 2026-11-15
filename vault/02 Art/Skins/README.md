# Skins

How a skin line goes from an idea to concept sheets ChatGPT makes. One folder per skin line (a line is one look carried across several guns, like a bundle). Building the skin in Blender and Studio comes after a sheet is approved and is not covered here.

## Folder layout
```
vault/02 Art/Skins/
  README.md              this note
  _Template/             copy this folder, rename it to the skin line's name
    concept.md           the brief: what the line is, which guns, colours per role, references
    prompt.md            the prompts to paste into ChatGPT (fill the <...> parts from concept.md)
    refs/
      style/             pictures for the overall look (other games' skins, product photos, concept art)
      texture/           pictures for surfaces (materials, patterns, paint finishes)
    out/                 what ChatGPT returns: <Gun>_v01.png, <Gun>_v02.png ...
  <Skin line>/           e.g. Sunforge/, with the same four things inside
```
`refs/` is ignored by git on purpose: those are other people's pictures and the repo is public. Everything else can be committed.

## Steps for one skin line
1. Copy `_Template`, rename the copy to the line's name (no spaces is easiest: `Sunforge`, `NightMarket`).
2. Drop pictures into `refs/style` and `refs/texture`. Three to six in total is enough. Name them `01_matte-white-armour.png`, `02_orange-anodised-metal.png`: the name should say what the picture is for.
3. Fill in `concept.md`. The two parts that matter most are **the colour per role** table and **the references table** (one line per picture: what to take from it, and what to ignore).
4. Open `prompt.md`, fill the `<...>` parts from `concept.md`.
5. In ChatGPT, start with the **hero gun** (the Vandal, or whichever gun sells the line). Attach, in this order: that gun's model sheet from `art-source/weapons/ModelSheets/<Gun>_model_sheet.png`, then the reference pictures. Paste Prompt 1 (direction check), pick a direction, then Prompt 2 (hero sheet).
6. Save the result as `out/<Gun>_v01.png`. Ask for changes in the same chat and save each round as `_v02`, `_v03`. Write the approved version's file name in `concept.md`.
7. For every other gun in the line, in the same chat: attach that gun's model sheet **and the approved hero sheet**, paste Prompt 3. The hero sheet is what keeps the line consistent.
8. When a gun's sheet is approved, it is ready to be built (tell Claude the skin line and gun).

## Rules a skin has to follow (they are in the prompts too)
- **The shape does not change.** Same silhouette, proportions and part positions as the model sheet: sights, magazine, grip, charm mount, controls. The rig, the animations and the aim view depend on them.
- **A skin is paint and material on the nine colour roles** shown at the top of every model sheet: Body, Panel, Dark, Grip, Metal, Accent, Neon, Brass, Glass. Say what each role becomes. Patterns go on Body and Panel; Grip and Dark stay dark enough to read as grip and polymer.
- **Small add-on pieces are allowed, and only small ones:** a plate, a fin, a wrap, a badge. They must not sit in the rear sight window or on the line to the front post, must not touch the magazine or the trigger, and must not change the outline by more than about a tenth.
- **Stylised low-poly, flat colour areas.** No photoreal wear, no tiny text, no real brand logos.
- **The left side matters most.** It is the side the player sees in first person, so put the signature detail there.
- **Neon stays small:** thin strips and dots. It can change colour per line.
- **Our own designs.** References set the mood and the level of finish. Don't ask for a copy of a named skin from another game.

## What to give Claude afterwards
The skin line's folder name and which sheets are approved. Claude builds from `concept.md` (colours per role) and the approved `out/` sheets.
