# Frostbite line: prompt for the building agent (2026-11-27)

Paste the block below into a new session. It builds the **Frostbite Havoc first** and stops for the owner's approval; the other 13 guns and the Knife come after a yes.

---

> **Build the Frostbite skin line, starting with ONE gun: Frostbite on the Havoc (Vandal).** Frostbite is the Season 1 battle pass **Legendary** chase line: faceted ice crystal over dark metal with a cold blue-white glow. Being Legendary, it needs **more than a shape change**: its own animated effects (ice grows over the gun on inspect, ice cracks and sheds when you get a kill, a soft cold shimmer at rest) and its own sounds (fire layer, inspect and kill), on top of a model that clearly beats the Arcade line.
>
> **Read lean (query, don't load whole notes):**
> - Load the skills `gauntlet-vault`, `gauntlet-build-style`, `gauntlet-model-joins`, then `blender-director`. LihFolk: `lihfolk-vfx` for the effects and `lihfolk-sfx` for the sounds.
> - `vault/02 Art/Skins/Arcade and Frostbite Handoff.md` (the line), `vault/02 Art/Skins/Arcade/Gun Brief.md` (the per-gun method, rules and gates: follow it exactly) and `vault/02 Art/Skins/Arcade/Build Ledger.md` (how Arcade went: scripts, effects, sounds, install). `vault/02 Art/Skins/Skin Build Pitfalls.md` is the gate.
> - Reuse the Arcade pipeline: `tools/blender/arcade/` (`arcade_lib.py`, `10_vandal.py`, `49_audit.py`, `20_review.py`, `53_export.py`, `30_sheet.py`). Make `tools/blender/frostbite/` the same way, with its own `frost_lib.py` palette. In-game effects follow `src/client/Util/ArcadeEffects.luau` + `Config/Arcade.luau` (named flat groups driven by Motor6Ds, client-only, cleaned up); sounds follow `Config/ArcadeAudio.luau` and the `arcade` bank in `AudioController`.
>
> **Rules that don't move:**
> - The stock contract is kept: every bone, locator, action and the stock `CharmLoop` (charms are the same on every gun). ADS stays clean (stock `*Sight*`, nothing new in the sight picture: check the ADS render). **No gaps anywhere** (culled magenta close-ups of every join, both sides and below). Faceted, never smooth; no Glass; joins buried 0.02+; ≤1.5× stock tris. Effects never on a moving bone unless meant to move with it.
> - Ice reads as **clean faceted crystal**, stylised like the rest of the game (Valorant-style, never photoreal, never cartoon). Glow is cold blue-white and small, not a neon sign.
> - Use the live Blender MCP on 127.0.0.1:9876 (confirm the PID and file), or an extra bridge (`tools/blender/start_bridge.py`) on a free port 9881–9883. Never ports 9100 / 9877 / 9700 (other projects' Blenders). Say which one you use before modelling.
> - Don't touch Studio until the owner says the Havoc is approved; then install it the Arcade way and test it **in the Range** (Locker → TRY IN THE RANGE), not in bot matches.
>
> **Done for this step:** the Frostbite Havoc at a self-grade of **9+** (lowest area counts) with every gate clean; a review sheet (hero, first person, ADS, close-ups); a short plan for the effects and sounds (what grows where, how long, the sound layers); renders shown to the owner. **Stop and wait for approval.** After a yes: install + effects + sounds on the Havoc, then the other 13 guns one at a time (or in parallel Blender instances), then the Knife.
>
> **Token-lean:** no whole-note reads over ~15 KB, no repeated full renders when a close-up answers it, short status lines. Plans and results go into `vault/02 Art/Skins/Frostbite/Build Ledger.md`. Commit small steps on `main` with exact paths only (never `git add -A` / `git add vault`), no push.
>
> If I attached a concept image, it's guidance only (charm mount and ADS are the same on every gun, and the ADS just has to look good). If there's no concept, write me a short ChatGPT image prompt for a Frostbite Havoc concept first, and wait.
