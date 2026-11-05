# Morning test checklist (2026-11-05)

What the four overnight lanes built, and what to test, in a sensible order (about 45 minutes). Plan and rules: [Overnight 2026-11-04](../Overnight%202026-11-04.md). Each section links the lane note with the full detail.

**Before you start:** both Studios are open. Rojo is serving on **34872** (game) and **34873** (Lobby): if a terminal was closed, run `rojo serve default.project.json --port 34872` and `rojo serve lobby.project.json --port 34873`, then Connect in each Studio. Both places were saved to Roblox at about 01:08; nothing was published.

## 1. Lobby place: look and walk (≈15 min) · [Lobby Rebuild](../../02%20Art/Lobby%20Rebuild%202026-11-04.md)
- [ ] Spawn view: DUELS through the north portal, the SEASON 1 hologram, leaderboards. Turn: RANGE, SHOP, ARMOURY.
- [ ] **Lighting (blocks two scores):** Lighting → Properties → check `Technology` is **Future** (the agents can't read it), play on a mid or high graphics level. Do the coloured light pools show at the portals, pads, shop counter and range model? Agent screenshots can't capture local lights, so Market and Range scored 8.3 instead of 8.5 or more.
- [ ] Walk the ring and slide; down into Duels (stand on pads, read the screens), Market (Event niche left, Battle Pass right, then down to the shop cross), up into the Armoury and Locker, the Range room (holo cage, gate).
- [ ] Look for flicker, gaps, floating pieces, too much or too little clutter. Check the frame rate on low graphics.
- [ ] **Decide:** approve the look, or say what to change. It's also the proposed style for the match-map redesign: [Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md).
- Range interior ideas (not built): [Range Brainstorm](../../01%20Design/Range%20Brainstorm.md).

## 2. Lobby place: UI and queue (≈10 min) · [Lobby UI and Queue](../../01%20Design/Lobby%20UI%20and%20Queue.md)
- [ ] Play: top bar (profile, coins, settings) and the bottom bar (Locker, Shop, **PLAY**, Pass, Range) slide in; hover and click every tile.
- [ ] PLAY → 2V2 → FIND MATCH: timer, bots fill after **5 s** in Studio, MATCH FOUND, then the would-be TeleportData card (Studio can't teleport). Listen to the UI sounds.
- [ ] Queue, then walk: the queue pill stays at the top; CANCEL works. Walk onto a Duels pad and press E: the menu opens on that pad's mode.
- [ ] Phone view (Test → Device emulator, iPhone SE), gamepad, and Settings → Reduced motion.
- [ ] **Decide:** queue name, 30 s bot fill in live games, bots as opponents (current) or teammates.

## 3. Game place: bots (≈10 min) · [Bots](../../01%20Design/Bots.md)
- [ ] Workspace: untick `TestMode`, add string attribute `BotMatch` = `1v1`, Play. Fight a few rounds; try `BotDifficulty` = `Easy` / `Hard`.
- [ ] `BotMatch` = `2v2` / `3v3`: bot teammates spread out, use Mods, heal.
- [ ] Kill feed, round results, a full match to 5. `BotDebug` attribute shows what each bot is thinking.
- [ ] Strafe against one at 20–40 studs: it should miss more than when you stand still.
- Known gap: no cover and peeking yet (needs per-map cover points, best added during the map redesign).
- When done: tick `TestMode` back on and clear `BotMatch`.

## 4. Game place: animations and knife (≈10 min) · [Animation and Knife Pass](2026-11-04%20Animation%20and%20Knife%20Pass.md)
- [ ] With a bot in `1v1`: both hands on every gun class from the front, side and back; the fire kick on a rifle, shotgun and sniper; no "zombie arms" when swapping or reloading.
- [ ] Sprint then slide: the full-body slide on the floor and the push back up.
- [ ] Knife in first person: hold, light slashes 1-2-3, heavy stab, Y inspect. Slash a wall: the mark sits **under the crosshair**.
- Scores (LihFolk animation rubric, blind): slide 8.7 and holds 7.0 before the overlap check; with it, both are capped at 5.0, because blocky R15 limbs clip slightly at the joints. Your eye decides whether that clipping matters.
- [ ] **Decide:** the knife sound plan (the lane proposes downloading CC0 recording packs, then an audition before any upload).

## 5. Later, once you approve the look
- Redesign the match maps in the same style (your "last thing" from last night; on hold until you approve the style).
- Real teleport test: publish both places, join the Lobby from the Roblox app, queue 1v1 with a friend or alt; solo, wait 30 s for a bot match.
