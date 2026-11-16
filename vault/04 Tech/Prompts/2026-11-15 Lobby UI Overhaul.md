# Prompt: Lobby UI overhaul (2026-11-15)

Paste into the UI session. Owner confirms at the end.

---

You're taking over the UI for GlitchedGauntletGame. The job: a full overhaul of the **lobby UI and every lobby screen**, then one consistency pass over the match UI. Work through the whole list without stopping to ask. Collect questions and decisions in the results note, and only hand back when everything is built, checked and written up. I'll confirm at the end.

## Load first (mandatory)
1. Skills: `gauntlet-vault`, `gauntlet-ui-style`, **`rivals-reference`** (new: RIVALS' own UI files are open in Studio), `roblox-ui-builder`, `roblox-dev:roblox-ui`. Use `lihfolk-lookup` for Roblox facts and `roblox-secure-remotes` for any remote you touch.
2. Vault (grep and ranged reads; don't load whole notes):
   - `vault/02 Art/Style Bible.md` → UI section
   - `vault/02 Art/UI Theme v4 Soft Edge.md`
   - `vault/03 Research/Rivals Reference/UI and Client.md` (how RIVALS stores, routes and animates its UI, with numbers)
   - `vault/03 Research/UI References/00 UI References.md` (video study of the live RIVALS / Valorant UI)
   - the note for each screen: `02 Art/UI Lobby HUD.md`, `UI Play and Party Menus.md`, `UI Locker.md`, `UI Shop.md`, `UI Battle Pass.md`, `UI Notifications.md`, `UI Overhaul Research.md`
   - the top of `vault/00 Home.md` and its Locked decisions → UI row
3. Read your memory notes on UI taste and follow them. The short version:
   - **Keep:** the dark look; slanted price plates; RIVALS-style icon tabs; one-piece chunky plates and cells; lobby font **Fredoka One**.
   - **No:** pills, outlines/strokes as decoration, glows, thin strips, rounded "AI" boxes, generic fonts, or the bright flat restyle (rejected).
   - **Motion:** Quint Out with no overshoot. A pop scales from the centre (anchor 0.5, 0.5); list items use a fixed holder with a centred inner UIScale. No UI sounds. One drawn-X close button everywhere.
   - **"Looks AI" usually means missing art or icons.** Fix that with real icon or art assets made through the ChatGPT art brief (`02 Art/UI Art Brief (ChatGPT).md`), not more shapes.

## How we use RIVALS
**Study, don't copy.** Take structure, layout, flow and the motion numbers in `UI and Client.md`:
- buttons: hover 1.125, press 0.875, 0.25 s;
- pages: open from 0.75 scale with a pop, 0.25 s;
- one page open at a time through a router;
- one Slot module per repeated card;
- per-screen blur 24 faded in;
- layout from scale sizes plus aspect-ratio constraints.

Do not use their images, 9-slice sources, icons, font or code. The RIVALS place file is read-only: never play it, never `require` its modules, never save it. Take screenshots of it only when a screen's layout needs checking. Save them in `vault/03 Research/Rivals Reference/third-party/ui/` (git-ignored, never committed).

## Scope, in this order
1. **System first:**
   - one shared component kit (plate, cell, tab, icon button, price plate, close X, list slot, page frame) used by every screen;
   - one page router (one open page, Esc/back closes, gamepad default element);
   - one motion module with the numbers above and our easing;
   - shared colour and text tokens in `Config/UiStyle.luau` / `Config/Theme.luau`.

   Move existing screens onto it, and delete the one-off styling it replaces.
2. **Lobby main HUD:** profile, currency, bottom icon bar, PLAY + party slots, player list, notifications.
3. **Play / queue / party:**
   - mode tiles and the searching bar;
   - party menu and invites;
   - the MATCH FOUND overlay;
   - teleport / loading screen.
4. **Locker** (v5 → polish), **Shop**, **Season Pass**: finish their look. Buying, claiming and progress still wait for the economy. Keep them UI-only and say so on the screen where it matters.
5. **Missing screens**, if they don't exist yet:
   - Settings (with a crosshair editor that reads `Config/Crosshair`);
   - Profile / stats;
   - a simple Inbox or Rewards stub.

   Check the code and Studio first, and build only what's missing.
6. **Phones:**
   - every screen on a 375×812 phone and a tablet;
   - touch targets at least 44 px, safe areas respected;
   - nothing clipped or overlapping.
7. **Match UI consistency pass:** top bar, combat HUD, draft, kill feed / spectate, match end, extras. Same kit, tokens and motion; no redesign unless something breaks the system.

## How to work
- Build in **Studio as real ScreenGuis** (owner rule): Studio-owned guis plus a Util module per screen, as the existing screens do. Lobby place for lobby screens (lobby Rojo on port 34873), match place for match screens. Pick the Studio instance by placeId.
- For each screen, loop:
  1. build;
  2. capture desktop and phone;
  3. self-grade against the UI rules (target 9/10, written down);
  4. fix;
  5. play it in Studio (open, close, hover, every button);
  6. move on.

  Keep captures lean: only the ones you judge with.
- Code rules from CLAUDE.md: `--!strict`, numbers in Config, clean up connections, every remote validated and rate-limited, no `wait()`. Run `stylua`, `selene` and `rojo build` before each commit.
- Commit each finished screen by **exact paths only** (never `git add vault` or `-A`; other sessions have work in the tree). Don't push. Remind me to **save both places**.

## Done means
- Every screen in the scope is on the shared kit, built, played in Studio on desktop and phone, and graded 9+.
- The results go in `vault/02 Art/UI Lobby Overhaul.md`:
  - what changed per screen, with captures;
  - grades and what's still weak;
  - a test list for me;
  - the open questions you parked.
- Home → Status, INDEX and Code Map updated for new modules or remotes.
- Hand back with a short summary and the test list. I'll confirm or send notes.
