# Shop art: master prompt for ChatGPT (2026-11-22)

One prompt to paste into ChatGPT (which can read the repo). It makes every image the launch Shop still needs. Plan and context: [Shop Economy and Art v1](../../01%20Design/Shop%20Economy%20and%20Art%20v1.md) → Art brief v2. When the files are in `art-source/ui/shop/new/`, Claude uploads them and pastes the ids into `src/lobby/shared/ShopCatalog.luau` (`banner`, `PACK_ART`, `PACK_BACKDROP`) and the Ticket icon slot.

---

```
You are making the shop art for my Roblox game "Draft Duels" (a stylised, blocky, RIVALS-like duel shooter). You have access to the project's files. Make finished, professional game-store images. Do not change any code or any existing file; only add the new images listed below.

READ FIRST (for the look, don't copy text from them):
- vault/01 Design/Shop Economy and Art v1.md → sections "Art brief v2" and "Look pass 1: scheme A colours"
- vault/02 Art/Style Bible.md (the game's overall look)
- Look at these images: art-source/ui/shop/coin.png, art-source/ui/shop/pack_01_loose_coins.png … pack_06_vault_crate.png, art-source/ui/shop/crates/crate_standard_card.png, art-source/ui/shop/heroes/hero_ruinblighted.png, art-source/ui/shop/heroes/hero_tempeststrike.png, and the screenshots in vault/01 Design/Shop Economy/ (themeA_home.jpg, themeA_bundle_hover.jpg, themeA_daily.jpg, reward_popup.jpg).

THE SHOP'S LOOK (every image must sit well on it):
- Dark "night market" theme: page #17132A, panels #241D40, inner #2F2752, gold #FFC83D for coins and highlights, green #3FD45C for Robux prices.
- Stylised, clean, soft 3D shading, chunky readable shapes, slightly faceted (no smooth blobby "AI" look), crisp edges.
- NEVER: text, numbers, logos, watermarks, borders, frames, UI buttons, real-world brands, characters or people, guns (our own gun renders go on top in the game), heavy glow/bloom, neon, photo-realism, noise or grain.

MAKE THESE FILES. Save every one in art-source/ui/shop/new/ with exactly these names, as PNG. For each one, make 3 variations first, show them to me side by side, wait for my pick, then save the picked one at full size.

1) Coin packs — a matching set of six (transparent background)
   Use EXACTLY the coin design from art-source/ui/shop/coin.png (same star emblem, same rim, same warm gold #FFC83D with darker gold shading). All six share the same camera angle (slightly from above, front three-quarter), the same key light from the upper left and the same soft rim light, so they read as one set that grows in size. Transparent background, the subject centred and filling about 80% of the frame, nothing else, no shadow on the ground. 1024 x 1024.
   - pack_1.png: a small neat pile of about 8 coins
   - pack_2.png: a short stack with a few loose coins beside it
   - pack_3.png: two tall stacks with coins spilling over
   - pack_4.png: a chunky leather pouch overflowing with coins
   - pack_5.png: a small wooden treasure chest with dark metal bands, lid open, heaped with coins
   - pack_6.png: a big armoured vault crate, heavy door open, bursting with coins, a few coins flying out
   Make 1 and 6 first so the scale range is agreed, then 2–5 between them.

2) pack_backdrop.png — the coin pack cards' background, 1200 x 820, opaque
   A deep indigo (#241D40) to dark violet gradient, a soft warm gold light pool in the centre where the coin pile sits, faint angular light rays behind it, a little sparkle dust. Darker toward all edges (price and amount text sit in the corners). No objects.

3) banner_ruinblighted.png — 2560 x 840, opaque
   Background for the Ruin-Blighted skin bundle card. Overgrown ancient ruins at dusk: cracked dark stone with glowing teal-cyan (#3FE0D0) cracks like the skin (see hero_ruinblighted.png for its colours), creeping moss, drifting dust motes, a deep indigo (#17132A) sky. The LEFT two thirds calm and darker (a big gun picture and the title go there), the RIGHT third simple and dark (a grid of item tiles goes there). No weapons.

4) banner_tempeststrike.png — 2560 x 840, opaque
   Background for the Tempest-Strike skin bundle card. A storm front over a dark sea at night: deep royal blue (#2F5DB8) storm clouds over indigo, thin white-cyan lightning forks far away, wind-swept rain streaks (see hero_tempeststrike.png for its colours). Same layout rule: left two thirds calm and darker, right third simple. No weapons.

5) banner_starter.png — 2560 x 840, opaque
   Background for the Starter Bundle (also shown on the Home page's special offer card). A warm "welcome, new player" feeling: indigo (#241D40) backdrop with gold (#FFC83D) and green (#3FD45C) angular light panels and a few confetti-like sparkles, a soft spotlight on the RIGHT where a coin pile and two weapon cases will be placed by the game. Darker on the left for the title. No objects.

6) ticket.png — the "Ticket" currency icon, 1024 x 1024, transparent background
   A single gold admission ticket stub, chunky and slightly tilted, a notched tear edge on one side, a small embossed star-burst emblem in the middle, a thin darker gold border. Same rendering style, lighting and gold as coin.png so the two currencies look like a pair. Centred, nothing else, no shadow.

CHECK BEFORE SAVING EACH PICKED IMAGE:
- the exact file name and size above; transparent where it says transparent (real alpha, no white or checkerboard background); opaque where it says opaque
- no text or numbers anywhere, no guns, no characters
- banners: the left two thirds really are calm enough for white title text, and the right third is quiet
- coin packs: the six read as one set (same coin, same light, same angle) and clearly grow from 1 to 6

WHEN DONE: list the files you saved with one line each on what's in it, and say which ones you're least happy with.
```
