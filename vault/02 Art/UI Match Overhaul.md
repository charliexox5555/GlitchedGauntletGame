# UI Match Overhaul + Map Vote (2026-11-16)

The owner's next phase after the lobby look pass ([UI Lobby Overhaul](UI%20Lobby%20Overhaul.md)): bring the match UI onto the new theme, check what RIVALS does better in a match, and add **map voting** (maps will be redone later, so the vote must not care which maps exist).

Sources: RIVALS file (read-only) `ServerScriptService.Server.DuelService`, client `ClientDuel.DuelInterface.Voting`, `Modules.MapSlot`, template `UserInterface.MapSlot`; [Rivals PC UI](../03%20Research/UI%20References/Rivals%20PC%20UI.md); [UI and Client](../03%20Research/Rivals%20Reference/UI%20and%20Client.md); our [Match Flow](../01%20Design/Match%20Flow.md), `Config/Match`.

## RIVALS' match structure (read from their files)
| Step | RIVALS | Ours today |
|---|---|---|
| Before round 1 | **Map vote, 12 s** (settle 1 s first); all voted → cut to **1.5 s**; chosen map shown **2.25 s** | none: the server picks a map for the team size |
| Pick | weapon pick page, round 1 **10 s**, later rounds **4 s** | the draft: 30 s round 1, 15 s after (gun + ability) |
| Round | **120 s** | 50 s, then sudden death |
| Round end | 4 s | 5 s |
| Win | first to 5 | first to 5 |
| Results | 25 s | final-kill replay, then 20 s match end |

**Their vote:**
- **Options:** every map that fits the number of teams, plus a **Random** card shown first, when there is more than one map.
- **The pick ("Chance" mode):** every vote is a ticket and one ticket is drawn. No votes, or the Random ticket, gives any map. Each card shows its **% chance** next to its name.
- **A map card:**
  - the map's picture, with its name in a bar along the foot;
  - the **voters' headshots** on it, ringed in their team colour;
  - a difficulty vignette and a small tag ("Experimental"); the chosen card plays an effect.
- **Cards** pop in staggered (Quint Out, 0.1-0.3 s), and a vote pops the card (Back Out 0.25 s).
- **Weapon bans** also exist (`MaxMapBansPerTeam`, ban icons) but are switched off.

**Our call:** keep our draft and round lengths (the draft is the game's identity); take the vote whole, with our own art and code.

## Plan
1. **Map vote (match place):**
   - a new `Vote` phase before round 1's draft;
   - `MapVoteService` (server: options for the team size + Random, one vote per player, validated and rate-limited, picks the map, bots don't vote);
   - a `MapVote` remote;
   - `MatchState` `MatchVote*` attributes;
   - numbers in `Config/Match VOTE`;
   - a Studio-built `StarterGui.MapVote` with map cards (picture, name, % chance, voter heads, the chosen effect);
   - map pictures captured from the current maps (placeholders until the maps are redone);
   - `Workspace.ForceMap` still skips the vote.
2. **Match screens onto the new theme:**
   - Rubik Heavy / Bold instead of Builder Extended;
   - neutral charcoal instead of navy (the lobby's neutralise rule);
   - the plate / cell look, title outlines and the shared `UiMotion`.

   Screens: top bar, combat HUD, notifications, draft, kill feed, death card / spectate, status tray, scoreboard, match end. Builders updated as backups.
3. Playtest a bot match end to end (vote → draft → rounds → end), then the results note, test list and commit.

## Open choices (owner)
Answered 2026-11-16 (all as recommended):
- **Where:** in the match server, before round 1's draft.
- **Pick rule:** chance, like RIVALS (each vote is a ticket, cards show %).
- **Options:** every map for the team size, plus Random.
- **Restyle:** all match screens in one pass after the vote, one review at the end.

## Added by the owner (2026-11-16, mid-build)
1. A **server / ping / FPS readout** top right, in the match and the lobby, like RIVALS.
2. **No map pictures yet:** the owner will make them, so cards show the name and keep an empty picture slot.
3. **Level and device marks** in the Tab scoreboard and the match top bar.

## Results (2026-11-16)
### Map vote
**Built and played through in Studio:** vote → the drawn map loads → round 1 draft → live.
- **Server:** `MapVoteService`.
  - `MatchService.pickMap` calls it with every installed map in `Config/Match MAPS` that fits the bigger team.
  - No vote when only one map fits, when nobody is in the server, or with Studio `ForceMap`.
  - Each vote is a ticket; one is drawn; no votes = any map.
  - The clock cuts to 1.5 s once everyone has voted; the chosen map shows for 2.5 s.
  - Numbers live in `Config/Match VOTE`. The `MapVote` remote is type-, length- and option-checked and rate-limited (`RATE.MapVote`); the vote is a server-set Player attribute `MapVote`.
  - New `MatchState` Phase `Vote`, plus `VoteOptions`, `VoteTeamSize`, `VoteChosen`.
- **Screen:** Studio-built `StarterGui.MapVote` (backup `tools/studio/BuildMapVote.luau`) + `MapVoteController`.
  - The controller keeps its own copy (`MapVoteLive`), because nobody has spawned yet and StarterGui only copies on a spawn.
  - Look: Rubik and charcoal; Random first with a "?"; each card has a name foot, the team sizes, your vote's foot turning white with a 1.04 pop, voters' heads ringed in team colour, % chance in gold, and the clock turning red at 3.
  - At the pick, the winning card pops and the rest dim.
  - `Config/Match MAPS` entries take an optional `name` and `image` for when the art exists.
- **Other screens:** the top bar, Tab scoreboard, spectate and match HUD treat `Vote` like `Waiting`.
- [Selected vote](Overhaul/match_map_vote.jpg).

### Server / FPS / ping readout
- `Shared/NetStats` draws a small dark plate in the Roblox top bar row, top right, in both places. Its first line is the region; the second has 3 signal bars (green under 60 ms, gold under 150, else red), then FPS (20-frame average) and ping.
- `Shared/ServerRegion` looks up the server's region once per server (`Config/NetStats REGION_URL`, ipinfo.io: only the server's own request, no player data; needs HTTP requests on, which they are in the match place).
- Studio shows "STUDIO"; a failed lookup shows "SERVER " plus the first 4 characters of the JobId.
- Wrappers: `ServerInfoService` + `NetStatsController` in each place. In the lobby it sits left of the top bar buttons.
- [Lobby](Overhaul/lobby_netstats.jpg).

### Level and device marks
- `Util/PlayerTags` draws a level chip ("LV n" from the Player attribute `Level`, or BOT for bots) and a device icon (our own icons, `art-source/ui/device-icons`).
- Device: the client reports it (`DeviceController`); `DeviceService` validates it against `Config/PlayerTags DEVICES`, rate-limits it, and sets the Player attribute `Device`. It's a label only.
- On screen:
  - Tab scoreboard: after the name.
  - Top bar: level on the tile's foot, device in its corner.
- **Nothing sets `Level` yet** (no progression), so everyone reads LV 1, like the lobby list.
- [Top bar](Overhaul/match_topbar_tags.jpg), [scoreboard](Overhaul/match_scoreboard_tags.jpg).

### Notes
- The Tab scoreboard has no rows during round 1's draft (stat lines start when the round goes live). Same as before.
- The vote delays the first spawn, so two screens log a harmless "infinite yield possible" warning while they wait.
- Testing needs Workspace `TestMode` off and `ForceMap` cleared in the match place. Both were put back (TestMode on, ForceMap OldTown2).

### Match screens restyle
- **In Studio (match place, in place):**
  - every match screen (TopBar, BottomHud, Notify, DraftScreen, KillFeed, DeathScreen, MatchEndScreen, StatusTray, Scoreboard) and their templates (TopBar, KillFeed, MatchEnd, Status, Scoreboard, Replay) are on **Rubik** (ExtraBold and up → Heavy, SemiBold / Bold → Bold, lighter → Medium): 229 text objects;
  - the lobby's navy → charcoal rule on every colour: 685 colours;
  - 24 big white words got the soft dark outline.
- **Code:**
  - `Config/Theme` text styles moved from Oswald / Montserrat to Rubik, and its greys to charcoal (this also touches lobby screens that read Theme);
  - the navy constants in `KillFeedController`, `ScoreboardController`, `TopBarController`, `Util/BottomHud`, `Util/DraftScreen` and `Util/MatchEndScreen` moved to charcoal.
- **Builders updated** (font + colours): BuildTopBar, BuildNotify, BuildDraftScreen, BuildFeedScreens.
- **Not touched** because other lanes have uncommitted work in them: BuildBottomHud, BuildMatchEndScreen, BuildMatchExtras, `ModHudController`, `Util/StatusTray`. Their Studio screens are restyled, but their backups and code colours still say navy; do them when those lanes land.
- **Seen in play:** the draft and the live HUD ([draft](Overhaul/match_draft_restyle.jpg), [HUD](Overhaul/match_hud_restyle.jpg)). **Not seen yet:** kill feed, death card, match end, notifications; the change is the same uniform pass.
- **Grade 8.5:** consistent with the lobby now. Weak spots:
  - small body text on the draft cards reads crowded in Rubik (its spaces are narrow);
  - the outline on the ability titles over coloured bands looks a little heavy.

## Test list for you
1. **Save the match place** (vote screen, restyled screens, templates) and the **Lobby place**.
2. Match: the vote (click a card, change your mind, let the clock run out with no vote = random), then the map loads and round 1's draft opens.
3. Top right in the match and the lobby: region, FPS, ping and bars (live servers should show a region, not "SERVER xxxx").
4. Top bar tiles and the Tab scoreboard: LV and device marks; bots show BOT.
5. A full match: kill feed, death card, notifications and match end in the new look.

## Open questions (parked)
1. **Map pictures:** yours, later. Add `image = "rbxassetid://..."` to the map's entry in `Config/Match MAPS` and the card shows it.
2. **Levels:** nothing gives levels yet. Progression (XP per match, saved) is its own task.
3. **Vote length:** 12 s like RIVALS. Shorter?
