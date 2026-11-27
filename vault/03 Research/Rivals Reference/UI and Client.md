# RIVALS reference: UI and client

Part of [Rivals Reference](00%20Rivals%20Reference.md). Studied 2026-11-15 from the RIVALS place file (read-only, nothing run). The scripts in the file are decompiles, so this note records **patterns and numbers, never their code**. Pair it with the live-video study in [UI References](../UI%20References/00%20UI%20References.md), which shows how these screens look when filled in; this file shows how they are built.

Paths below are in the RIVALS file. `UI.` = `StarterPlayer.StarterPlayerScripts.UserInterface`.

## How the UI is stored
- **Nothing in StarterGui.** All UI is a template library in `UI.` (7,523 instances). `Controllers.UserInterfaceController` builds it at runtime from 24 `Modules.UserInterface.*` modules.
- **One main ScreenGui**, `UI.MainGui` (`ResetOnSpawn=false`, `IgnoreGuiInset=true`, `ZIndexBehavior=Sibling`), with a `MainFrame` holding the always-there screens: `Lobby` (menu bar, Play, currency, party), `Queue`, `Equipment` (locker), `BottomStack` (spectate), `Notifications`, `SideTasks`, `Spotlight`, and an empty `Pages` holder.
- **Pages** (`UI.Pages`, 38 frames: Shop 788, Rewards, Matchmaking, Gifting, Settings, Ranked, BattlePass, ViewProfile, Maps, Collection, Tasks, Party…) live outside the gui and are **reparented into `MainFrame.Pages` when opened**. Each has a `UIAspectRatioConstraint` + `Container`; logic in `Modules.Pages.<Name>`.
- **Match HUD** is cloned per fighter: `FighterInterface` (bottom-left/right/centre, damage indicators, full-screen vignettes for damage, heal, frozen, low-ammo, speed lines), `DuelInterface` (top bar timer/scores/match point/round result, scoreboard, kill feed, voting, final results), `ItemInterface` (mouse + aiming vignette), `Crosshair` (foreground/background/hitmarker).
- **~150 `…Slot` / `…Card` templates** at the top of `UI.`, each with a matching `Modules.<Name>Slot` that clones and fills it (NotificationSlot, EliminationFeedSlot, ScoreboardPlayerSlot, ShopSlot, BattlePassRewardSlot, CosmeticSlot, WeaponSlot, MatchmakingQueueSlot…).
- **World-space UI:** 14 BillboardGuis (nametag, damage, teammate label, scope glare) and 9 SurfaceGuis (duels board, leaderboard, likes board, eliminations board, starter-bundle board, shooting-range board, video ads).

**For us:** the same split we already use (Studio-built templates + a module per screen). Worth copying as a *pattern*: one Slot module per repeated card, pages that live outside the gui until opened, one router (below).

## Motion (the numbers)
- **Buttons** (`Modules.ButtonEffect`): hover grows to **1.125×** (Quint Out 0.25 s); press shrinks to **0.875×** (Quint Out 0.25 s) with a click sound; release snaps to 1.125 then eases home with **Back Out 0.25 s** (small overshoot). Re-anchors to (0.5, 0.5) so it scales from the centre (same as our [UI scale pivot](../../02%20Art/UI%20Shop.md) rule). Also reacts to gamepad selection.
- **Pages** (`Modules.Page`): open starts at **0.75 scale, y = 0.6**, tweens to full size at y = 0.5 with **Back Out 0.25 s** (rises and pops). **No close animation** (just hides). Reduced Motion turns the pop off. Shop opts out.
- **Router** (`Modules.PageSystem`): one page open at a time; `OpenPage(name, toggle)`, `CloseCurrentPage`, signals for opened/closed; each page must give a default element (gamepad) and a close request.
- **Backdrop** (`Modules.GlowyBackground`): each screen has its own Lighting **Blur (size 24) + ColorCorrection (brightness -0.3, contrast 0, tint 220 grey)**, faded over **2 s on a quintic ease-out**; four tiled pattern images drift slowly behind pages. Prompts dim the background to 0.333 transparency.
- **Totals across modules:** Quint ~45 uses, Back ~12 (pops only), then Quad/Quart/Linear; **Out** nearly always; **0.25 s is the default beat**, 0.5 s next. No sine, elastic or bounce. Springs are used for the viewmodel, not the UI.

**For us:** this matches the owner's rule (Quint, no overshoot except pops). Our pop = their Back Out 0.25 s; our default = Quint Out 0.25 s.

## Build details
| Item | Count | Note |
|---|---|---|
| Frame / ImageLabel / ImageButton / TextLabel | 2,004 / 1,808 / 441 / 974 | **no TextButtons**: every button is an ImageButton with labels inside |
| 9-slice images | 1,042 of 2,249 | one rounded-square source, `SliceCenter` (15,15)-(16,16), corner size set by `SliceScale` (0.5 most, also 0.35 / 0.25 / 1 / 0.125) |
| UICorner | 367 | 0,8 most; 1,0 (circles) 102 |
| UIStroke | 423 | thickness 2 nearly always, Round joins |
| UIGradient | 915 | heavy use for sheen and fades |
| UIAspectRatioConstraint / UIScale | 146 / 8 | layout is scale + aspect ratio, not UIScale |
| Fonts | ~1,000 labels | **one custom family** (weights Medium, ExtraBold, Bold, Heavy, SemiBold) |
| Button base colour | RGB 18,18,21 at 0.08 transparency, icons 247,247,248 | |

- **3D previews:** ViewportFrames only for emotes and cosmetics (cameras at **FOV 25**, plus a zoomed-out variant). The **locker is a real 3D scene in the world** with its own camera and a fade frame, not a ViewportFrame (we did the same for our Locker).

## Phones
- **No separate phone gui and almost no UIScale.** Layout = scale sizes + aspect-ratio constraints.
- Touch players are sent to a **separate mobile duels place** (`MobileController`, a mobile place id, a `MobileDuels` page).
- Code branches on `ControlsController.CurrentControls == "Touch"` in ~15 files (camera, locker spin, settings tab, shop opens an inspect prompt instead of hover).
- Touch overlay `MainGui.MobileInputs`: joystick area, double-tap area, buttons, and an **editor that lets players move and resize their touch buttons** (saved per profile through two Data remotes).

## Client architecture
- `ReplicatedFirst` bootstrap → `StarterPlayerScripts.Client` requires **51 Controllers** each in a pcall (one broken controller doesn't stop the rest).
- `Modules` (935): UI kit, `Pages` (37), `ViewModels` (347), `LightingProfiles` (36), `Items`, `GameComponents`, `LobbyElements`.
- Shared `ReplicatedStorage.Modules`: `*Library` modules (Item, Shop, Cosmetic, Sound, Animation, Settings, Season…), `Signal`, `Spring`, `CONSTANTS`, enums.
- **Replication:** a `ReplicatedController` base; server objects arrive on `Remotes.Replication.<Name>.Replicate` / `ReplicateUnreliable` as Added/Changed/Removed with ids.
- **Remotes:** 196 plain RemoteEvents/Functions/Unreliable, grouped in folders (Data, Misc, Replication, Matchmaking, PrivateServer, Moderator, Duels, Permissions, Arcade, Debug, Analytics). No networking library.

## Screenshots (local only)
`third-party/ui/` (git-ignored): the lobby play / queue bar, the shop tabs with empty cards, the match HUD template. Static captures come out half-empty because code fills the slots; use the video study for the filled look.

## What we take
- Patterns: page router, slot modules, aspect-ratio layout, per-screen blur, the motion numbers above, the touch-button editor idea (parked for mobile).
- **Not** their images, 9-slice sources, icons, font or code. Our look stays [Soft Edge](../../02%20Art/UI%20Theme%20v4%20Soft%20Edge.md) + the owner's plate style.

## Damage numbers (2026-11-16)
- `UserInterface.DamageGui`: a BillboardGui sized `{15, 250}, {15, 250}` (15 studs + 250 px: smaller with distance, less than the world), AlwaysOnTop, MaxDistance 400. The file's `Modules.DamageNumbers` says it is a port rebuilt from captures (not original code): one billboard **per target**, on top of the head, whole numbers, crit red and taller, and a hit while it's alive **adds to the same number and re-pops it**. What we took: [Match Fixes Round 1](../../05%20Production/Playtests/2026-11-16%20Match%20Fixes%20Round%201.md) → 6.

## Map vote (2026-11-16)
- `DuelInterface.Voting`: wide 2.2:1 map cards in a grid (3 per row, 2 x 2 for four, featured + small above six), voters as square team-coloured headshot tiles, your pick = white foot. No vote timer of its own (the top-bar timer grows). No springs: cards open 0.25 → 1 scale Quint Out over `sqrt(i)*0.1+0.1` s, blur 24; votes redraw instantly; the winner flies to the centre (0.75 s Quint Out), holds 1.25 s. Full numbers and our plan: [Match Fixes Round 1](../../05%20Production/Playtests/2026-11-16%20Match%20Fixes%20Round%201.md) → 7.

## Case opening (2026-11-20)
`StarterPlayerScripts.Modules.Functions.LootboxEffect` + `Assets.Lootboxes` (read only): the box is tossed ~7 studs out over 2 s (eased glide, ~1.5 decaying bounces), plays its own clip (`Animation` attributes `Duration` / `RevealDelay`: skin case 4.85 / 2.0, weapon crate 5.55 / 2.25, chests 8-9 / ~4), the reward card (10-stud BillboardGui, ~8 studs up) grows in 0.5 s Quint Out with a rarity-coloured trail and a rarity stinger, holds 4 s, shrinks (Back In) and flies into the player (1.9 s Quint In) into collect particles. Everyone sees it; others at half volume. Our build: [Case Opening](../../01%20Design/Case%20Opening.md).

## First-time flow (study 2026-11-22, for onboarding)
- Beginner 2v2 = queue `2v2_beginner` in `ReplicatedStorage.Modules.DuelLibrary` (`add_queue`): sorted first, no lobby pad, one map (Arena), 1 real player per team, title "Beginner". Shown in the Play page while duel wins < `CONSTANTS.BEGINNER_QUEUE_WINS` (10), then Ranked takes its slot (`Modules.Pages.Matchmaking._UpdateBeginnerQueue`).
- Play page while duels played < 3: a simpler centred duels frame (`CenterDuelsFrame`).
- PLAY bubble "Join the queue to start playing!" while duels played ≤ 3 (`Modules.UserInterface.Lobby.Play`, `PlayButtonJoinBubble`).
- Red enemies: `Modules.ClientReplicatedClasses.ClientDuel.BeginnerDuel` sets `SetRedFigureMode(true)` on every non-team fighter at `RoundStarting` / `RoundStarted`, Beginner queue only.
- Favorite prompt: `Controllers.LobbyController._PromptStuff`, 1 s after landing in the lobby, once per session, at duels played = 5 or the first win; notification opt-in at 8 played / 2nd win.
- What we took: [Handoff - Onboarding and Bots](../../05%20Production/Handoff%20-%20Onboarding%20and%20Bots.md) → Phase 1 results.


## Loadout / weapon pages (study 2026-11-26, for our Locker revamp)
The RIVALS file was running (the owner had started Play). Clicked through `MainGui.MainFrame.Equipment` and read the code without running it. Captures are in `third-party/ui/loadout/` (git-ignored): 01 weapon page, 02 locked weapon, 03 overview metrics, 04 statistics.

**Layout.** The camera sits in a 3D locker room: the gun floats over a workbench in the middle, and the UI fills the side columns, about 25% of the width each.
- **Left** (`Left.List`, a scroll list):
  - At the top, a **Career** card: the avatar plus one icon per class (ability, primary, secondary, melee, utility).
  - Under it, the selected weapon card (name plus a gun render).
  - Then one `EquipmentClassSlot` per class (Primary, Secondary, …), listing that class's weapons. Locked ones are greyed with padlocks; special or limited guns have animated gold or purple names.
  - A "Dismiss N notifications" row.
- **Right** (`Right.List`), with stacked cards that change with what is selected:
  1. **Details:** name, two bullet lines (class, one-line role), a favourite toggle.
  2. **Level:** an XP bar (level number over it, 0–50), "Level up now!" with a key price, "Reward at Level 5" with the reward icon.
  3. **Actions**, each a row with a big coloured button:
     - Contracts → (earn free rewards).
     - Overview 👁 (expands inline: equip cooldown, move speed, damage near→far, falloff range, fire rate, spread, headshot damage, ammo).
     - Statistics 👁 (expands inline: playtime, rounds and wins, damage and eliminations split by sliding / crouching / airborne / blinded, deaths, assists).
  - On the Career page the actions are Career, Collection, Performance, Duel History, Maps.
- **A locked gun** gets gold chains and a padlock over the model, and the right panel swaps to **Unlock now** (35 keys), **Free Trial** (play 1 duel), **Try out for free** (range), and a special offer.
- **Bottom bar** (customise): Leave, Skin, Wrap, Charm, Finisher; a top name display.

**Code** (read only):
- `PlayerScripts.Modules.UserInterface.Equipment` (+ `EquipmentState`, `Scene.UnlockModel`, `Interface.Right.Overview.MetricsGuide`), `EquipmentButtonSlot`, `EquipmentMetricCard`, `BaseContractSlot/ContractSlot`, `Pages.Contracts`.
- Shared rules in `ReplicatedStorage.Modules.ContractsLibrary` (26 KB), `StatisticsLibrary` (130 KB) and `LootLibrary`.

**Rules worth knowing:**
- **Weapon level XP:** `max(50, floor(5 + 4(n−1) + (min(n,99)/40)² × 100))`, so 50 XP a level early, rising later, max 99.
- **Buying the rest of a level:** `clamp(floor(10 × (1 − progress)), 1, 10)` keys.
- **Level rewards:** a key at level 5, a white wrap at 50, a black wrap at 99. Career levels give a random "Experience" item every 10.
- **Weapon contracts** have two tracks per weapon:
  - **Eliminations:** 5, 20, 100, 500, 2,000, 10,000, 20,000, 30,000, 40,000 × a per-weapon factor. Rewards: key → charm capsule ×2 → wrap box → mastery camos Gold → Diamond → Midas Touch → Diamond Hands → Dark Matter.
  - **Playtime:** 5 min, 20 min, 1 h, 6 h, 12 h, 24 h, 48 h, 72 h. Rewards: key, charm capsule, the weapon's colour, wrap boxes, a chibi version.
  - Map contracts give dioramas.
- **Live numbers (2026-11-26, second look):** the locker camera is FOV 18 on a set far below the map, with a `DepthOfFieldEffect` (far 0.75, near 0, focus 0.1, in-focus radius 15). Panels are a black 9-slice at 25 % transparency; buttons are a white 9-slice with a vertical gradient (blue 0059FF → 00D0FF, gold FFFF00 → EBC015, green 74DF32 → C6FF0A) plus a `Shine` copy on the top half, and words carry a black stroke at 88 % transparency. Used for our [Locker v3 mockup](../../01%20Design/Loadout%20and%20Power%20Deck.md#locker-v3-mockup-2026-11-26).
- **What we take:** the structure (side columns around a 3D gun, cards that change with the selection, inline overview and stats, a locked state with clear unlock actions, levels from use, two contract tracks with prestige camos at the top). Not their art, layout proportions or names. Ours is in [Loadout and Power Deck](../../01%20Design/Loadout%20and%20Power%20Deck.md#locker-design-from-the-rivals-study-2026-11-26).
