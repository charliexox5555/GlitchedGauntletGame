# Gun feedback, round 2 (user playtest, 2026-10-26)

The user's hands-on notes after round 1, turned into a checklist. Two sessions work it: **Blender** (models + gun clips) and **Studio** (game systems). Tick items off here as they land, with the commit hash, so the work can resume after a usage-limit pause. Goal in the user's words: "more professional, and interaction guns that look good, feel good and leave the player feeling satisfied."

References: ADS `02 Art/References/ads-refs/` (open ring aperture + post, see-through, RIVALS/Hypershot style), Valorant hold `02 Art/References/rivals-viewmodel/valorant-vandal-hold.webp`.

## Studio (game systems)
- [ ] **Draw on every equip/switch**, not only the first pull-out (e.g. secondary → primary). All guns.
- [ ] **Mag drop**: on every mag reload the old mag falls to the floor (physics prop, pooled, despawns) and a new one goes in; the old one never goes back in. All mag guns.
- [ ] **Muzzle flash**: the Phantom's flash is still inside the suppressor; fix it for real. Suppressed/muzzle-device guns get a **subtle grey puff** (Valorant), not the red/orange flare.
- [ ] **Framing too close**: Stinger (hold and inspect), Spectre, Bulldog (can't see its reload). Audit every gun so the whole gun reads in hold, reload and inspect.
- [ ] **Secondary hold redesign**: Classic, Ghost, Sheriff, Shorty, Akimbo look odd (no hand on the trigger; the inspect doesn't look held). Rework the pistol pose (and the hand shape if needed) so a small gun looks gripped.
- [ ] **Akimbo**: hold, sprint, inspect, reload and draw work one gun at a time, left and right, never overlapping.
- [ ] **Knife system**: Valorant-style slash combo 1 → 2 → 3 (sequenced, with timing), right-click two-handed heavy stab, wall marks (decals) and a different wall-hit sound, a proper knife hold, a plain default inspect (no whole-hand spin). Better placeholder sounds.
- [ ] **Per-shot action playback**: Ares and Judge cycle their action on every shot (like the Vandal); guns with an action cock it on draw.
- [ ] **Partial reloads**: Outlaw reloads only the spent chamber(s) (1 or 2); Bucky loads shell by shell from the bottom (interruptible). Satisfying shell sounds (placeholders in GunSounds).
- [ ] **ADS overhaul**: open, see-through classic irons (RIVALS/Hypershot) on every ADS gun once the Blender session redesigns the sights; re-align the ADS camera per gun. The Bulldog ADS "looks really bad". The user has more ADS notes coming.

## Blender (models + clips)
- [ ] **Thickness pass**: bodies too thin. Widen (gun-left/right axis) and re-proportion: **Outlaw** (most, redesign), Odin, Judge, Akimbo, Classic, Ghost, Shorty, Guardian, Operator, Ares (slight); check every other gun against the Vandal. **Marshal stays slim** (the user likes it).
- [ ] **Shorty redesign**: a regular sawed-off **side-by-side double-barrel** shotgun.
- [ ] **Open iron sights** on every ADS gun (Vandal, Phantom, Stinger, Spectre, Bulldog, Guardian, Ares, Odin): a thin ring aperture or notch at the rear and a post at the front, see-through, not enclosed boxes.
- [ ] **Actions that move**: every gun with an action cocks it on Draw (Guardian, Ares… audit all). Per-shot cycling on the Ares; **Judge gets a new top action** that cycles every shot and on draw; **Bulldog** gets a working side charging handle like the Vandal.
- [ ] **Mag-drop-ready reload clips**: the old mag leaves quickly downward (the game spawns the falling copy), and the new mag comes up from below.
- [ ] **Outlaw reload** (Valorant-style): breaks fully open, pulls the shells, loads only the spent one or both (clips for 1 and 2).
- [ ] **Bucky reload**: rolls the gun and feeds shells from the bottom one by one (shell-in loop clip).
- [ ] **Marshal reload**: cleaner shell insertion. (The "second barrel" is the tube magazine under the barrel, which is intentional.)
- [ ] **Akimbo clips**: one gun at a time.
- [ ] **Knife clips**: Slash1 / Slash2 / Slash3, HeavyStab (two hands), a default-style Inspect.
- [ ] Re-bake, re-export and upload each changed gun, then hand it to the Studio session.
