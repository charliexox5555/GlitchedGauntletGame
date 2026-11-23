# Queue tile art: master prompt for ChatGPT (2026-11-22)

One prompt to paste into ChatGPT (which can read the repo). It makes the six Play menu tile pictures (Beginner 2v2, 1v1, 2v2, 3v3, 4v4, 5v5) in the RIVALS queue-menu idea (first person, enemies drawn solid red, a clean bright arena), drawn with our own guns, bodies and maps. This is phase 5 of [Handoff - Onboarding and Bots](../../05%20Production/Handoff%20-%20Onboarding%20and%20Bots.md). When the files are in `art-source/ui/queue/new/`, Claude uploads them, sets each tile's `Art` image in the Studio-built `PlayMenu` (and `ART` in `tools/studio/BuildLobbyMenus.luau`), and gives `PlayMenuController` each picture's real size (the crop code assumes 840 × 940 today).

Tile sizes in the menu (design px): Beginner 2v2 tall 360 × 644; 1v1 / 2v2 / 3v3 square 330 × 330; 4v4 / 5v5 wide 502 × 300. The game draws the mode name big in the middle of each tile, a "0 SEARCHING" line bottom-left and a key number top-left, so the pictures carry no text.

---

```
You are making the six queue-mode pictures for the Play menu of my Roblox game "Draft Duels" (a stylised, blocky, RIVALS-like duel shooter with first-person guns). You have access to the project's files. Make finished, professional game-menu images. Do not change any code or any existing file; only add the new images listed below.

THE IDEA (study RIVALS' menu, don't copy it):
Look at third-party/onboarding/rivals-queue-menu.webp. RIVALS shows each mode as a first-person moment: the player's blocky arms and gun in the foreground, and the enemies painted as flat, solid red silhouettes in a clean, bright, tiled arena, with more enemies for bigger modes; the tall "Beginner 2v2" tile is a big bright impact burst over a plain grid floor instead. We want that same readable recipe, but drawn with OUR guns, OUR blocky bodies and OUR arena, in our own colours. Do not reproduce their images, guns, characters, poses or layout one to one.

READ / LOOK AT FIRST (for the look; don't copy text from them):
- vault/02 Art/Style Bible.md (sections 1-4: readable first, tactical not cute, faceted not blobby, one accent at a time)
- Our guns (use these exact designs, nothing invented): art-source/ui/guns/*.png and the renders vault/02 Art/References/<gun>-blender-check.jpg (Sheriff, Vandal, Phantom, Operator, Odin, Judge, Bulldog, Marshal...). Guns are matte charcoal with a neutral base, small coloured details, chunky and faceted.
- Our arena: vault/02 Art/References/maps/arena/arena-v3-side-platform.jpg and arena-layout.png, and the tile texture art-source/maps/Arena/textures/arena_grid_tile.png (light grey 5-stud modules, two greys, a grid tile floor, plain walls, open sky). Another map for variety: vault/02 Art/References/maps/foundry4/build-overview.jpg.
- Our bodies: blocky Roblox R15 avatars (block arms, block legs, square heads), see art-source/ui/draft-duels/launch-art/draft-duels-avatar-studies.jpg.

THE PLAYER (foreground, every gun tile):
First person. The player's arms are sharp-edged block arms (RIVALS-style blocks, not thin, no visible fingers detail beyond simple block hands), wearing a dark charcoal sleeve with a small gold (#FFC83D) cuff stripe. The gun is held straight ahead, slightly right of centre, entering from the lower right, the way a first-person shooter shows it. Pistols are held with two hands.

THE ENEMIES (every gun tile):
Blocky R15 avatars holding guns, painted completely flat solid red (#E5262E, one tone, a slightly darker red #9E1A20 only where needed to separate overlapping limbs), no faces, no textures, no outlines, no glow. Readable silhouettes in clear poses: aiming, strafing, jumping, sliding. They stand on the floor with contact, nothing floating.

THE WORLD AND LIGHT (identical across the set):
A clean, bright arena from our Arena map: light grey modular walls and cover blocks with crisp chamfered edges, a grid-tiled floor, a pale blue sky with a few soft clouds. Soft daylight from the upper left, gentle ambient occlusion, a faint cool violet tint in the shadows. Stylised, clean, soft 3D render look (like a polished Roblox game render), crisp edges, no noise, no grain.

LAYOUT RULES (the game puts text on top):
- The MIDDLE band (about 30% to 70% of the height, centre 60% of the width) must stay calm enough for a big white mode title ("1V1") to read on it: enemies can sit behind it but keep it mid-toned, not busy, no bright highlights there.
- Bottom-left corner: quiet and darker (a small "0 SEARCHING" label sits there).
- Top-left corner: quiet (a small number chip sits there).
- The edges darken slightly (a soft vignette) so the tiles sit on the dark menu.

NEVER: text, numbers, letters, logos, watermarks, UI, crosshairs, health bars, borders or frames; real-world gun brands; photo-realism; cartoon "AI" look (rounded blobby forms, glossy plastic, plush toys); neon or heavy bloom; smooth round shapes on guns or bodies (everything is built from flat angled faces); blue-teal steel; any RIVALS asset, gun or character copied.

MAKE THESE FILES. Save every one in art-source/ui/queue/new/ with exactly these names, as opaque PNG (no transparency). Make queue_1v1.png FIRST and show me 3 variations side by side; wait for my pick; that pick fixes the arms, gun style, red, arena and light for the whole set. Then make the rest, 2 variations each, and wait for my pick before saving each one at full size.

1) queue_1v1.png — 1320 x 1320 (square)
   One red enemy at mid distance across an open lane, side-stepping behind a low grey cover block, gun raised. The player holds the Sheriff revolver (two hands), aimed at him. Tense, one-on-one.

2) queue_2v2.png — 1320 x 1320 (square)
   Two red enemies: one jumping across a gap, one peeking from a wall edge. The player holds the Vandal rifle; one thin white-gold bullet tracer streaks from the muzzle toward the jumping enemy with a small curved motion arc behind him. A partner's blocky arm or shoulder (charcoal sleeve, gold stripe) just visible at the left edge, so it reads as a team.

3) queue_3v3.png — 1320 x 1320 (square)
   Three red enemies spread across a wider arena space at different depths (one close behind cover, two farther back). The player holds the Operator sniper rifle, scope up, long barrel crossing the lower right.

4) queue_4v4.png — 2008 x 1200 (wide)
   Four red enemies pushing through a lane between grey walls, staggered at different distances, one sliding. The player holds the Odin heavy machine gun (a belt of rounds visible). Bigger, busier fight; keep the middle band readable.

5) queue_5v5.png — 2008 x 1200 (wide)
   Five red enemies in a wide open arena section with raised platforms, some on a ledge, one mid-jump. The player holds the Judge shotgun. The biggest crowd of the set, still clean silhouettes, not a blob.

6) queue_beginner.png — 1440 x 2576 (tall)
   No gun, no arms, no enemies. Looking down at the plain grey grid-tiled arena floor with a big painted "X"-shaped spawn mark (two crossed angular strips, slightly darker grey, no letters) in the lower third. Above it, in the upper-middle, a big bright impact burst: a white-hot core, sharp faceted shard rays and angular streaks in warm gold (#FFC83D) and white, a few hard-edged sparks flying out, a soft violet haze around it. It should feel like "your first hit", exciting and friendly, and read as the special, featured tile. Keep the very middle (where "BEGINNER 2V2" is written) a bit softer than the burst's core so white text stays readable; the bottom area (where a gold line of small text sits) calm.

CHECK BEFORE SAVING EACH PICKED IMAGE:
- exact file name and size above; opaque PNG
- no text, letters or numbers anywhere
- the guns match our real guns in art-source/ui/guns (shape and colours), the arms are block arms, the enemies are flat solid red blocky avatars
- the six look like one set: same red, same arms and sleeve, same arena and light
- shrink each image to its tile size (330 x 330, 502 x 300, 360 x 644) and check it still reads: the enemies' count and the gun are clear, and the middle band would carry white text

WHEN DONE: list the files you saved with one line each on what's in it, and say which ones you're least happy with.
```
