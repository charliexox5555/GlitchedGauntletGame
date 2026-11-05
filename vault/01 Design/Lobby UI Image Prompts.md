# Lobby UI Image Prompts

Images the lobby UI can use once made (ChatGPT image generation, core session). Nothing waits on them: the UI ships with vector placeholders ([Lobby UI and Queue](Lobby%20UI%20and%20Queue.md)). After upload, put each asset id where the "Goes in" column says. Style for all: **stylized and grounded, clean, bold readable shapes, no text, no logos, no real brands**; glitch only as a faint accent if at all.

## Icons (white on transparent, tinted in game)
Target **512 × 512 PNG, transparent background, pure white shape, no shading or gradients**, a 32 px safe margin, thick strokes (about 40 px at 512) so it reads at 38 px. Goes in: `src/lobby/client/Util/Icons.luau` → `ASSETS.<Name>`.

| Name | Prompt |
|---|---|
| Shop | "A single flat white icon of a shopping bag with two handles, bold rounded geometric shapes, thick even strokes, centred, transparent background, no text, game UI icon, 512x512" |
| Locker | "A single flat white icon of a tall two-door locker with small vents at the top and two handles, bold geometric shapes, thick even strokes, centred, transparent background, no text, game UI icon, 512x512" |
| BattlePass | "A single flat white icon of a shield-shaped badge with two stacked chevrons inside, bold geometric shapes, thick even strokes, centred, transparent background, no text, game UI icon, 512x512" |
| Range | "A single flat white icon of a round shooting target reticle with a centre dot and four tick marks, bold geometric shapes, thick even strokes, centred, transparent background, no text, game UI icon, 512x512" |
| Settings | "A single flat white icon of a gear cog with six teeth and a round hole, bold geometric shapes, centred, transparent background, no text, game UI icon, 512x512" |
| Coin | Full colour (not tinted): "A stylized gold game currency coin seen straight on, thick darker gold rim, an embossed diamond shape in the centre, soft bevel, clean cel-shaded highlights, transparent background, no text, 512x512" |

## Mode card art (Play menu)
Target **840 × 940 PNG** (the 420 × 470 card at 2×). Dark, low-contrast at the bottom (text sits on the lower half): **fade the bottom 55% to near-black `#181D26`**, leave the top-right clear of busy detail (the key chip sits there). Goes in: a new `MODE_ART` table in `QueueMenu.luau` (shown behind the wash, ImageTransparency about 0.2).

| Mode | Prompt |
|---|---|
| 1v1 | "Stylized grounded game key art, two armed silhouetted fighters facing each other across a clean modern arena, one lit cyan from the left, one lit orange-red from the right, bold simple shapes, smooth materials, saturated rim light, low-poly stylized like a hero shooter, dark background, bottom half fades to solid near-black #181D26, no text, vertical 840x940" |
| 2v2 | "Stylized grounded game key art, two pairs of fighters in a clean modern arena, the left pair rim-lit cyan, the right pair rim-lit orange-red, dynamic poses, bold simple shapes, smooth materials, low-poly stylized hero-shooter look, dark background, bottom half fades to solid near-black #181D26, no text, vertical 840x940" |
| 3v3 | "Stylized grounded game key art, two squads of three fighters charging toward each other in a clean modern arena, cyan rim light on the left squad, orange-red on the right, subtle purple atmosphere, bold simple shapes, low-poly stylized hero-shooter look, dark background, bottom half fades to solid near-black #181D26, no text, vertical 840x940" |

## Optional
- **Match Found band texture**, 1920 × 540 PNG: "Abstract dark horizontal banner background, subtle diagonal speed lines and a faint gold light streak through the centre, very dark navy #07090D, minimal, no text, 1920x540". Goes behind `LobbyMatchFound` → Band at ImageTransparency about 0.3.
