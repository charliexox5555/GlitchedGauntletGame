# Moltframe

**Round one · Line 1 of 6**  
**Status** · Draft brief and image prompt saved. Concept images follow the six line discussions.

## Identity

Futuristic insect armour made from an unnamed alien alloy. Three broad, curved plates fold over a recessed chamber of viscous violet fluid. The outer metal is cool and hard, with satin graphite faces and a bright, cold sheen on the folds. The goo is wet, glossy, and deep aubergine, with pale violet streaks drifting through it. Give the chamber one asymmetric slit under the player-facing shoulder so its movement reads in first person. Use broad plates, smooth inner shadows, and restrained seam detail to keep the silhouette clear.

The reference derives its organic look from insect shell layered like armour. For Gauntlet, use wide folded plates and a continuous fluid channel with an irregular outline. Develop new plate shapes, negative spaces, and accent placement. [Denis Lakhanov’s concept notes](https://lakhanov.artstation.com/projects/oAy2dq)

## Proposed roster and structure

| Item | Concept |
| --- | --- |
| Vandal · hero | Make the left receiver and handguard the main showpiece. Overlap broad shoulder plates toward the front and expose one elongated recessed channel below them. Keep the rear stock recognisable and let the finish carry the remaining surfaces. |
| Spectre | Use two compact crescent plates and one short, wide fluid window on the left. Let the existing suppressor silhouette read cleanly at a glance. |
| Ares | Use heavier segmented shoulder armour and a small visible fluid inlet on the body. Echo the folded edges as a static finish on the existing drum exterior. |
| Knife slot · Moltframe Dagger | A compact, slightly hooked dagger with a bright alloy edge, swept shell-shaped guard, dark grip, and one recessed violet insert. Reuse the stock Knife animations. Try the stock grip transform first and adjust the cosmetic hold offset if necessary. Check wrist alignment, knuckle clearance, and blade position in idle, swings, and inspect before considering any clip edits. |
| Shorty · optional | Add as a later compact study if one fluid window reads on the small receiver. |

Keep host weapon behavior, stock ADS alignment and zoom, reload and firing animations, grips, and animated part travel. Shape changes are exterior cosmetic work. Preserve the visual separation of moving parts and check shell clearance across the stock clips. Start with stock sights and show the first-person aim view so ornamentation can be checked against the sight window.

## Materials and visible details

These colours are draft concept swatches. Tune finish and contrast after viewing the hero under gameplay lighting.

| Role | Draft direction |
| --- | --- |
| Body | Blue-black alloy `#28313F`, broad satin metal faces |
| Panel | Cold slate `#515C70`, polished on the folded ridges |
| Dark | Deep graphite `#14171F`, matte |
| Grip | Charcoal `#222430`, soft matte texture |
| Metal | Cool silver `#A7B4CB`, selective bright edges and dagger bevel |
| Accent | Muted lilac alloy `#7C7290`, sparse fittings |
| Neon | Violet `#BA63F2`, limited to fluid highlights or existing tiny indicators |
| Brass | Smoke nickel `#63637A`, cosmetic exposed game cartridge or shell finish with a violet band `#934BD1` |
| Glass | Stock optic glass where applicable |
| Goo | Aubergine `#370E55` through violet `#7635AA`, with glossy lilac streaks |

**Ammunition.** Show a fictional smoke-nickel cartridge with a fine violet band and an on-theme spent casing. Keep the host ammunition profile and the stock reload, ejection, projectile, and hit behavior. The cosmetic change should be visible in the model sheet and during reload where the stock animation exposes the round. Keep stock tracer, muzzle and impact presentation.

**Buddy or charm.** Skip for the first draft. A tiny shed-shell fragment can be revisited once the mount system is ready. Let the main fluid window carry the identity on its own.

## Purple fluid motion

Use a slow seamless loop in one recessed window. Start with a deep-purple base, pass a soft lilac streak down the channel, then return to the resting pattern. The motion belongs to the material inside the chamber. The metal plates and the chamber outline stay still.

Prototype the window on the Vandal as a separate cosmetic insert. Keep the shell maps static. Test a scrolling `Texture` on a face-aligned insert if it fits the shape cleanly. Its offset can animate on a part face. Check the fit in Studio rather than assuming it follows curved UVs. If the face projection looks wrong, use the static marbled violet finish for the first build and retain the motion study as a follow-up. Compare under bright and dark lighting at normal first-person size. [Roblox animated texture documentation](https://create.roblox.com/docs/parts/textures-decals)

## Reference images

| File | Study |
| --- | --- |
| [01_hivemind-vandal.png](refs/style/01_hivemind-vandal.png) | The contrast of silver-edged plates against the glossy purple interior and its read along a long body. |
| [02_hivemind-dagger.png](refs/style/02_hivemind-dagger.png) | The relationship of the bright blade to the dark shell and violet handle details. |
| [03_hivemind-lineup.png](refs/style/03_hivemind-lineup.png) | How the surface language scales across long, compact, heavy, and melee silhouettes. |

## Draft image order

Once round-one planning is complete, start with the Vandal and use its approved shape and material treatment as the style anchor for the proposed supporting items. Include an ADS crop, cartridge and casing detail, and a three-frame material strip on the hero sheet. For the dagger, show the profile, grip-side view, and first-person idle and inspect poses. [Saved draft image prompt](prompt.md)
