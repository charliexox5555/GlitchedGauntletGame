# UI concept prompts (2026-11-05, lane E)

ChatGPT image prompts for the UI concept pass. See `vault/01 Design/Lobby UI and Queue.md` §10.

No third-party screenshots were uploaded; what to take from the references is described in words (LihFolk *UI Style Directions*, section 5).

## Shared style block (pasted into every prompt)
```
Original game UI concept, 16:9, 1920x1080 screen mockup, flat 2D interface over a stylised low-poly 3D arena (shipping containers, concrete, warm daylight, Roblox-style blocky characters). Game: a fast competitive arena shooter where players draft abilities each round (working title GAUNTLET).
Look: a shipped AAA competitive shooter. Crisp, engineered, readable, restrained.
SHAPES: sharp rectangles; ONE signature detail = a small 45-degree clipped corner (top-left and bottom-right) on primary panels and buttons only; 1-pixel hairline light rules and small tick marks as structure. NO rounded corners, NO pill shapes, NO circles (except the crosshair), NO glassmorphism, NO soft drop shadows, NO glow halos, NO gradients on buttons.
TYPE: heavy geometric sans (like Montserrat Black), ITALIC for big titles and big numbers; small uppercase labels in a clean humanist sans with letter spacing. Huge size contrast: one big word per screen, everything else small.
PALETTE: near-black navy panels #11151C at 85-95% opacity, off-white text #F5F7FA, muted grey #A6B0BE, ONE action colour gold #FFC83D used only for the main action and the selection, ally cyan #2FD3E6, enemy coral #FF5A4E.
LAYOUT: anchored to screen edges, asymmetric, left-aligned titles, generous negative space; centre of the screen kept clear.
Do NOT copy any existing game's logo, name, icons, characters, layout or branding. No real brand names. Text in the image must be short and spelled exactly as given.
```

## 1. Options round: Lobby, three directions
```
<style block>
Make ONE image split into THREE side-by-side panels labelled A, B, C, each the same Lobby screen in a different shape direction:
A "Clipped steel": the clipped-corner rectangles described above.
B "Slant": everything is a parallelogram slanted 12 degrees, heavy italic everywhere.
C "Hairline pro": almost no panels, text and numbers on thin hairline rules, square edges.
Lobby screen contents (same in all three): top edge bar flush to the top: left = player name "CHARLIE" + "LV 1" + thin XP line; centre = text tabs PLAY  LOCKER  SHOP  PASS  RANGE with a gold underline under PLAY; right = coin count "0" and a square settings button. Bottom right: the biggest element, a gold PLAY block with "PLAY" in huge italic and "1V1 · 2V2 · 3V3" small under it. The player's blocky avatar stands in the arena in the centre.
```
**Result (15:50):** ChatGPT accepted the prompt, then answered "Image creation is only available when you're logged in". It needs the user's sign-in in lane E's browser pane.

## 2. Lobby PLAY / queue menu (after a direction is picked)
```
<style block, chosen direction>
Full-screen PLAY menu over the dimmed lobby. Top-left: small gold label "PLAY · CASUAL DUELS" and under it a huge italic title "CHOOSE YOUR FIGHT". Three tall mode cards in a row from the left: 1V1, 2V2, 3V3. Each has an in-engine render band at the top (blocky characters facing off), the mode name in huge italic overlapping the art's bottom edge, one line of description, "FIRST TO 5 · 2 PLAYERS", a green dot with "0 SEARCHING". The first card is selected: a 2 px gold frame, a small gold "SELECTED" tag above it and small corner ticks. A square close button at the top right. Bottom right: a flat gold "FIND MATCH" block. Bottom left: keyboard hint keys "1 2 3 CHOOSE", "ENTER FIND MATCH", "ESC BACK".
Also show a small inset: the compact searching bar under the top bar, "SEARCHING · 1V1 · 0:42 · CANCEL".
```

## 3. Match HUD (in a round)
```
<style block, chosen direction>
First-person view holding a blocky pistol in the low-poly container arena. Top centre, under a 58 px empty strip: three plates side by side (ally plate with a cyan top edge, "YOU", health line and score "2"; a centre timer plate "0:47" in big italic with "ROUND 3 · RIFLE" above and 5+5 small square pips below; an enemy plate with a coral top edge, "ECHO", score "1"). Top right: kill feed, 3 sharp rows with a team-colour left stripe, killer, weapon name, victim; my kill has a thin gold outline. Centre top third: round banner, small "ROUND 3" over a huge italic "WON" in cyan between two hairlines, with small corner ticks. Bottom left: health plate, a shield badge "50", "100" in big italic, a segmented bar. Bottom centre: three square ability slots Q, E, T with icons; E is on cooldown (dark, "4", partly filled line); key letters in small outlined key boxes. Bottom right: ammo plate, "12 / 12" big italic, gun name "CLASSIC" and a small gun silhouette. Thin white crosshair. Leave the centre clear.
```

## 4. Draft screen
```
<style block, chosen direction>
Between rounds: a dark overlay. Top-left: small gold "ROUND 3 · DRAFT", a huge italic "PICK A GUN AND ONE MOD". A row of three compact gun cards (1 SHERIFF, 2 SHORTY +25 SHIELD, 3 GHOST +25 SHIELD), the first selected with a gold frame. Under them, three tall ability cards with Q, E, T key tabs on top; each has illustrated art at the top in its role colour (gold, orange, purple), a role-colour rule, the name in big italic (STIM, MOLLY, FIREWALL), an outlined role tag (TEAM BUFF, DAMAGE, CONTROL), two lines of description, a footer "1 PER ROUND" and "NEW · LV 1". The middle card is selected (gold frame and corner ticks). Right column: "LOCK IN" label, a big italic timer "0:15" with a line, "ENEMY KIT: No abilities yet", and a flat gold "LOCK IN" block.
```

## Figma frames built from the "Clipped steel" direction (no ChatGPT yet)
`figma-v3-clipped-*.png` in this folder are renders of the Figma frames (file `UbCKQXuZijn0Gpryt0uUxN`, Screens page, y 8500-11275).
