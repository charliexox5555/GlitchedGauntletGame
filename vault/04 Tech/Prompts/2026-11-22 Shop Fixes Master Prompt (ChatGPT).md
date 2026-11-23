# Shop fixes: master prompt for ChatGPT / Codex (2026-11-22)

The owner's six notes after the launch art went in, as one prompt for ChatGPT (it has the repo). Claude's audit before writing it:
- **Every gun has an image.** All 214 case skins (18 guns × 18 lines) and all 11 bundle skins (Ruin-Blighted 5, Tempest-Strike 6) have a portrait in `src/shared/ItemPortraits.luau` and a side icon in `src/shared/ItemIcons.luau`. Nothing is missing. The Thanksgiving bundle is a "soon" placeholder with no items, and it is hidden in the launch layout.
- **Why they look low quality:** the portraits are only about 230 px (side icons about 270 × 90). They are cut from one Studio screen capture holding a grid of many guns (`tools/studio/RenderPortraits.luau` → `tools/render/icon_sheet.py`), then shown 2–3× larger in the shop. The fix is to re-render them bigger from the real models, not to redraw them.
- **The Home featured card has no carousel code.** `Offer.Card.Dots` (Dot1–4) exist in Studio, but nothing drives them.

---

```
You are working on my Roblox game "Draft Duels" (repo open: Rojo + strict Luau). Read AGENTS.md first and follow it. Fix the six Shop issues below. Work on main, stage exact file paths only (never `git add -A` or `git add vault`), and commit each part separately with a clear message. Don't change prices, product ids, rewards or purchase rules, and don't touch any server purchase code.

CONTEXT (read only these sections, don't read whole big files):
- vault/01 Design/Shop Economy and Art v1.md → the last three sections ("Cases for Robux…", "Art brief v2", "Launch art wired in")
- vault/02 Art/Style Bible.md, and .claude/skills/gauntlet-ui-style/SKILL.md (UI look and motion rules)
- Code: src/lobby/client/Controllers/ShopController.luau (grep these: fillBundleCard, celebrate, celebrateProduct, buyStarter, offerCard, heroPic, drawLogin), src/lobby/shared/ShopCatalog.luau, src/lobby/client/Util/Fx.luau (pop, shine), src/shared/Config/UiSounds.luau (Reward* cues), src/shared/ItemPortraits.luau, src/shared/ItemIcons.luau, src/shared/SkinArt.luau
- Screenshots of the current shop: vault/01 Design/Shop Economy/art_*.jpg
- The Shop UI is built in Studio (StarterPlayer.StarterPlayerScripts.UI.Lobby.Shop). Don't build new screens from code. Short-lived effect pieces (sparkles, rays, flying copies) made and destroyed by a Util/Fx helper are fine.

RULES: `--!strict` in every file. Every tunable number (timings, counts, sizes, volumes) goes in a Config module under src/shared/Config (make Config/ShopFx.luau). Run `stylua src`, `selene src` and `rojo build -o build.rbxl`; all must pass. Never draw or AI-generate our guns: gun pictures must come from the real models.

1) STARTER BUNDLE PICTURE: show what's in it
   It gives 2 Standard cases + 1,500 coins + 3 Tickets, but the card only shows one old coin stack.
   Make art-source/ui/shop/new/starter_contents.png (1600 × 1000, transparent) by COMPOSITING our existing PNGs in Python/PIL. Don't redraw them:
   - two Standard cases: art-source/ui/shop/case_standard.png (or crates/crate_standard_card.png, whichever is cleaner), one behind the other, slightly overlapped
   - the coins: art-source/ui/shop/new/pack_3.png in front
   - three Tickets: art-source/ui/shop/new/ticket.png, fanned, in front corner
   Add a soft contact shadow under the group and keep the edges clean (real alpha, no halo). Show me the result and wait for my OK.
   Then upload it as a Decal (python tools/opencloud/upload_asset.py --group 11116787 --type Decal <file> "GG Shop starter_contents"). Get the image id (Studio: InsertService:LoadAsset(decalId) → the Decal's Texture). Add ShopCatalog.ART.starterContents and use it in ShopController wherever the Starter shows ShopCatalog.ART.coinStack: the Bundles Starter card Hero, Home's offer card Hero, and the YOU GOT popup for the Starter.

2 + 6) CHECK EVERY GUN AND LINE HAS ITS PICTURE
   Write tools/studio/AuditShopArt.luau (run in Studio Edit; reads only client-safe Shared modules). For every skin in SkinCases.all() and every bundle item in ShopCatalog.BUNDLES it checks for an ItemPortraits entry and an ItemIcons entry. It also checks that every bundle that isn't "soon" has hero + banner, and that the Starter has banner + ART.starterContents. It prints anything missing. (Claude's check on 2026-11-22 found nothing missing. Rerun it after part 5 and report.)
   If a NEW skin line has no "line icon" (the small emblem/tile shown for a whole line, see SkinArt.line), list it for me instead of guessing.

3) HOME: THE FEATURED CARD SCROLLS THROUGH OUR BUNDLES
   Home → SPECIAL OFFERS has one big card (Studio: …Home…Offer.Card with Art, Shade, Title, Sub, Price, Hero, Dots.Dot1–Dot4). The dots exist, but no code moves them.
   Make it a carousel over the featured bundles in this order: Starter, Ruin-Blighted, Tempest-Strike (ShopCatalog.BUNDLES, skip `soon` / empty ones, respect Config/Release.SHOP_FULL_LAYOUT).
   - Each slide sets the banner (Art), Title, Sub, Hero (bundle.hero; for the Starter ART.starterContents), the price plate, and OWNED when owned (reuse plateOwned / ownsAll).
   - Auto-advance every ~6 s (Config). Pause while the mouse is over the card. Clicking a dot jumps to that slide. On touch, a horizontal swipe changes slides; a tap opens it. Show only as many dots as slides and highlight the current one (same look as Dot1's "on" state).
   - Change slides with a short slide-and-fade (Quint out, no bouncy overshoot), about 0.35 s.
   - Clicking the card opens that bundle exactly like clicking its card on the Bundles tab (the Starter opens its confirm; the skin bundles open their bundle page).
   - Clean up connections and the timer when the shop closes.

4) MORE SATISFYING CLAIMS AND PURCHASES
   Today the YOU GOT popup (PopupCanvas.RewardPanel: Title, ItemName, Art, Close, Collect) pops the picture, plays one sweep and a tier stinger. Make it feel like a reward reveal:
   - The build-up (~0.4 s): the screen dims, the panel scales in, and a "whoosh" sound plays.
   - The reveal: a rarity-coloured flash behind the picture, slowly turning light rays behind it, a burst of 20–30 small sparkles/confetti (gold for coins and Tickets, the rarity colour for skins), and the tier stinger.
   - Coins: count the amount up quickly ("+1,500") with a soft coin-tick sound.
   - Bundles: each item's picture flies in one after another into a small row under the main picture, with a tick sound each and a bigger hit on the last one.
   - The Starter: the case, coins and Tickets appear one after another the same way.
   - The COLLECT button pulses gently until it's pressed. Pressing it plays a short confirm sound, and the items shrink toward the top bar (coins toward the coin counter).
   - Use the same popup for Daily login claims (today they only update the cell) and for the free daily skin.
   - Sounds: only Roblox-library or APM sounds we can use (same as the existing Reward* cues). Pick 2 or 3 choices for each new sound (whoosh, coin tick, item tick, final hit, collect), list their asset ids and names in Config/UiSounds as comments, and tell me which you picked so I can audition them. Keep volumes modest and never stack more than 3 sounds at once.
   - Every number goes in Config/ShopFx. Respect reduced motion if the game has a setting for it. Nothing may block buying again: the popup closes on COLLECT, X or a click outside.

5) HIGH-QUALITY GUN PICTURES
   The shop's gun portraits are about 230 px and the side icons about 270 px wide. They're shown 2–3× bigger, so they look soft. Re-render them from the REAL models at high resolution:
   - Pipeline: tools/studio/RenderPortraits.luau puts many guns in a grid of ViewportFrames and the screen is captured; tools/render/icon_sheet.py cuts the sheet (its --maxw flag sets the output width; the hero shots used 1600). The lists of what to render are tools/render/portrait-lists/*.txt.
   - Render far fewer guns per capture (2 × 2 or 3 × 2 per screen, gun filling its cell), so each picture comes out at least 768 px (portraits square 768–1024; side icons 1024 wide). Keep the same camera angles, lighting and framing as now so nothing else changes. Cut with --maxw 1024. Do the same for the side icons used by ItemIcons.
   - Upload as Decals (tools/opencloud/upload_asset.py, group 11116787), resolve each Decal to its image id, and replace the ids in src/shared/ItemPortraits.luau and src/shared/ItemIcons.luau. Keep the PNGs in art-source/ui/item-portraits/ and the item-icons folder (overwrite the old ones).
   - This needs Roblox Studio (place 71551303511506) open with the Studio MCP. If you can't drive Studio, don't fake it: make everything else ready (updated render script with the new grid and size, the batch lists, a single command list) and tell me, so I can hand that step to Claude.
   - Spot-check 10 pictures at full size (sharp edges, no grid lines or neighbours in the crop, real transparency) and show me a contact sheet before uploading all ~225.

TEST (Studio play, Lobby place) and report with screenshots: Home carousel (auto-advance, dots, hover pause, click opens the right bundle), the Starter card with its new picture, a Daily login claim, a free daily skin, and a fake Robux receipt for a bundle and a coin pack (ServerStorage.RobuxTestReceipt:Invoke(userId, productId)) showing the new popup. Check desktop and phone size (Studio device emulator) for cropping and readability. Run AuditShopArt and paste its output.

WHEN DONE: add a "Shop fixes round 2 (date)" section to vault/01 Design/Shop Economy and Art v1.md (what changed, the new asset ids, the sounds you picked, screenshots in vault/01 Design/Shop Economy/, what wasn't tested). Remind me to save the place in Studio. List your commits.
```
