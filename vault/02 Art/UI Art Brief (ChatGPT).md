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

