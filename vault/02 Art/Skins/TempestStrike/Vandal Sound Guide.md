# Tempest-Strike Vandal: sound guide (owner's Audacity + ElevenLabs pass)

2026-11-22. Every sound the Tempest-Strike Vandal plays, what it is now, and what to do with it. The owner designs the sounds (base recordings + ElevenLabs layers + Audacity). The Vandal session wires them in. Current foley and its CC0 sources: [Tempest Audio](Tempest%20Audio.md).

**The target:** clean, crisp, premium, Valorant-style designed punch (the project's gun-audio rule: punchy designed layers, not raw recordings, not cartoon). **Identity = a solid gun core with water and electricity on top.** The gun must still read as a Vandal in a fight: the skin layers decorate the shot, they never replace its punch or hide where it came from.

## The general recipe
1. **Base layer first.** Start from the current base sound (the pro-pack take the game uses now; the Vandal's are the pack's semi-auto rifle set: shots in `art-source/audio/ProPack/audition/semi_auto_rifle shots/` (`gun_semi_auto_rifle_shot_01–08`, `_shot_00_first_01`, `_shot_00_last_with_tail_01`, `_shot_00_tail_only_01`), handling in `.../semi_auto_rifle handling/`). It carries the mechanics and the punch.
2. **Character layers on top, thin and short.** A water layer (whip, snap, splash, swish) and an electric layer (crack, zap, fizz), each cut to the part you need, usually 30–150 ms.
3. **Align transients.** Zoom in and slide each layer so its attack starts 0–3 ms after the base's attack. Layers that start late smear the hit. If the mix gets thinner when you add a layer, its phase is cancelling: select it and use Effect → Invert.
4. **Carve each layer's lane with EQ** so they don't fight:
   - Base keeps the low end and the body.
   - The water layer gets a high-pass at about 400–800 Hz.
   - The electric layer gets a high-pass at about 2 kHz.
   - Only one layer may carry the sub (under 150 Hz): stacked lows turn to mud.
5. **Glue, then limit.** Mix down (Tracks → Mix → Mix and Render), add a gentle compressor, then a limiter at -1 dB.
6. **No reverb on shots or clicks.** The game plays its own room tail. Reverb goes only on tails and slow foley, and only a little.
7. **Variations.** Make several takes for anything that repeats (shots 6–8, foley 3). Vary the water and electric layers and the pitch by ±2–4 %, so no two shots sound identical.

### ElevenLabs prompt tips
- Ask for one isolated sound: "single", "isolated", "close-mic", "dry, no reverb", "no music", and give a short duration (0.3–1 s).
- Generate 4–8 versions and keep the cleanest. You usually only need its first 50–150 ms for a transient layer.
- Avoid prompts that drift to "magical"/"cartoon" or "laser" for the shot: that lands in sci-fi pew territory. Words that work: "pressurised", "whip", "crack", "snap", "splash", "static", "crisp", "punchy", "tight".

### Audacity settings that work
- Compressor: threshold -12 dB, ratio 3:1, attack 0.01–0.02 s, release 0.1 s, make-up gain on.
- Limiter: type "Soft limit", limit -1 dB, hold 10 ms.
- EQ: Filter Curve EQ (or Effect → High-Pass Filter at 12 dB/oct). Cut 250–450 Hz by 2–4 dB if it sounds boxy. A +2 dB shelf at 3–6 kHz adds crispness.
- Reverb (tails and slow foley only): room size 40–60, reverberance 30–45, damping 60, wet gain -12 to -18 dB, dry 0 dB.
- Fades: no fade-in on a transient (cut exactly at the attack); fade-out 20–60 ms on short sounds.

### Hand-over format
- WAV, 48 kHz, mono, 16- or 24-bit, peak -1 dBFS, no silence at the start.
- Match loudness by ear: put the stock shot in a track beside yours and compare.
- Put the files in `art-source/audio/tempest/owner/`, named `<slot>_NN.wav` (e.g. `fire_01.wav` … `fire_08.wav`).
- The Vandal session uploads them as solo sounds (no atlases), registers them in `Config/TempestAudio` and routes the Tempest Vandal's shots to them (the same way Ruin-Blighted's own shots are routed).

## Sound by sound
"Now" says what plays today. "Base" means the stock pro-pack take.

### Shooting (yours to make: the biggest win)
| Slot | When | Now | What to do | Length, takes |
|---|---|---|---|---|
| **fire** | every own shot (2D) | stock `gun_semi_auto_rifle_shot_01–08` | **Layer.** Keep base `shot_0N` at 0 dB. Add a **water crack** layer (−8 dB, high-pass 600 Hz, first 60–90 ms only). Add an **electric snap** (−12 dB, high-pass 2 kHz, first 40 ms; on about half the takes, for variety). Optional sub thump from one source only (low-pass 150 Hz, −6 dB). Compress + limit. No reverb. | 0.45–0.5 s, **8 takes** |
| **fireFirst** | first shot of a burst | stock `shot_00_first_01` | Same layers as `fire`, a touch heavier: water layer +2 dB, slightly longer (120 ms), so the first shot lands harder. | 0.5 s, 1–2 takes |
| **fireLast** | the shot that empties the mag | stock `shot_00_last_with_tail_01` | `fire` layers + the base's tail + a quiet **power-down** under the tail: water draining or a fizzling discharge, low-passed, −14 dB. It tells you you're empty without a beep. | ~2.5 s, 1 take |
| **tail** | room tail after every shot, faded by the next | stock `shot_00_tail_only_01` | Keep base tail. Add a faint **water shimmer / static hiss** bed (−18 dB, high-pass 3 kHz), reverb allowed (wet −14 dB). No transient at its start. | 2–2.5 s, 1 take |
| **fireFar** | what other players hear (3D) | stock shots | Make from your finished `fire` takes: low-pass 5 kHz, water and electric layers down another 6 dB, small room reverb (wet −16 dB). Enemies must still recognise a Vandal first. | 0.5 s, 4–8 takes |
| **dryFire** | trigger on empty | stock `dry_fire_01–04` | Layer a **tiny electric fizzle** (−10 dB, 80 ms) under the click. | 0.2–0.3 s, 3 |

**ElevenLabs prompts for the shot layers:**
- Water crack: *"a single sharp pressurized water whip crack, extremely short and punchy, close-mic, dry, no reverb, isolated"*
- Electric snap: *"one crisp electric static snap, very short, bright and tight, close-mic, dry, isolated"*
- Optional sub: *"a deep punchy low thump of a heavy water impact, very short, dry"*
- Power-down: *"a short electric charge fizzling out with water draining, quiet, close, 1.5 seconds"*

### Reload (I made foley; improve it or replace it)
| Slot | When | Now | What to do |
|---|---|---|---|
| **magOut** | the old mag leaves | stock `magazine_unload` click + Tempest `magOut` (splash + static fizz) | **Merge into one designed sound.** Base click at 0 dB, a bright water burst on the same frame (−4 dB, high-pass 500 Hz), a short static fizz tail (−12 dB). 0.4–0.6 s, 3 takes. Prompt: *"a small water burst splashing outward, crisp, close, dry, 0.4 seconds"* |
| **magForm** | water forms the new mag in the hand | Tempest `magForm` (a reversed splash rising) | **Replace or layer**: a rising water gather that ends in a soft "pop" as the mag solidifies. Prompt: *"water swirling and rushing together into a shape, rising, ending in a soft liquid pop, 0.5 seconds, close, dry"*. A reversed splash underneath works well. 0.4–0.5 s. |
| **magIn** | the mag seats | stock `magazine_load` + Tempest `magSeat` (zap + splash) | **Make it the satisfying beat**: base seat click at 0 dB, a **metal lock clack** (−3 dB), a tight **water slap** (−6 dB), a short **electric zap** tail (−10 dB). A tiny reverb (wet −18 dB) is fine. 0.4 s, 3 takes. Prompt: *"a heavy metal latch locking with a crisp click, close-mic, dry"* |
| **reloadSpin** | the barrel roll after the seat | Tempest `inspectRoll` pitched up | Optional new sound: a fast **water whoosh around an object** (−6 dB) over a quiet **electric hum swell**. Prompt: *"a quick swirling water whoosh spinning around, 0.5 seconds, close, dry"* |
| **rack** | charging handle (empty reloads, some draws) | stock `cock_01–05` | Layer a short **electric charge chirp** (−12 dB, high-pass 2 kHz) on the forward stroke. Prompt: *"a short electric charge-up chirp, very quick, crisp"* |

### Draw, inspect, aim, idle (I made foley; polish if you like)
| Slot | When | Now | What to do |
|---|---|---|---|
| **draw** | every equip | stock long-gun draw + whoosh + Tempest `draw` (water swish) | Fine to keep. To lift it: add a soft **metal shing** at the end (−8 dB). Prompt: *"a clean short metallic blade shing, bright, dry"* |
| **drawLock** | the plates lock as the draw lands | Tempest `drawLock` (zap + small splash) | Keep, or add a crisp **latch click** under it so the lock feels mechanical. |
| **inspect** (start) | inspect begins | stock `safety_switch` + Tempest `inspect` (water swirl + static) | Keep. Optional: a soft **electric hum swell** under the swirl (−14 dB). |
| **inspectRoll** | the barrel roll | Tempest `inspectRoll` (deep water whoosh) | Keep, or a richer **swirling whoosh** with a faint static crackle on top. |
| **inspectCatch** | hands catch the gun | Tempest `inspectCatch` (wet slap + spark) | Keep; add the base's light handling click (−6 dB) for weight. |
| **aimIn** | entering the sights | stock cloth + Tempest `aimIn` (soft high water swish) | Optional: a tiny **crystalline shimmer** (−16 dB). Keep it very quiet: it plays constantly. |
| **aimOut** | leaving the sights | stock cloth | Leave as it is. |
| **idleSurge** | the idle flourish | Tempest `inspect`, soft and high | Leave as it is (rare and quiet). |

### New sounds worth adding (optional)
| Slot | When | Idea |
|---|---|---|
| **impact** (Tempest shots on walls) | own shots landing on the world | Stock surface impacts still play. Add a quiet skin layer: tiny water splash + static zap, 0.3 s, 4 takes, about −10 dB under the surface sound. Prompt: *"a tiny sharp water splash with a quick electric zap, very short, close, dry"* |
| **vent** | the handguard vents flaring on each shot | Probably not needed (the shot covers it). If you want it: a micro metal "tick", −20 dB, on some shots only. |

Not part of this skin: hit, headshot and kill sounds (game-wide, and the headshot flare stays orange), footsteps, UI.

## Things to avoid (from the project's sound rules)
- Synth beeps, laser "pew", cartoon boings. The owner rejected synth layers on guns before.
- High dings or metal rings on anything that repeats fast.
- Long reverb on shots: the game adds the tail.
- Stacking two low-end layers (mud), and clipping (limit to -1 dB).
- A shot quieter or softer than the stock Vandal: the skin should feel stronger, never weaker.
