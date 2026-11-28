# Release 1: ChatGPT prompts (2026-11-27)

Prompts for the art release #1 still needs. The thumbnail history and ad results are in [Draft Duels Launch Art](Draft%20Duels%20Launch%20Art.md).
- **What the ads say (read before choosing):** the best thumbnail so far is `03_v10_gold_barrel_closeup_clean.png`, at **4.5% CTR over 21k impressions**: a Lobby-Gold fighter, a matte charcoal gun, a crimson glare and a red laser, a sunlit Arena, one clear focal point, no clutter.
- **What loses:** ability and draft-card thumbnails (0.6–1.4%) and added explosions or muzzle blasts (a 3.4% image fell to 0.9%).
- So the new ones build on the winner and change one thing: the Season 1 skins.

## The one-chat handoff (owner, 2026-11-28: "give me just the chat")
Open one new ChatGPT chat. **Attach these 7 files** (in this order), then paste the message below. ChatGPT makes the images one at a time; say "next" after each one you're happy with.
1. `art-source/ui/shop/new/starter_contents.png`
2. `art-source/ui/item-portraits/Bulldog_Payload.png`
3. `art-source/ui/shop/crates/crate_standard_card.png`
4. `art-source/ui/shop/boxes/box_strike.png`
5. `art-source/marketing/draft-duels/thumbnail-v10/exports/03_v10_gold_barrel_closeup_clean.png`
6. `art-source/ui/item-portraits/Vandal_Arcade_HD.png`
7. `art-source/ui/item-portraits/Vandal_Frostbite_HD.png`

```
I'm making launch art for my own Roblox shooter, Draft Duels. I've attached 7 images. Make 4 images for me, ONE AT A TIME, and wait for me to say "next" before starting the next one. Rules for all of them: every gun, case and box must match its attached image exactly (they are real in-game models: same shape, colours and details, never redesigned). Stylised, clean, crisp, high contrast, one clear focal point. No real brand logos, no extra effects, no explosions, no particles unless I ask.

IMAGE 1 - Starter Bundle shop art. Match image 1 exactly for canvas (1600x1000, transparent background), framing, camera angle, lighting and style. Replace its contents with: the gun in image 2 (the "Payload Lancer") large and angled across the middle as the hero; behind it, slightly smaller and overlapping a little, the case in image 3 and the box in image 4, upright; a small stack of the same gold coins as image 1 at the front corner. Soft studio light, a gentle gold rim light. No text.

IMAGE 2 - Season 1 thumbnail (1920x1080). Image 5 is my best-performing thumbnail. Remake it changing ONLY the gun: the fighter now holds the gun in image 6 (the "Arcade Havoc": purple arcade-cabinet rifle, neon edges, pixel screen, arcade buttons). Keep the same gold block fighter, pose, camera, forced-perspective barrel close-up, red laser, crimson glare, sunlit arena and uncluttered look. The gun's neon can glow softly. Add only "SEASON 1" small in the top-left corner, heavy white sans-serif with a slight dark shadow.

IMAGE 3 - the same as IMAGE 2 but with the gun in image 7 (the "Frostbite Havoc": faceted ice crystal over dark metal, cold blue-white glow). Swap the crimson glare for an icy blue-white glare; everything else identical to IMAGE 2.

IMAGE 4 - Starter Bundle icon, 512x512 square: the gun from image 2 large and centred on a dark violet-navy background with a soft gold rim light, the case and box small behind it. No text.
```

**Where each goes:**
1. Shop art: Claude uploads it and swaps `ShopCatalog.ART.starterContents`.
2. Thumbnail #1 for the Creator Dashboard and ads.
3. Thumbnail #2, to test against #2.
4. The Starter Bundle product icon. Claude uploads it with the new product description (Open Cloud needs the icon in the same call).

Put the finished files in `art-source/marketing/release1/` (or tell Claude where they are).

---

The single prompts below are the same jobs one at a time, kept for reference. For those: one chat per prompt, attach the files listed, in order, then paste.

---

## 1. Starter Bundle art (Shop: replaces `art-source/ui/shop/new/starter_contents.png`)
**Attach:**
1. `art-source/ui/shop/new/starter_contents.png` (the old art: match its size, framing and style)
2. `art-source/ui/item-portraits/Bulldog_Payload.png` (the Payload Lancer)
3. `art-source/ui/shop/crates/crate_standard_card.png` (the Standard Case)
4. `art-source/ui/shop/boxes/box_strike.png` (the Strike Box)

```
This is shop art for my own Roblox shooter. Image 1 is our current Starter Bundle picture: keep its exact canvas size, framing, camera angle, lighting and clean stylised look. Replace its contents with the new bundle:

- the hero: the gun in image 2 (the "Payload Lancer", a burst rifle skin), large, angled across the middle, the clear focal point
- behind it, slightly smaller: the case in image 3 and the box in image 4, both upright, overlapping a little
- a small stack of our gold coins at the front corner (same coin style as image 1)

Rules: keep each item's real shape and colours exactly (they're in-game models, don't redesign them). Stylised and clean, soft studio lighting, a dark violet-navy background like image 1, a gentle gold rim light. No text, no logos, no extra items, no characters. Transparent background if image 1 has one.
```

## 2. Season 1 thumbnail: the winner with an Arcade gun (16:9, 1920x1080)
**Attach:**
1. `art-source/marketing/draft-duels/thumbnail-v10/exports/03_v10_gold_barrel_closeup_clean.png` (the 4.5% winner: layout and style)
2. `art-source/ui/item-portraits/Vandal_Arcade_HD.png` (the Arcade Havoc)

```
Image 1 is the best-performing thumbnail for my own Roblox game. Make a new version of it for our Season 1 update, changing only one thing: the fighter now holds the gun in image 2 (the "Arcade Havoc": a rifle skin like an arcade cabinet, purple body, neon edges, a pixel screen and arcade buttons on its side).

Keep from image 1: the same fighter (the gold block character), pose, camera, forced-perspective barrel close-up toward the viewer, the red laser and crimson glare, the sunlit arena, and the clean uncluttered look with one focal point. The gun's neon accents can glow softly; nothing else new.

Rules: the gun must match image 2 exactly (shape, colours, details). No explosions, no muzzle blast, no extra effects, no particles. Add only the text "SEASON 1" small in the top-left corner, in heavy white sans-serif with a slight dark shadow. 1920x1080.
```
**Variant B:** same prompt with the Frostbite Havoc portrait (`art-source/ui/item-portraits/Vandal_Frostbite_HD.png`), ice-blue glow instead of neon.

## 3. Season 1 thumbnail: a skin lineup (16:9)
**Attach:**
1. the winner (as above, for style and lighting only)
2. 4 Arcade portraits: `Vandal_Arcade_HD.png`, `Operator_Arcade_HD.png`, `Classic_Arcade_HD.png`, `Bucky_Arcade_HD.png` (all in `art-source/ui/item-portraits/`)

```
Make a thumbnail for my own Roblox shooter's Season 1 update: the four guns in images 2-5 (our "Arcade" skin line) fanned out like a hand of cards, big, crisp, slightly angled toward the viewer, over a dark violet arena backdrop with soft magenta and cyan rim light. Same clean, uncluttered, high-contrast style as image 1.

Rules: every gun matches its image exactly. No characters, no effects, no particles. Text "SEASON 1" top-left, heavy white sans-serif. 1920x1080.
```
Test it against #2 in Play Ads; the data favours a character with a gun, so #2 is the main bet.

## 4. Store page description (paste into the Creator Dashboard)
```
Draft Duels: fast 1v1, 2v2 and 3v3 gunfights where you DRAFT a new power every round.

• Pick your loadout, then build your power deck round by round: dashes, smokes, lightning strikes, firewalls and more, each with upgrade paths.
• Every match plays differently. Outdraft, outplay, outgun.
• Level up your guns as you play them. Unlock new guns with coins.
• SEASON 1 BATTLE PASS: Arcade and Frostbite skins, charms, titles, and two new powers: Smoke and Electric Shock.
• Collect skins and charms, equip titles, show off your win streak.

Play with friends in parties or jump into quick duels on the lobby pads.

Sound credits: <list the licensed sound libraries here (ProPack and the others in vault/02 Art audio notes)>.
```
