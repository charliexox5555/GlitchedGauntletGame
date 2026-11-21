# Tempest-Strike Vandal: overnight plan (2026-11-21 → 22)

Owner (going to bed): "the VFX look a bit off and don't move well: when you shoot they move out, not attached to the gun; same with the reload. The lighting needs improvement, the loop looks off. It needs more, this is a premium skin. Overnight: make everything look good: ADS, VFX, reload, shooting, muzzle flashes, idle / shooting / reload / inspect animations. Do your own grading and checks, then report back." Permissions given: ChatGPT app (computer use + clipboard) for textures, uploads to the group, play-test and save the match place. Resume at 5:10 if usage runs out.

Rules: our own designs (the owner's concept: shuriken flash, laminar water, hydro-core round), stylised like Valorant but never copied; custom motion and sound first person only (locked); build on the Ruin-Blighted runtime (ShadowMistActions / ActionFx / Idle); tuning numbers in `Config/SkinPreview.luau` → `TEMPEST`.

## Status (update as items land)
1. [x] Effects ride the gun (attach to the Root-bone part, not the Handle), verified while firing and reloading.
2. [x] Textures from the ChatGPT app (`art-source/vfx/tempest/raw`): water ribbon, droplets, shuriken flash front/side, lightning arcs, splash, static mark, water tracer; cleaned, uploaded, ids in `Config/VfxTextures.luau`.
3. [x] Idle, premium: water ribbon texture, better light, the stock ring redone or removed, vent arcs visible.
4. [x] Shooting: shuriken muzzle flash, mist droplets from the brake ports, cyan water tracer, splash impact + static mark; skin recoil feel.
5. [x] Reload: magazine dissolves to water, water forms the new magazine, cyan pulse on seat (on the stock reload markers).
6. [x] Draw and inspect: water ring runs down the barrel on draw; inspect with a water ring and arcs.
7. [x] ADS polish (crescent read, effects clear).
8. [x] Checks (play-test captures, cleanup on interrupt, low graphics), self-grade, save the place, commit, report.

## Log
- **Attach fix:** idle anchors were on the Handle; the stock rig drives everything through Handle → `Root` motor → `Root` part, so recoil / reload / inspect left the effects behind. Anchors are now converted into the `Root` part's space at build time (`TempestIdle.rootBody`). Verified while firing: helices stay on the gun.
- **Textures:** ChatGPT app made eight original greyscale textures from my prompt (preview `art-source/vfx/tempest/raw/preview_sheet.png`): water ribbon, droplets 2x2, shuriken flash front 2x2 and side 2x2, lightning arcs 2x2, splash 2x2, static mark, water tracer. Uploaded as group decals, Image ids resolved in Studio, registered as `TEMPEST_*` in `Config/VfxTextures.luau`.
- **Shot (Util/TempestFx):** shuriken front flash + side spear (flipbooks, random frame, 0.055 s), port mist droplets, cyan light pop at the stock fast-gun level (1.6; a brighter pop bloomed the view), cyan tracer tint, impact splash crown + droplets + a static crackle decal that fades after 0.7 s. Captured mid-burst: crisp star at the muzzle, helices stay on the gun.
- **Idle v2:** textured water ribbon (width 0.072, full opacity) over a thin solid core, lightning-arc flipbooks on the receiver cowl / handguard top / handguard blade (rate 2.2), Neon conduits breathe toward a brighter cyan, softer wider rim light; stock ring removed (owner: "the loop looks off").
- **Capture gotcha:** using the ChatGPT app minimized Studio; a minimized Studio renders white in captures. Restore it from the taskbar thumbnail before judging.
- **Action layer (Util/TempestIdle, tuning in `TEMPEST`):** one module now owns idle, shot, reload, draw and inspect for the camera gun.
  - *Reload:* the old mag bursts into water where it is (no drop copy), the conduits drain to a dark teal while it is out, a cyan water loop gathers and tightens at the magwell (measured mouth, Handle (0, 0.12, -0.6)), water bursts where the new mag appears, and on the seat (the mag's last moving frame) a droplet burst + conduit flare + a small upward pop.
  - *Draw:* the gun rolls in 24 deg and snaps level with a little overshoot (easeOutBack) while a water ring runs from the muzzle down to the receiver; the plates flare as it locks.
  - *Inspect:* a water ring sweeps from the muzzle back over the receiver and returns, arcs fire 3x faster, the gun floats up a touch and rolls gently.
  - *Shot:* small skin kick on top of the stock recoil (snap in 40 ms, alternating roll, damped at ADS) and a conduit flare per shot; faint hover at idle. Reduced motion stops the scroll, sparks and hover.
- **Fixes from captures:** ring was grey-white (white edge colour on short segments) → pure water cyan + a solid core; droplets too faint → bigger and longer; ribbons at full ADS sat on the front post → 0.2 opacity.
- **Checks:** reload interrupted by a weapon switch leaves the mag visible and the ring off; one set of effects per equip (131 instances, no growth); no script errors in Output; ADS window clear (crescent + post). Match place saved (version 953).
- **Self-grade:** 8.5 / 10. Strong: shot flash, water reload story, draw ring, ADS window. Still short of 9-10: no skin-specific sounds yet (first-person water / static layers), and the overlays ride the stock clips rather than custom keyframed idle / inspect / reload tracks (the Ruin-Blighted hero has its own tracks). Next pass: audition water foley, then custom tracks if the owner wants them.
