# Glitched Gauntlet ability rework

Implement the owner's playtest feedback on all nine Mods in the current match place. The owner rejected the v01 and v02 art direction. Start the new props and effects from scratch, then carry them through Studio import, rigging, animation, effect timing and runtime integration. Make the gameplay and input changes below and deliver playtest captures.

## Claude task routing

*Changed 2026-11-16 (owner, [follow-up](2026-11-16%20Ability%20Rework%20Follow-up.md)): good results on low usage.*
- **Opus 5.5 does almost everything:** the parent chat (it owns the brief, task boundaries, visual consistency, integration and final verification) and every fork and agent: props, Blender modelling, VFX building, animation, wiring, checks. Group Molly with Frost, assign Recon's bow and bolt together, and give Stim and Recall their own tasks. Each fork owns its source file, reviewed render and part and pivot notes; its brief names the files it owns and the stop condition.
- **Fable 5.2 only to lock things in:** one agent at a time, each with a tight brief (the question, file paths, renders or captures to judge, what "done" looks like). Use it for the shared effects language decided once for all nine Mods (layer kit, colour, timing, texture set), a final consistency review of all Mods before handing back, and a problem Opus has tried twice and can't crack. Never in parallel, never for routine work.
- **Haiku or Sonnet** for lookups (`vault-lookup`, `lihfolk-lookup`), bookkeeping and repeatable checks.
- **Lean:** no polling Studio in loops; captures only when something is being judged; grep plus ranged reads, not whole files. Report any model-routing limitation in the environment.
- **RIVALS study first:** before building each Mod's effect, read the closest RIVALS effect (skill `rivals-reference`, table in the follow-up) and write its layers and numbers into `vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md` → "Ability VFX". Numbers and recipes only: no RIVALS textures, meshes, trails, sounds or scripts in our game.
- The connected live Blender MCP server is the only Blender execution path. Author, edit, render, verify and export Blender assets through that live connection. Check the connection before Blender work and recover it if it drops. Use separate Blender files or scenes per fork and serialize scene mutations when forks share one live instance.

## Ground the work in the current build

- Read `CLAUDE.md`, the project vault and build-style skills, [Style Bible](../../02%20Art/Style%20Bible.md), [Mod System](../Mod%20System.md), and [Upgrade Paths](../../01%20Design/Abilities/Upgrade%20Paths.md). Use current source and the match place to establish the baseline. This brief takes precedence where the older design or art notes differ.
- Use the F8 Mod test panel and a second Studio client to capture the current holds, casts, impacts, deployed props and status effects. Prioritize the phases this brief changes. Compare gameplay changes on the same lane with the same camera angles and reproduce the observed bugs before fixing them.
- Preserve current slot assignments, upgrade identities and existing gameplay values except where the brief calls for testing or changing them. Keep gameplay tunables in config and preserve server validation. Use the normal movement and Mod input paths. Focus activation changes on desktop and defer a dedicated touch-controls redesign.

## Visual direction and asset workflow

- Build in Gauntlet's stylized tactical look. Use matte surfaces, big angled faces, carved transitions, a few accents and clear silhouettes at normal first-person scale. Props need readable grip and contact points. Give each effect a recognizable onset, readable active state and quick exit. Use shaped mesh layers and authored textures or flipbooks for the major beats. Keep the aim area clear and retain team and threat readability under different map lighting.
- Give each Glitch upgrade the identity of its mechanic. The firebomb split, ice wall, shield, healing field, decoy and teleport recovery should each read from their motion and shape. Treat purple neon and digital static as occasional accents. The owner is open to a small flicker on Fork Fire if it helps sell the split.
- Follow the asset interfaces described in `art-source/abilities/README.md`, `tools/blender/export_mods.py` and `tools/studio/abilities/`. Run Blender-side work through live MCP. Check meshes and materials in the match place at intended scale. Keep active Studio templates in `ReplicatedStorage.Abilities`. Trace the live model lookup and attachment names before replacing anything. Use the current first-person viewmodel and third-person pose paths for animation. Line up model releases, gameplay events and existing sound cues.
- Derive the art direction from the project's [build rules](../../../.claude/skills/gauntlet-build-style/SKILL.md) and the approved gun assets. Use the [Vandal](../../02%20Art/References/vandal-blender-check.jpg) and [Phantom](../../02%20Art/References/phantom-blender-check.jpg) as construction references for Recon. Use a few deliberate angled cuts and machined planes, mechanical joints with clear seats, strong silhouettes, and restrained inset details. Check hard surfaces for unintended overlap, floating trim and messy seams from both the player camera and observer angles.
- Treat the earlier Codex concept boards, Blender packs, FBXs, textures and VFX sheets as rejected review history. Build fresh designs. Keep Molly's separately animatable latch, pull pin and arming pad with named pivots or travel markers. Apply the same practical separation to the Frost latch and pin, and to Recon's bow limbs, string segments and bolt.
- For any uncertain prop, VFX texture or animation beat, prepare a short paste-ready ChatGPT image request that specifies the shape, material, silhouette, camera view, color and intended use. Ask for something reviewable such as a matched prop sheet, effect keyframes, or an isolated texture with alpha. Use concept images as reference. Check timing, geometry, UVs, texture edges and alpha in Blender and Studio before using an asset in-game.

Start gameplay and animation tracing in `src/shared/Config/Mods.luau`, `src/shared/Simulation/Abilities.luau`, `src/client/Controllers/ModController.luau`, `src/shared/Config/Viewmodel.luau`, and `tools/studio/MakeModAnimations.luau`. For effects and status, start with `ModFeelController`, `ModFxController`, `ModHudController` and the existing `src/client/Util/UpgradeFx/` modules. Check `BodyClone` and `MatchBody` for the skinned-limb fix, and `src/server/Services/Weapon/Damage.luau` and `WeaponController.onHitConfirm` for hit feedback.

## Q slot

### Updraft and Crash Down

- Keep base launch behavior. Replace the realistic screen wind with stylized tapered strokes that travel upward from the edges. Use the same graphic family as Dash with motion tuned to a vertical launch. Time it with the hand flick and the rise and fade it clear of the aim area.
- At G2/G3, a fresh **second press of the bound Updraft input (Q by default)** starts or queues Crash Down during the valid airborne window. The first press still launches. Prevent a held key, repeat, or second press from spending another launch charge. Update the move hint, card copy and any input paths that still advertise crouch. Check the normal launch, early queued press, late press, missed window, low ceiling, ledge and landing.
- Make Crash Down practical in a fight. Start with modest horizontal carry or limited steering and compare the current 8-stud hit area against a 10-stud trial. Playtest the existing G2/G3 damage (30/45) and a small increase if landing reliability improves but the hit still feels weak. Keep the final values open to iteration. Match the visual footprint and timing to the actual damage event and keep the existing enemy/sight checks.
- Rework anticipation, descent and impact in first and third person. Try a strong landing pose, a ground-hugging dust or pressure ring, chunky fragments and a short settling beat. Give the impact energy through motion and contrast with the ground.

### Stim and Heal Zone

- Keep the base zone visuals and buff behavior. Give the beacon a modest, visibly forward underhand toss. Tune the landing offset and arc together, and synchronize the held beacon's release with the world prop and deploy. Verify a clear cast on level ground and a sensible landing near walls and on slopes.
- Push the existing model toward a chunky faceted beacon with a wider base and a readable coil. Preserve enough of the silhouette that it still feels like Stim.
- Give Heal Zone a clear treatment of soft upward healing pulses. Reuse the **HEALING** status indicator specified under Heal Orb. Show it for the player's current healing source and clear it when that source ends.

## E slot

### Dash, Ghost and Desync

- Replace realistic screen streaks with sharply tapered edge strokes following the dash direction. Give Ghost a short edge shimmer or similarly restrained protection cue in place of the blue flash. Preserve readable protection timing.
- Tune L1 as a quick dodge that earns its slot beside sliding. Compare the current 12 studs with 16 and 18 over a similar burst duration, measuring travel and time to regain aim/fire in the same lane. Check lateral, backward and air use, and how it starts and ends beside slide-jumps. Keep wall stops consistent and retain visible progression in Long Dash if a new L1 baseline is adopted. Pick the shortest distance that feels decisive in a duel.
- Rebuild Desync's presentation around a complete, convincing moving copy of the current skinned match body. Reuse the live body-copy and limb attachment conventions as appropriate. Check silhouette, held weapon, run pose, upper-tier fake firing and expiry from another player's view.
- Fix player/dummy body blocking with collision groups on authoritative spawn and respawn paths. Cover real players, bots and range/dev dummies as applicable, including later body descendants. Keep world collision and hit queries working. The decoy remains a non-solid visual. Test moving through another character and then into a wall, plus damage and targeting on the dummies.

### Molly and Fork Fire

- Remake the first-person canister as a short, wide, faceted prop with a warm panel and a recognizable latch. Build the family alongside Frost and check both silhouettes in hand.
- Give throw and lob deliberate windup, a readable release and satisfying follow-through. Tune the throw feel against the existing server flight path. Check hand-to-projectile continuity, arc, wall bounce, floor burst, and first- and third-person timing.
- Keep the base patch recognizable and readable. Refine it with shaped flames and punchy ember bursts. Replace the realistic fire on burning players with short stylized flame licks that travel with the current body. Make Fork Fire's canister split, bouncing bomblets and smaller fire patches visually clear.

### Recon and Ping Spike

- Replace the held launcher with an original compact, angular recurve bow and a matching sensor bolt. Use Sova's draw and release as a feel reference for nock, draw, hold, release and settle. Animate the bowstring and the drawing hand in first person and give observers a matching pose. Use the existing projectile and stuck-dart lifecycle with the new model.
- Improve the charge and bounce UI and animate charge on the bow. Let right-click cycle 0/1/2 bounces **during the draw** with immediate feedback, continuous charge and the correct bounce count on release. Verify tap, partial and full draw, rapid cycling, cancellation and re-equip.
- Use a textured spherical wave around the bolt, with the visible edge readable from above and below. The server already checks 3D distance. Preserve that radius and the base pulse's line-of-sight rule, and use Ping Spike's existing through-cover behavior. Give the Spike one stronger, visually distinct pulse.
- Repair the ally-side enemy outline on the actual skinned match body. Verify the whole pose reads, including limbs. Make **DETECTED** clear to the victim using the existing revealed event and status tray or fallback. Check both pulses, Ping Spike, expiry, repeated scans and an elevated bolt in a two-client test.

### Heal Orb and Barrier

- Make the held pose a deliberate palm-up hold with light ribbons and motes that frame the orb. Improve the handoff to an ally and the self-cast gesture where needed. Keep the existing heal gameplay.
- Add a **HEALING** status shared by Heal Orb and Stim's Heal Zone. Drive it from actual active healing, including refresh and expiry. Verify it independently from the visual heal cue and the HP display.
- Keep the hex motif on Barrier's HUD. Refine the world shield's placement, material, hit reaction and break. Check first-person protection and spectator/enemy readability on the new match body. G2 and G3 should still clearly communicate their remaining protected hits.

### Recall and Crash Recovery

- Keep the current placement distance, teleport range, pickup reach and existing upgrades to range. Remodel the anchor as a faceted sturdy device with a recognizable core and readable facing.
- Re-key the teleport with Chamber as a reference for a quick, controlled hand motion. Bring the anticipation forward, use a crisp departure and arrival, and hand control back cleanly. Start from the current windup timing. If it still feels slow after the animation pass, compare a modestly shorter windup in playtest and record the timing and counterplay trade-off before adopting it.
- Give Crash Recovery its own recognizable departure and recovery beat. Verify placement, pickup, destruction, teleport and lethal recovery in-range and out-of-range.

## T slot

### Firewall and Frost Wall

- Make the fire curtain read as overlapping flame shapes with a rolling top edge and a strong rise from the floor. Keep its sight-blocking silhouette across the full built curve. Rework the ready flame in hand to match. Sharpen the hand push and guide pose so the cast and steering feel connected to the wall.
- Keep the existing Frost Wall behavior. Refine its angled ice plates, cold interior light and edge chips. Make it read as ice from both sides and at a distance. Check straight and steered fire and ice walls, edge coverage, build duration, active time and cleanup.

### Frost and Freeze Frame

- Remake the canister with a taller profile, pale faceted panels and bold cooling vents. Compare its silhouette to Molly's both in hand and in flight. Polish the throw trail and impact with a quick shard spray, a textured frost front and short-lived mist.
- Build the Freeze Frame shell around the player's pose. Give capture a clear buildup or snap and release a crisp shatter. Preserve the readable frozen-player view while improving the observer view. Check immobilization, expiry and cleanup when the player dies or respawns.

## Shared hit feedback and final verification

- For damage from abilities, keep the crosshair hit marker and suppress floating damage numbers. Use the authoritative damage source to route the feedback. Check all damaging Mods, including repeated ticks and kills, and preserve weapon feedback. Review position-based hit effects for covered targets and prevent the feedback from pinpointing a hidden enemy.
- First test one full prop/animation/effect loop and the shared rig, collision and HUD fixes. Reuse the established patterns for the rest of the roster. Play through L1 and every visually or mechanically distinct upgrade with the current loadout and draft paths. Check representative A/B levels, both Glitch tiers, re-equip and round/respawn cleanup. Compare player and observer views with two Studio clients.
- Deliver updated Blender and texture sources, import metadata and Studio backups, source/config changes and a review note in the vault. Include a before/after view of each ability, closeups of new props, short clips for motion-dependent changes, measured Dash/Crash Down trials, and any checks that still need the owner's playtest. Run the repo's normal formatting, lint and build checks on the changes and report results.
