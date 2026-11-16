# Ability VFX direction (2026-11-15 rework)

The shared effects language for the nine Mods. It replaces the look the owner rejected in playtest ("realistic" screen wind and streaks, realistic fire on players, glitch static on everything). Brief: [2026-11-15 Ability Rework](../04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md). Plan: [Ability Rework](../05%20Production/Ability%20Rework%202026-11-15.md). It sits under [Style Bible](Style%20Bible.md) §4 (shapes over particles, stylised like Valorant, sprites under the Bloom threshold).

## The one rule
**Each element is recognisable from its motion, shape and timing alone**, in grey, with the sound off. Colour and glitch come after that.

## Grammar shared by every effect
1. **Shapes first.** Every big beat is a mesh or an authored flat shape with a designed outline (pointed, cut, faceted: the prop style carried into the effects). Particles are only the debris of a shape: few, big, short.
2. **Three beats.** Onset in 0.1 s or less (a snap), an active state that holds still enough to read, an exit in 0.3 s or less. Anticipation belongs to the animation, not the effect.
3. **Stepped motion.** Flames, chips and strokes move on held frames (12 to 15 a second) rather than smooth drift. Smooth drift is what read as "realistic".
4. **Screen effects live on the edges.** The middle 40% of the screen (the aim area) stays clear in every state.
5. **Team colour on the gameplay line, element colour on the body.** Rings, danger footprints and reveal outlines use the game's team colours (`client/Util/TeamColor`: ally cyan, enemy orange-red). Fire is fire-coloured and ice is ice-coloured for everyone.
6. **Glitch is an accent on Glitch levels only:** one or two frames where the effect's own shape is doubled and offset with a magenta edge. No pixel static clouds, no screen tear, no purple wash.

## Element signatures
| Element | Mods | Shape | Motion | Timing | Colour |
|---|---|---|---|---|---|
| Wind | Dash, Updraft | Tapered strokes: long thin wedges, pointed at both ends | Travels straight along the move; exits by shortening from the tail | In 0.05 s, gone in 0.25 s | Off-white, faint cool tint |
| Fire | Molly, Firewall | Flame tongues: hooked blades in 3 value bands (deep base, orange body, pale core), overlapping | Rises from the floor, top edge rolls and curls; stepped | Ignite 0.12 s with a burst, steady burn, sink 0.3 s | Red-orange to pale yellow |
| Ice | Frost, Frost Wall, Freeze Frame | Angled plates and prisms with chipped edges, cold light inside | Snaps out with a small overshoot, then **does not move**; exits by cracking and dropping chips | Out in 0.1 s, still, shatter 0.2 s | Pale blue-white |
| Healing | Heal Orb, Heal Zone | Soft leaf / chevron shapes and ribbons | Slow upward drift, ease-out, a gentle pulse about once a second | Soft in 0.2 s, soft out 0.4 s (the only slow element) | Green-teal `5CFFC8` |
| Teleport | Recall | A vertical fold: the body pinches to a line, a ring snaps in; the reverse on arrival | Symmetric in and out, no travel between | Depart 0.12 s, arrive 0.15 s | Violet `9B6BFF` |
| Scan | Recon | A thin spherical shell with a banded edge | Expands at constant speed | Radius / speed, fades at the edge | Team colour |
| Impact | Crash Down | A ground-hugging pressure ring, chunky floor fragments, a dust skirt | Ring races out flat, fragments pop up and settle | Ring 0.25 s, fragments 0.6 s, a settle beat | Floor colour + team ring |
| Shield | Barrier | Hex shell (kept) | Ripple from the hit point, plates fall away on break | Hit 0.2 s, break 0.35 s | Team colour |

## Per effect: what changes
- **Updraft launch (caster):** the realistic screen wind goes. Tapered strokes rise from the bottom corners and sides to the top, timed with the hand flick and the rise, gone before the peak.
- **Dash (caster):** the radial streak cloud and the blur go. A few sharply tapered strokes on the edges, pointing along the dash. Ghost: a short shimmer on the screen edge for the protection window (no blue flash).
- **Crash Down:** an anticipation tuck, a dive with two or three long strokes (the wind family, vertical), then the impact row above. The ring's footprint is the damage radius and lands on the damage event.
- **Molly:** shaped flames and ember bursts on the patch; burning players carry a few short flame licks that ride the body (no realistic fire emitter); Fork Fire shows the canister splitting, with a single flicker on the split.
- **Firewall:** overlapping tongues with a rolling top edge and a strong rise from the floor; the hand flame matches. **Frost Wall:** angled plates, cold interior light, chipped edges, reads as ice from both sides.
- **Frost:** shard spray, a frost front with texture, short mist. **Freeze Frame:** a shell built around the pose, a snap on capture, a crisp shatter.
- **Recon:** a textured spherical wave readable from above and below; Ping Spike gets one stronger, different pulse. The outline goes on the real skinned body.
- **Heal Orb:** ribbons and motes that frame the orb in the palm; **Heal Zone:** soft upward pulses. Both show the HEALING status.
- **Recall:** the fold in and out; Crash Recovery gets its own departure and recovery beat.

## Review method
Every important effect is judged in motion from the caster's view and from another player's view, in the test range, with a slow-motion freeze (`VfxTimeScale`) for captures. An effect passes when the element can be named from a greyscale capture.
