# Break down a complex animation

## Define the motion before opening the curve editor

Write one line each for intent, biggest readable pose, support/contact, and what must stay planted or held. Mark the clip as in-place, motion-driven, or staged against a cinematic anchor. Identify the rig (including R6 versus R15), the axes and sign convention, the intended game speed, the camera, and any prop with limited clearance.

Use the reference as evidence. Match the aspects the brief calls for, such as the contact rhythms, while recording choices like a more relaxed torso or quieter arm. Document which comparisons are exact targets, approximate targets, or diagnostic. Never infer a hidden joint angle or depth from a single flat frame without recording the assumption.

## Block and layer

1. Mark the starting pose, anticipation, extreme, contact or action, follow-through, and recovery that apply. For a walk, start with contact, down, passing, and up poses for both legs. A two-character sequence also needs shared spacing and synchronized contact frames.
2. Build the hips, support, and balance first. Use stepped holds to judge silhouettes and weight shifts. Confirm where the center of mass stays over the supporting foot and how a heavy prop affects balance. Add torso pitch (lean), yaw (turn), and roll (side tilt) in a declared body space. Adjust shoulders and pelvis together for clear counter-rotation.
3. Set timing with key placement and spacing with the evaluated positions between keys. Slow in and out where the motion needs a settle. Preserve decisive contact, launches, or impacts using the spacing they require. A straight velocity curve can be right for deliberate constant movement. Ease body channels separately. If the hands, head, and hips all brake at the same instant, inspect whether the motion needs overlap.
4. Track wrist and ankle arcs in useful space. Add follow-through only after contacts behave. Use IK or explicit contact keys where hands and feet must hold, then inspect the release, limb reach, elbow or knee direction, and clipping. In a two-actor shot, solve both performers around the same contact anchor before layering motion.
5. Layer locomotion, upper-body action, facial detail, camera, props, and VFX according to their actual ownership. Remove accidental keys on joints that belong to another track. Use markers or the shared cutscene clock for animation-synced effects. Confirm cancellation restores controls, state, and effect windows.

## Sample and diagnose

Use the same frame rate or resample into a common normalized phase grid with labeled landmark events. Sample in the same axis and space. Use signed angular channels with a consistent forward convention. Before interpreting angular curves, unwrap discontinuities or use rotation comparisons appropriate to the rig. Record hip height from a declared baseline, hand height relative to its shoulder, planted feet relative to floor or moving platform, and root forward travel separately. For an in-place cycle, keep raw root travel visible and compare only against its intended drift target. Across rigs, normalize translation to a known scale where raw studs have different meanings.

| Symptom | First check |
| --- | --- |
| Looks stiff | Compare key poses in silhouette, then inspect spacing and overlap between linked body channels. |
| Matches the pose but feels off | Align at the same contacts and compare acceleration and recovery, not just peak displacement. |
| Foot slides or floats | Use foot positions during contact and compare actual movement speed with the authored cycle. |
| Prop jumps or twists | Sample its world anchor and direction at the handoff and during held contact. |
| Torso appears to snap | Inspect rotation wrap, tangents, and runtime layer conflicts before smoothing the curve. |
| Effect feels late | Compare visible contact frames with authored markers and observed effect events in one clock. |

Generate the curve report with `check.py motion.json --report motion.html`. Review the traces alongside matched playback. Select the worst unintended difference, change the responsible pose, timing, tangent, or layer, then resample the same channels. Use the specific tools for phase retiming, easing, loop seams, contacts, cue timing, and rate fit as needed.

[Roblox Animation Editor](https://create.roblox.com/docs/animation/editor) · [Curve Editor](https://create.roblox.com/docs/animation/curve-editor) · [AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
