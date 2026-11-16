# UI Art Brief (ChatGPT)

Art for UI v1 ([UI Design](UI%20Design.md)) made with ChatGPT's image generation, 2026-11-03. The game swaps it in through `Config/Theme` and `Config/Mods` `icon`. Everything must be original: no Valorant, RIVALS or other game characters, logos or ability art.

## Where files go
`art-source/ui/chatgpt/icons/<Id>.png` and `art-source/ui/chatgpt/cards/<Id>.png`, with these ids:
Dash, Updraft, Molly, Firewall, Frost, Recon, HealOrb, Stim, Recall.

## The prompt sent to ChatGPT

> I'm making UI art for my Roblox shooter (this folder: GlitchedGauntletGame). The style is Valorant's clean tactical UI mixed with RIVALS' chunky, bright Roblox feel. Everything must be original, so no characters, logos or ability art from Valorant, RIVALS or any other game.
>
> **1. Ability icons (9).** One PNG each, 512×512, **transparent background**. A flat, solid **white** glyph (no colour, no gradient, no outline, no text), bold and simple enough to read at 40 px, centred with about 12% padding. All 9 share one consistent style: thick shapes, a few sharp angles, Valorant ability-icon feel.
> - Dash: a quick forward dash (speed streaks plus a forward chevron)
> - Updraft: a burst of wind launching straight up
> - Molly: an incendiary canister with a flame
> - Firewall: a curved wall of fire
> - Frost: an ice crystal burst that slows
> - Recon: a sensor dart with scan rings
> - HealOrb: a glowing orb with a plus
> - Stim: a beacon with an energy bolt
> - Recall: an anchor point with a return arrow
>
> **2. Ability card art (9).** One PNG each, **1024×768** (4:3), no text, no UI, no characters. A stylised, painterly game-key-art close-up of the ability's effect against a dark, moody, slightly blurred arena background, lit in the ability's colour, with the subject in the upper middle and the bottom third dark (text sits there):
> - Dash `#2BD9A8` teal, Updraft `#2BD9A8` teal, Molly `#FF7A3D` orange, Firewall `#C15CFF` purple-magenta with orange fire, Frost `#C15CFF` violet and icy blue, Recon `#4C8DFF` blue, HealOrb `#6BE36F` green, Stim `#FFC53D` yellow, Recall `#8E7CFF` violet.
>
> Save them as `art-source/ui/chatgpt/icons/<Name>.png` and `art-source/ui/chatgpt/cards/<Name>.png` (names: Dash, Updraft, Molly, Firewall, Frost, Recon, HealOrb, Stim, Recall). Do the icons first. If you can't save files, show them here and I'll download them.

## Result
Completed: all nine icons and nine cards saved under `art-source/ui/chatgpt/`, using the exact ability IDs above. Icons verified as 512x512 RGBA PNGs with pure white glyphs, transparent backgrounds and approximately 12% padding. Cards verified as 1024x768 PNGs. `art-source/ui/chatgpt/Preview.png` provides a contact sheet. Artwork only; Roblox asset upload and in-game wiring are separate steps.

**In game (2026-11-04):** `python tools/ui_chatgpt.py` made white 256 px icons and 760 × 600 card art (cut corner, bottom fade) in `art-source/ui/chatgpt/out/`; all 18 uploaded and wired: icons in `Config/Mods` `icon` (draft, HUD slots, kill feed), card art in `Config/Theme` `CARD_ART`. With art, a new-ability card shows the picture on top and its icon in a small badge in the corner (the big centred icon covered the picture's subject). Checked in a Studio draft:

![Draft with ChatGPT art](References/ui-v1/ingame-draft-chatgpt-art.jpg)

Note: ChatGPT's desktop app refused Claude's clicks (Windows UIPI, likely run as administrator), so the user pasted the prompt by hand.


## Card art v2 + the free pack (2026-11-17)
The owner: the v1 cards are "a bit too realistic", they "don't really fit the vibe"; they want a cooler, cleaner, less fancy look that shows what each power does without looking Roblox-blocky, plus cards for the three new Mods (Shock Dart, Flash, Roller).

**What changes from v1:**
- Painterly brushwork, detailed arena buildings and busy particles become clean cel-shaded graphic shapes on a plain dark gradient with a few angular hints.
- One hero subject per card, showing the power in action, readable at draft-card size.
- Colours now follow each power's in-game look (the fire, ice, scan and flash colours), not the old guesses.
- Our faceted shape language: angular, chunky, not cubes.
- The Flash and Roller cards come with their Blender renders attached (`art-source/abilities/FreePack/v01/renders/Flash_hero.png`, `Roller_front.png`) so the art matches the in-game models.
- Part 2 makes ChatGPT icons for the three new Mods (they use stand-ins today).

**Pipeline when the images come back:**
1. `art-source/ui/chatgpt/cards_v2/<Id>.png` and `icons/<Id>.png`.
2. `python tools/ui_chatgpt.py` (now 12 ids; it reads cards_v2 first) writes `out/`.
3. Upload with `tools/opencloud/upload_asset.py --type Decal` and resolve the image ids.
4. Wire them up: `Config/Theme CARD_ART` (draft cards, the match-end screen) and `Config/Mods` `icon` (draft, HUD slots, kill feed, status tray).

### The prompt (paste into ChatGPT, attaching the two renders)
> I'm remaking the ability card art for my Roblox shooter (GlitchedGauntletGame). The old cards were too painterly and realistic. I want a cleaner, cooler, more stylised set where each card clearly shows what the ability does. Everything must be original: no characters, logos or ability art from Valorant, RIVALS, Overwatch or any other game.
>
> STYLE (the same for all 12; they must look like one set)
> - Clean stylised game illustration: bold graphic shapes, crisp edges, cel-shading with 2-3 flat tones per surface, and one soft glow on the energy only. Think simplified modern hero-shooter splash art. Not painterly, not photoreal: no brush texture, film grain, tiny details or busy particle clouds.
> - Shapes are angular and faceted (cut corners, flat planes, sharp tapers), solid and chunky, but NOT Roblox-blocky: no plain cubes, studs or LEGO look.
> - One hero subject: the ability in action, big and readable, in the upper middle of the frame, seen at a dynamic 3/4 angle. It must still read when the card is shown small (about 190 x 150 px).
> - Background: simple and dark.
>   - A smooth gradient from charcoal at the bottom (#14181E) to slate at the top (#2A313B).
>   - A few faint, large angular shapes (a diagonal slash, a cut-corner panel, a floor line) to hint at an arena.
>   - No buildings, props, sky or detailed scenery.
> - Colour: neutral greys plus the ability's own colour (given below), which is the light source and the only saturated colour. The light comes from the effect itself, with a soft rim light on the shapes around it.
> - The bottom 35% of the image stays dark and empty, fading to #12151A; the card's text sits there.
> - No text, numbers, UI, frames, borders, people, hands, or weapons held by anyone.
> - Format: 1024 x 768 PNG (4:3).
>
> THE 12 CARDS (file name: what to show, then colour)
> 1. Dash: a sharp burst of speed racing across the floor from left to right. A long tapered wind streak shaped like an arrow, two or three fading after-image chevrons behind it, a few chunks of floor dust kicked up. Cool white with sky blue #5BC8FF.
> 2. Updraft: a tight spiralling column of wind blasting straight up from a small hexagonal launch ring on the floor, angular debris lifted inside it, motion lines going up. White with sky blue #5BC8FF.
> 3. Molly: a faceted metal fire canister (octagonal body, pull ring) tumbling onto the floor and bursting into a wide pool of stylised angular flame tongues. Orange #FF7A2E with a hot yellow core.
> 4. Firewall: a tall wall of stylised angular flame tongues running in a curve across the floor, blocking the view, a scorch line at its base. Orange-red #FF5A2E with hot yellow tips.
> 5. Frost: a canister shattering on the floor into a starburst of big faceted ice crystals, a frost ring spreading flat across the floor, a few ice shards in the air. Icy blue #7FD6FF and white.
> 6. Recon: a small sensor dart stuck at an angle in a wall, sending out a flat ring-shaped scan pulse; behind the wall, two enemy positions show as red diamond markers. Cyan #2FD3E6, markers red #FF5A4E.
> 7. HealOrb: a floating glowing orb with a bright plus-shaped core, a slow ring of light around it and a few healing motes rising. Green #5EE09A.
> 8. Stim: a small beacon on the floor projecting a low glowing zone dome, with upward chevron arrows rising inside it (a speed boost) and a crackle of energy on the beacon's coil. Yellow #FFC83D.
> 9. Recall: a faceted anchor beacon planted on the floor, a glowing trail looping back to it like a rewind arrow, broken light fragments being pulled in. Violet #9B6BFF.
> 10. ShockDart: a bow bolt with a pronged, amber-tipped head hitting the floor, a lightning strike cracking down onto the impact, and jagged electric arcs crawling out across a flat ring on the floor. Electric blue #5EC4FF with amber #FFB547 tips.
> 11. Flash: a faceted flare canister with a gold lens bursting in mid-air into a blinding starburst, with a white-gold core and long light rays fanning out across the whole frame. Gold #FFF0B8 core, pale cool teal #BFE6D6 rays; the background stays dark. (The attached Flash_hero.png is the in-game canister; match its shape.)
> 12. Roller: a cheeky little bomb bot rolling fast toward the camera, about to blow. A faceted charcoal body slung between two big chunky wheels, two angry slanted glowing orange eyes, a yellow-and-black hazard stripe on its chin, a small antenna, sparks and a hint of fire trailing behind. Fire orange #FF6A1A and hazard yellow #FFC83D. (The attached Roller_front.png is the in-game bot; match its shape.)
>
> Save them as art-source/ui/chatgpt/cards_v2/<Name>.png, using exactly these names: Dash, Updraft, Molly, Firewall, Frost, Recon, HealOrb, Stim, Recall, ShockDart, Flash, Roller. Keep all 12 one consistent set: if one comes out more detailed or more realistic than the others, redo it to match.
>
> PART 2: three new icons, to match the existing nine in art-source/ui/chatgpt/icons/ exactly. Each is a 512 x 512 PNG with a transparent background and one flat, solid white glyph: no colour, no outline, no text, thick shapes with a few sharp angles, readable at 40 px, about 12% padding.
> - ShockDart: a bolt with a lightning zigzag beside its head.
> - Flash: a short canister bursting into a starburst.
> - Roller: a small two-wheeled bot with angry slanted eyes.
> Save them as art-source/ui/chatgpt/icons/<Name>.png (ShockDart, Flash, Roller).
>
> If you can't save files, show them here and I'll download them.
