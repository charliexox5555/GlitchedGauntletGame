# Exotic bundle concept handoff

Produce the complete offline concept pass for **Spindrift, Kilnlock, and Stacklight**. The owner has authorized you to make art decisions and continue unattended. Self-review each result, revise visible faults, and continue through the queue. Save the evidence and remaining issues for the owner's later review.

Use the [bundle briefs and artist references](Exotic%20Bundle%20Concepts.md). This pass delivers concept PNGs, Blender concept models and motion previews, and an animator handoff. Keep all work in Blender and on disk. Studio, runtime integration, uploads, and publication are a separate pass.

## Queue

| Line | Hero | Other guns in build order | Melee | Charm |
| --- | --- | --- | --- | --- |
| Spindrift | Vandal | Spectre, Ghost, Marshal, Guardian, Bucky | Sounding Arc | Stormglass Buoy |
| Kilnlock | Odin | Phantom, Bulldog, Shorty, Sheriff, Judge | Kiln Cleaver | Foundry Stamp |
| Stacklight | Phantom | Stinger, Classic, Outlaw, Ares, Operator | Patch Tool | Keycap Tester |

Complete the three heroes in the order shown, then the three melees, then the three charms, then the remaining guns by line in the order shown. Complete independent work if a specific source or tool is blocked. Track **18 gun sheets, three melee sheets, and three charm sheets**, with separate Phantom outputs under Kilnlock and Stacklight.

## Concept production

1. Read the existing [vault skill](../../../.claude/skills/gauntlet-vault/SKILL.md), [build style skill](../../../.claude/skills/gauntlet-build-style/SKILL.md), and [skin build pitfalls](Skin%20Build%20Pitfalls.md). Connect to **Blender MCP on `127.0.0.1:9999`**. Verify which scene and process are open read-only before editing. Preserve the current file, unsaved work, and original stock assets. Use separate, versioned concept scenes.
2. Use image generation for original concept art and material exploration. Use each gun's stock renders and Blender source for proportions, key silhouette landmarks, hand positions, sight alignment, and active stock parts. Reference gallery images guide art direction. If a sheet cannot be generated, build a Blender-rendered concept board using the stock reference and your own design studies. Follow the first reviewed hero's materials and shapes for the rest of its line.
3. Give each gun a large three-quarter view, fixed side view, held view, stock aim reference where applicable, material detail, and start, commit, and ready reload thumbnails. Show which pieces move, the decorative effect path, and the clean resting shape. Keep the recognizable stock game profile, contacts, and sight picture. Pair custom animation with the host's stock reload timing, including sequential loads and cancel states. Fit the charm to the fixed side at the stock `CharmPoint` where available, with a compact swing envelope clear of aim and hands. Use the [reviewed Bulldog and Stinger source repairs](Full%20Roster%20Reskin%20Build%20Ledger.md) and [regression checks](Reskin%20Geometry%20Regression%20Checks.md).
4. Build all three melee designs with original silhouettes, grips, rigs, and first-person motion. Start the animations from scratch. For each, show equip, idle, carry, light A, light B, heavy or alternate, inspect, recovery, and cancel. Draw grip anchors, effects, major poses and timing cues. Use the stock Knife and current gameplay only to check camera coverage and contact timing. Implement short Blender concept animatics with distinct motion and silhouette states. Keep game reach, hit windows, and responsiveness anchored to the current gameplay.
5. Keep the selected charms from the brief. Give each a separate mesh, mount pivot, finish, resting pose, and active pose. Show the concept at reward-icon size and on its hero in the held view. Use a bubble for Stormglass Buoy, a hinged glow reveal for Foundry Stamp, and a light and keypress study for Keycap Tester.

## Save and verify

- Save a versioned PNG for each item to `vault/02 Art/Skins/<Line>/out/<Item>_concept_vNN.png`. Use `SoundingArc`, `KilnCleaver`, `PatchTool`, `StormglassBuoy`, `FoundryStamp`, and `KeycapTester` as file stems. Include versioned Blender blockouts and short motion previews for the **three hero guns, three melees, and three charms** under `art-source/weapons/Skins/<Line>/<Item>/Concept/vNN/`. The other 15 guns need concept sheets and pose references. Use stock or concept scene renders wherever it improves their accuracy.
- Open every saved PNG and check it against the brief. Check gun proportions, sight and hand clearances against stock, and verify motion against the hero blockouts. Check both sides and the underside for floating joins, visible gaps, inverted faces, and layered surfaces that flicker from grazing views. Scrub the Blender previews with the first-person camera and inspect each change of state, including cancellation back to rest. Inspect each charm mounted and hanging at its most extreme pose.
- Grade the concept evidence on identity and finish **/35**, geometry and fit **/30**, presentation and reference quality **/20**, and motion clarity **/15**. Aim for 95/100 on the heroes and repair visible faults before carrying their design forward. Explain deductions and distinguish actual Blender checks from animation ideas shown on a sheet. Continue after self-review with the best verified result when further iterations hit a genuine tool limit. Leave any unverified item open.
- Maintain `vault/02 Art/Skins/Exotic Bundle Concept Ledger.md` from the first item onward. Update it **after every saved item or meaningful stage** with the output path and version, check result, unresolved corrections or tool issue, and exact next bundle, item, and stage. Reopen existing outputs on resume and continue from that checkpoint. Finish when all 24 entries have a verified deliverable, or report what is specifically blocked with the evidence and exact resume point.

## Kickoff prompt

If a single tool hits its limit, keep working on independent Blender, rendering, review, or handoff tasks. If account usage stops the run, resume from the ledger when Codex can continue after the reset. The owner's target restart is around **9:15 a.m. Chicago time on November 16, 2026**. Use the actual reset displayed by Codex if it is later. If the host needs a new turn, leave the exact next item and stage ready for a manual resume.

```text
/goal Complete the offline Glitched Gauntlet exotic concept pass. Read vault/02 Art/Skins/Exotic Bundle Concept Handoff.md and the linked bundle briefs, then start with Spindrift Vandal. Use image generation and Blender MCP on 127.0.0.1:9999. Deliver all 24 concept sheets and the Blender concept models and motion previews for the three gun heroes, three original melees, and three charms. Give each melee its own shape, rig, and original first-person animations. Self-review, fix what you find, and continue without waiting for approvals. Keep this pass in Blender and on disk. Studio and game integration come later. Update the ledger after each item. If usage interrupts the run, resume from the exact checkpoint following the handoff's 9:15 a.m. Chicago time restart guidance and skip completed items.
```
