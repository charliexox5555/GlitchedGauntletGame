# Prompt: Make the Rest of the Guns (matching the master rifle)

**How to use:**
1. Use the same chat or session that made the rifle, so it can see the rifle's file.
2. Attach the screenshot `vault/02 Art/References/bitrate_master.webp` ([view](References/bitrate_master.webp)).
3. Paste everything in the box below.
4. Approve each gun before it moves on to the next. Don't let it batch all 22 at once: quality drops and mistakes copy forward.

```text
The rifle we just finished is BITRATE, the MASTER REFERENCE for the whole weapon set (screenshot attached). Every new gun must look like it was made by the same artist, for the same game, on the same day. Same style, same materials, same level of detail, same units and orientation. Do NOT restyle anything; extend the set.

=====================================================================
1. STYLE RULES (taken from Bitrate, follow exactly)
=====================================================================
- Stylized hard-surface, chunky but clean. Rounded bevels on every edge, angular chamfered cuts on front faces, big readable shapes, no tiny greebles, no grime, scratches or logos.
- TWO-TONE body:
  * Upper/main panels: slate blue-grey with the subtle cyan circuit-trace pattern Bitrate's receiver has.
  * Lower receiver, grips, magazines, barrels, suppressors, buttpads: near-black dark gunmetal.
- CYAN NEON (#00E5FF) as glowing emissive, always in these forms only:
  * long thin horizontal lines along major panels (1–2 per panel)
  * rounded "pill" vents in a row (like Bitrate's 4 handguard pills)
  * segmented bars on magazines (like Bitrate's mag)
  * one ring around the muzzle/suppressor
- GOLD/YELLOW accent: ONLY the trigger and one small lever (charging handle or mag release), like Bitrate.
- MAGENTA (#FF3DCB) emissive: ONLY on optic lenses and on WILDCARD guns' energy parts (wildcards are "exotic" and get magenta energy cores in addition to cyan).
- Shared hardware: same black notched top rail and same flip-up ring iron sights as Bitrate wherever a gun has a rail.
- Every gun has the same small CHARM LOOP at the back of the receiver (where Bitrate's hangs), for cosmetic charms later. Don't model a charm, just the loop.
- Reuse Bitrate's parts as a KIT where they fit (trigger and guard, pistol grip, rail, iron sights, pill vents, neon strip profile, buttpad) so the set is consistent. Rescale them, don't redesign them.

=====================================================================
2. SCALE, ORIENTATION AND TECH RULES
=====================================================================
- Same units, same forward direction and same "upright" as Bitrate. Bitrate's length = 1.00 = 3.8 Roblox studs.
- Lengths below are relative to Bitrate (overall length, muzzle to buttpad). Heights should feel proportional: sidearms are slimmer, machine guns bulkier.
- Origin/pivot of every gun = the pistol grip, at the same spot relative to the grip as on Bitrate.
- Triangle budget: sidearms ≤ 3,000; primaries ≤ 5,000; machine guns and wildcards ≤ 6,000.
- Materials, with exactly these names on every gun (so Roblox skins can swap them):
  Body_Panel (slate blue-grey with circuit trace), Body_Dark (near-black), Metal (barrel and inner parts), Neon (cyan emissive), Accent (gold), Lens (magenta emissive).
- Keep ALL neon geometry as separate mesh pieces using the Neon material.
- Name parts: Body, Barrel, Mag, Sight, Neon, Trigger, Stock (where present). The magazine must be its own object (it gets animated during reloads).
- Add empties/locators named: Muzzle (bullet exit point), RightGrip, LeftGrip (where the support hand goes), AimPoint (center of the sight), Eject (shell ejection point), CharmPoint (the charm loop).
- One collection per gun named exactly as the gun (e.g. "Byte"). Export each as its own FBX.

=====================================================================
3. SILHOUETTE RULE (most important)
=====================================================================
A player on a phone must recognise every gun from its BLACK OUTLINE ALONE. Every gun below has a SIGNATURE feature. Exaggerate it. If two guns' outlines look alike, change the newer one.

=====================================================================
4. THE GUNS (build in this order; wave 1 first)
=====================================================================
Format: NAME (class, tier), length relative to Bitrate. Signature. Details.

--- WAVE 1 ---
1. BYTE (default pistol, T1), 0.37. Signature: thick squared slide, very simple, friendly. Neon line on each side of the slide, short squared barrel shroud, chunky grip with segmented neon on the mag base, gold trigger. Small rail stub, no iron-sight rings (simple notch sight).
2. ROOT (heavy revolver, T1), 0.50. Signature: big hexagonal cylinder ringed in neon. Long heavy top-ribbed barrel, hammer shaped like a cooling fin, wide curved grip. Feels heavy.
3. BANDWIDTH (SMG, T2), 0.60. Signature: short and boxy with a stubby suppressor shroud. Vertical foregrip, long straight mag in front of the trigger with neon segments like signal bars, folding stub stock. Pill vents (3) on the shroud.
4. HARD RESET (pump shotgun, T2), 0.84. Signature: thick wide barrel with a big square muzzle + oversized pump grip. Neon grooves on the pump, shells shown as 4 glowing cells on the side, heavy rounded stock.
5. LONG POLL (light bolt sniper, T2), 1.10. Signature: long thin barrel + big rectangular digital scope (magenta lens). Slotted muzzle brake, chunky bolt handle, skeleton stock like Bitrate's but longer, neon line along the barrel.
6. FLOOD (heavy machine gun, T3), 1.20. Signature: triple-barrel rotary cluster + big side ammo drum. Neon cooling coil around the barrels, glowing drum window, top carry handle, front stabilizer grip. Bulkiest gun in the set (1.4× Bitrate's height).
7. RAY TRACE (railgun, WILDCARD), 1.15. Signature: two parallel rails instead of a barrel with a magenta energy core visible between them. Magenta capacitor cells along the body, open-frame stock. Should NOT look like any real gun.
8. CUTTER (melee energy blade), 0.42. Signature: dark angular handle + glowing cyan hard-light edge on a dark blade spine. Finger guard, gold accent on the guard. No charm loop.

--- WAVE 2 ---
9. SPLINTER (pocket shotgun, T1), 0.32. Signature: two stacked fat barrels on a tiny body. Over-under, break-action hinge, stubby grip, neon ring on each barrel.
10. FLICKER (machine pistol, T1), 0.42. Signature: long extended mag sticking far below the grip + small folding front grip. Compact slide, neon line, mag with segmented neon.
11. MUTE (suppressed pistol, T1), 0.45 incl. suppressor. Signature: sleek slide + long fat suppressor (about half its length). Smooth and quiet-looking, minimal neon (one thin line), magenta dot sight.
12. BURST BUFFER (burst SMG, T2), 0.63. Signature: top-mounted horizontal magazine lying along the top of the gun (P90-style placement but our shapes). Bullpup body, neon "3-dot" burst indicator on the side.
13. CRASH (auto drum shotgun, T2), 0.80. Signature: huge round drum magazine under the body. Short wide barrel, vertical grip, drum with a glowing spiral or window.
14. PULSE (burst rifle, T2), 0.95. Signature: tall angular body with a top carry-handle sight. Three neon dots showing the burst, short barrel, compact stock. Simpler than Bitrate.
15. CHECKSUM (marksman rifle/DMR, T2), 1.05. Signature: long slim body with a medium scope + long thin magazine. Bipod folded under the handguard, neon line along the handguard.
16. OVERWRITE (heavy assault rifle, T3), 1.03. Signature: heavier, angrier Bitrate. Bigger angular muzzle brake (no suppressor), taller receiver, thicker mag, bigger pill vents. Must look clearly different from Bitrate in outline: brake instead of suppressor, solid stock instead of skeleton.
17. HANDSHAKE (double-shot sniper, T3), 1.05. Signature: two side-by-side barrels with a break-action hinge + big scope. Glowing neon on both muzzles, a chunky lever.
18. KERNEL (heavy one-shot sniper, T3), 1.30. Longest gun. Signature: enormous scope + very long barrel + huge muzzle brake. Bipod, big bolt, heavy stock with cheek rest, neon along the full barrel.
19. OVERFLOW (light machine gun, T3), 1.12. Signature: box magazine hanging under the body + carry handle. Bulky receiver with a heat-shield top, pill vents on the barrel shroud, folding bipod.

--- WAVE 3 (WILDCARDS) ---
20. LOOPBACK (disc launcher), 0.80. Signature: large circular disc visible in a top slot, ringed in magenta. Wide flat muzzle, spinning-disc motif, no real-world look.
21. DUAL BOOT (twin pistols), 0.40 each. Signature: a matching left and right pair of Byte-like pistols with mirrored magenta details, exported as two separate guns ("DualBoot_L", "DualBoot_R").
22. NULL (beam gun), 0.90. Signature: open coil emitter at the front with a floating magenta energy orb. Battery pack with a glowing level meter, smooth rounded body.

=====================================================================
5. WORKFLOW
=====================================================================
For EACH gun, one at a time:
1. Build it.
2. Render or screenshot (a) a side view and (b) a LINEUP with Bitrate next to it at true scale.
3. Show me a black-silhouette version of the side view next to Bitrate's silhouette.
4. List the triangle count and confirm the material names and empties.
5. STOP and wait for my OK or changes before starting the next gun.

=====================================================================
6. REFERENCES (style direction only, never copy a design)
=====================================================================
- Bitrate (attached): the ONLY reference for materials, colours, detail level and parts.
- Overwatch's stylized weapons: exaggerated forms, guns readable from their silhouette, big shapes over small details, lighter convex edges.
- RIVALS (Roblox) weapons: chunky, clean, readable on phones.
- Nerf blasters: bold toy-like shape blocks.
- Tron: Legacy: neon lines on dark surfaces.
Do NOT use or imitate Valorant weapons or skins (e.g. Glitchpop).
```

## Size lineup at a glance (Bitrate = 1.00 = 3.8 studs)

| Gun | Length | Studs |
|---|---|---|
| Splinter | 0.32 | 1.2 |
| Byte | 0.37 | 1.4 |
| Dual Boot (each) | 0.40 | 1.5 |
| Flicker | 0.42 | 1.6 |
| Cutter | 0.42 | 1.6 |
| Mute | 0.45 | 1.7 |
| Root | 0.50 | 1.9 |
| Bandwidth | 0.60 | 2.3 |
| Burst Buffer | 0.63 | 2.4 |
| Crash | 0.80 | 3.0 |
| Loopback | 0.80 | 3.0 |
| Hard Reset | 0.84 | 3.2 |
| Null | 0.90 | 3.4 |
| Pulse | 0.95 | 3.6 |
| **Bitrate** | **1.00** | **3.8** |
| Overwrite | 1.03 | 3.9 |
| Checksum | 1.05 | 4.0 |
| Handshake | 1.05 | 4.0 |
| Long Poll | 1.10 | 4.2 |
| Overflow | 1.12 | 4.3 |
| Ray Trace | 1.15 | 4.4 |
| Flood | 1.20 | 4.6 |
| Kernel | 1.30 | 4.9 |
