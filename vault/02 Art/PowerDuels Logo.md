# PowerDuels logo

> **[RETIRED 2026-11-26]** The owner went back to **Draft Duels** ("Draft Duels is still a better name"). The game uses the [Draft Duels logo](Draft%20Duels%20Logo.md) again; this note and `art-source/ui/powerduels/` are history. "Powers" (not abilities) stays.

The owner renamed the game to **PowerDuels** on November 25, 2026. Write it as one word. The wordmark stacks **POWER / DUELS**. The Draft Ticket’s gold-and-cream palette carries over. Its ticket becomes a power-up badge with an original bolt, while the DUELS letters get a slight bounce and the small sparks mark the energy of the reveal.

- [Logo sheet](../../art-source/ui/powerduels/powerduels-logo-sheet.png) and [asset kit guide](../../art-source/ui/powerduels/README.md)
- [Reveal preview](../../art-source/ui/powerduels/powerduels-reveal.gif) and [Claude integration prompt](../../art-source/ui/powerduels/CLAUDE-INTEGRATION-PROMPT.md)
- [Draft Duels logo history](Draft%20Duels%20Logo.md)

The layered master, vector exports, monochrome bases, horizontal mark, and aligned Roblox sprites are on disk.

## Roblox integration (2026-11-25)

**Uploaded** with `tools/opencloud/upload_asset.py --group 11116787 --type Decal` (group 11116787 owns experience 10772880160). Decal ids resolve to image ids through InsertService. Both are recorded in `art-source/uploads.json` (`assetId` / `imageId`).

| Sprite (`art-source/ui/powerduels/ui/`) | Decal | Image (used in ImageLabels) | Loading layer |
|---|---|---|---|
| `power.png` | 89151942774358 | 108640302171695 | `Logo.Ticket` (name kept, the controllers bind it) |
| `duels.png` | 120431138519485 | 113740015524735 | `Logo.Duels` |
| `sparks.png` | 104639300067696 | 90350576633615 | `Logo.Sparks` (new, optional) |
| `full.png` | 139449726319345 | 71296115628525 | `Logo.Full` (reduced motion) |
| `shine-mask.png` | 106420837548370 | 136775039864530 | `Logo.Shine` |

**Installed**
- [BuildDuelsLoading.luau](../../tools/studio/BuildDuelsLoading.luau) builds the new layers.
- The local Studio template `ReplicatedFirst.DuelsLoading` in place 71551303511506 was edited in place, not rebuilt, so the owner's template edits stay.
- Ticket, Duels and Sparks show by default, so plain clones show the whole mark: the teleport screen (`MatchFoundController`, the match-end home teleport) and the pad-duel cover (`DuelLoadingController`).

**Motion** ([LoadingScreen.client.luau](../../src/first/LoadingScreen.client.luau)), timed from the band's start + 0.12 s, after the reveal GIF:
1. POWER comes in from the upper left, tilted −7° and at 92% scale, and lands at 0.235 s (Back). The sting plays on the landing (`Config/Loading` `sting.at = 0.235`).
2. DUELS enters at 0.185 s and rises into place by 0.5 s, with a small punch.
3. The sparks pop from 0.34 s (scale 0.7 → 1, Back).
4. The shine sweeps at 0.95 s. While the title floats, the sparks ride with the badge and twinkle.

Reduced motion hides the layers and fades in `Full`. Older copies without `Sparks` still work. The milestones, watchdog, layout, teleport handoff and preload are unchanged; the preload adds Sparks.

**Verified in local Studio (2026-11-25)**
- **First join:** the real `ReplicatedFirst.Loading` script, replayed on the client and recorded. Order: POWER, then DUELS, then sparks, shine, segments, READY and close. No errors from the loading code.
- **Lobby pad duel:** 1v1 with `PadDuelSolo`. The cover shows the full mark with "LOADING DUEL" and fades into the map vote.
- **Layouts:** desktop (2178 × 964) and phone frames 844 × 390 and 667 × 375 through `LoadingLayout.fit`. Nothing clips.
- **Reduced motion:** `Full` renders at desktop and phone sizes and lines up exactly with the layered mark. The live `ReducedMotionEnabled` path can't be switched on in Studio, so it is checked by code reading only.
- **Not verified:** the reserved-server teleport handoff (Studio doesn't teleport). Its code is unchanged and uses the same template.

**Other player-facing changes**
- There was no other Draft Duels branding in the game: no UI, signs or template text. The Rojo source had it only in comments and tool headers.
- The first loading tip is now "PICK A NEW POWER EVERY ROUND".
- Player-facing "ability/abilities" text now says "power/powers": draft hint, enemy-kit line, Range blurb, Locker tab label (the instance stays `ABILITIES`), Locker save error, settings and touch-layout labels. Remote and data names are unchanged. "Mods" text is unchanged.

**Sound audition (2026-11-25, owner: "use better sounds")**
- The tool is [AuditionLoadingSounds.luau](../../tools/studio/AuditionLoadingSounds.luau). It plays each candidate over the real reveal, using Studio-only Workspace attributes that `LoadingScreen.client.luau` reads (`LoadingAuditionSting` / `Bed` / `Whoosh`, `…Volume`, `LoadingAuditionHold`).
- To run it: press Play, switch the command bar to the client, set `PASS` (`stings`, `whoosh`, `beds` or `combo`), then paste and press Enter. The Output names each candidate.
- All candidates are licensed Roblox partner audio and all 16 load (checked in Studio).
- **Picks (2026-11-25, the owner left it to Claude: "whatever you think is best"; not heard, chosen by fit):** sting 1 (Outrunning - Hit, kept: 3.1 s fits the reveal; the No Stopping Us tags run 6.4-7.2 s past it and Totally Go For It is now the Common case reveal), no whoosh (Whoosh 1 was tried, then taken out: owner 2026-11-25 "I dont really like the swooshes"), bed 1 (Beginnings, kept). In `Config/Loading`. Swap any time with the tool.
- Stings:
  1. Outrunning - Hit (9047207931, current)
  2. There's No Stopping Us - Tag3 (9042539652)
  3. There's No Stopping Us - Tag1 (9042539411)
  4. There's No Stopping Us - Tag5 (9042539884)
  5. Automata Sting 2 (9047064962)
  6. Mech Madness Stinger 1 (127087932061391)
  7. Totally Go For It - Hit4 (9038919815)
  8. Spinning Around (b) (1839881844)
- Whoosh under POWER's swing (new optional `Config/Loading.whoosh`, none for now):
  - W0 none
  - W1 Whoosh Fast Swish By 3 (9120714219)
  - W2 Whoosh Fast Swish By 1 (9120710054)
  - W3 Searing Bursts 15 (9118883081)
- Beds:
  1. Beginnings (9042293789, current)
  2. There's No Stopping Us - Alt2 DrumsBass (9042539083)
  3. There's No Stopping Us - Alt1 NoLead (9042539080)
  4. Night Driver (a 30) (1842054459)
  5. Round About Now, no percussion (9042294497)
- Stings 2–4 and beds 2–3 come from one track ("There's No Stopping Us", big confident electro), so the sting and bed can match.
- No licensed spark sound was good enough, so the sparks stay silent.
- Checked in Studio: the override swaps the sounds. The whoosh starts at 0.03 s, the sting at 0.37 s (target 0.355 s), and the hold stretches for beds. Nobody has listened yet; the owner picks by ear.

**Still to do (owner)**
- Creator Dashboard: experience name "PowerDuels", description ([Store Description](../05%20Production/Store%20Description.md) still says Draft Duels), icon and thumbnails ([Launch Art](Draft%20Duels%20Launch%20Art.md) is Draft Duels art).
- Group, badge and pass names if they say Draft Duels.
- Publish the place, then save it.
