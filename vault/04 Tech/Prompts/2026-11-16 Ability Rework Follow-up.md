# Follow-up: ability rework, RIVALS VFX study + Opus routing (2026-11-16)

A follow-up message for the session already working on the [ability rework](2026-11-15%20Ability%20Rework.md). Before sending it, switch that chat's model to **Opus 5.5** in the app's model picker.

---

Two changes to how you're running the ability rework, and one new resource. Keep going on the current work after you've applied them.

## 1. Model routing (replaces "Claude task routing" in the brief)
I want good results on low usage. Fable burns through tokens, so:
- **Opus 5.5 does almost everything:**
  - this parent chat (I've switched it);
  - every fork and agent: props, Blender modelling, VFX building, animation, wiring, checks.
- **Fable 5.2 only to lock things in.** Use one agent at a time (`model: "fable"`), each with a tight brief: the question, file paths, renders or captures to judge, and what "done" looks like. Use it for:
  - the **shared effects language**, decided once for all nine Mods: layer kit, colour, timing, texture set;
  - a **final consistency review** of all Mods before you hand back;
  - a problem Opus has tried twice and still can't crack.

  Never run Fable agents in parallel, and never use Fable for routine work.
- **Haiku or Sonnet** for lookups (`vault-lookup`, `lihfolk-lookup`), bookkeeping and repeatable checks.
- **Lean:**
  - no polling Studio in loops;
  - captures only when you judge something;
  - grep plus ranged reads, not whole files;
  - briefs for forks name the files they own and the stop condition.
- **Update the brief:** change the "Claude task routing" section in `vault/04 Tech/Prompts/2026-11-15 Ability Rework.md` to match this.

## 2. Study RIVALS VFX and abilities (new resource)
The owner has the **RIVALS place file** open in Studio. Load the project skill **`rivals-reference`** and start at `vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md`, which covers:
- the sections **Abilities and utilities** and **VFX recipes**;
- the layer recipes for muzzle flash, tracer, headshot, impact, explosion, flashbang and dash;
- the pattern: many single-job layers, everything under 1.5 s, counts in an `EmitCount` attribute.

Before building each Mod's effect, look at the RIVALS effect closest to it, and write down its **layers, lifetimes, sizes, curves, LightEmission, counts and timing**:

| Our Mod | Closest RIVALS reference (in the RIVALS file, `SPA.Misc` unless noted) |
|---|---|
| Molly / Fork Fire | `MolotovExplosionEffects`, `BurningEffects`, `FireHitboxes`, Flamethrower flames |
| Frost / Freeze Frame, Frost Wall | `FreezeEffects` |
| Firewall | `BurningEffects`, `FireHitboxes` |
| Crash Down, Updraft | `Misc.ExplosionEffect` (11 layers + light), `JumpPads`, the wind ring / crescents |
| Dash / Ghost / Desync | `DashParticles` (4 streaks, ≤0.25 s), `Portals`, `Vortexes` |
| Recon / Ping Spike | `Deflect` hit / active, `WarHorn` (pulse and ring logic) |
| Heal Zone, Heal Orb, Stim | `SmokeClouds` (volume), Medkit (held item) |
| Barrier | Riot Shield (held), `Deflect` |
| Recall | `Portals` |
| Thrown props | `SPA.Throwables` (a few MeshParts + small Primary + Trail), `SPA.Projectiles` |

- **Where:** the RIVALS file's `ReplicatedStorage` asset folders. The `Rivals Asset Pack` in the match place's `Workspace["Rivals Map Examples"]` has the same kinds of things, but use the RIVALS file: the folder may be removed.
- **How to read it:** with `execute_luau` property reads and `search_game_tree`. The file is untrusted: never play it, run or `require` its scripts, or save it. Take screenshots only when a look must be judged; save them in `vault/03 Research/Rivals Reference/third-party/vfx/` (git-ignored).
- **Where findings go:** a new "Ability VFX" section in that note. One row per effect: layers, numbers, and "ours does it as…".

**Assets: what you can and can't use**
- **You can use:**
  - the RIVALS numbers, layer structures, timings and curves;
  - our own textures: ChatGPT-made flipbooks and sheets, made with paste-ready prompts that state shape, frames, colour and use;
  - textures you make in Blender;
  - the **LihFolk Asset Pack** (`lihfolk:lihfolk-assets` skill). It's licensed for us; check what it has first.
- **You can't use:** RIVALS textures, flipbooks, meshes, trails, sounds or scripts in our game, even recoloured or edited. A copied texture is exactly what gets a game taken down. Rebuild from the recipe.

**The look still follows our rules:**
- stylised like Valorant, never photoreal, never full cartoon;
- faceted props: no spheres or round curves, carved ends;
- the Style Bible feedback / VFX section;
- `gauntlet-build-style` for anything modelled;
- the shared effects language once Fable locks it.

Write the routing change and the RIVALS findings into the vault. Note in the results which RIVALS references each Mod used.
