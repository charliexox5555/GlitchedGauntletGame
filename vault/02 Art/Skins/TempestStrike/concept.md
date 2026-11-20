# Tempest-Strike

2026-11-18. Elite storm-and-shadow weapon line for Glitched Gauntlet. The owner supplied a revised Vandal sheet and an action, effects and sound breakdown. The Vandal is the first production hero. [Owner sheet](refs/style/Tempest-Strike%20Vandal%20Reference.png) · [Research and continuity](Research.md) · [Build handoff](Build%20Handoff.md)

**Production clarification.** Start with the Storm Shadow Vandal. Use GPT 3D and the relevant project skills, with live Blender MCP on port 9876. The owner prefers deliberate mesh modeling and sculpted detail, permits code where it helps quality and efficiency, and authorizes installation of useful Blender add-ons. The [handoff](Build%20Handoff.md#modeling-method-and-add-ons) records the workflow and review requirements.

**Owner review update, 2026-11-18.** Keep the stock Vandal legible in profile and first person, including the exposed barrel, rear-biased stock opening and unchanged buddy mount. Use sharper transitions, blue enamel and a single clean crescent on the stock aiming center. The current Blender master carries the empty mount and no effect geometry. Equipped charms, chromas and runtime water belong to later passes. [Build review](Build%20Review.md)

## Direction and precedence

The target is a fully authored elite rifle with the craftsmanship, silhouette development and action feel of **Ruin-Blighted Vandal v05**. The owner rejected the initial Ruin-Blighted expansion quality. Use the Vandal benchmark and the latest owner feedback when reviewing this hero. Another agent owns the Ruin-Blighted expansion revisions.

The owner's latest Tempest-Strike changes control the build. The image guides the overall composition. Where its hero view and detail panels disagree, resolve the design in a consistent 3D model and record the choice.

| Topic | Current direction |
| --- | --- |
| Fore-end | Elongated octagonal fluted shroud, tapered black and brushed-silver surfaces, clean side vents and a compact ported shinobi muzzle brake. The original bulky crescent blade beneath the barrel is superseded. |
| Water | Thin laminar ribbons close to the shell and stock ring. The older dense mist and blob treatment is superseded. |
| Sight | Open crescent-halo rear frame, two restrained cyan pips, clear aiming center and a usable front reference aligned to the stock aim axis. |
| Stock | A purpose-built triangular open frame, with a circulating pressurized-water ring at its rear junction. The opaque frame carries the structural silhouette through every effect state. |
| Grip and magazine | Charcoal to dark-brown leather wraps, crisp overlapping folds and recessed hydro-conduits. Wrap thickness follows hand and magazine clearance. |
| Character | Sharp, composed, lightweight and precise. Faceted black alloy and selectively bright silver make the rifle readable before the effects play. |

## Structure and first-person composition

Rebuild the visible fore-end, receiver shoulders, upper spine, stock frame, magazine exterior, grip finish and sight frame into a coherent family. Use a continuous dark chassis, long silver planes and deliberate vent reveals. Give the silver plates a seat, consistent thickness, tapered ends and their own readable transitions into the receiver. Replace the stock visual hardware in the redesigned regions so duplicate rails and panels cannot show through.

The barrel shroud should appear longer and faster through proportion and taper. Measure the stock envelope before setting its length. Keep the result close to the game's Vandal footprint, grip spacing, camera position and muzzle reference. Record any dimensional departure and show it in a matched stock comparison. The concept's printed triangle count is illustrative and needs a real measured count from the saved asset.

The wrapped magazine must read as a distinct removable assembly. Put bindings, conduits and water guide anchors on its own rig branch. Resolve the magwell lip, release, moving action and visible ejection area in the new visual language. Keep the original mechanical and hand-contact contracts while giving their visible covers deliberate new forms.

Use the sight-frame opening to preserve the stock aiming center. Keep the two pips outside the aiming target, with low brightness. Test the ring thickness and opening from the actual aim cameras. Redirect or fade any water, sparks, charm swing and bright surface that enters the sight corridor. The side-view crescent motif must resolve into a working first-person frame.

The underside, far side, magazine bottom, stock joint and action area receive the same finished modeling as the hero side. Leather folds, plate overlaps and facets should hold up under neutral lighting. Water and lightning support a finished silhouette.

## Palette and finish

These are proposed working values derived from the supplied image and description. The role names describe intended material separation. Keep the repository's role contract intact when mapping them into a manifest.

| Role | Proposed base | Finish |
| --- | --- | --- |
| Body | `#171C20` | Matte black alloy with broad planar highlights |
| Panel | `#B8C4CC` | Brushed silver, directional along the long armor planes |
| Dark | `#101726` | Dark indigo in deep recesses and vent interiors |
| Grip | `#4B3429` | Dark-brown leather, charcoal shadows, subtle grain and edge compression |
| Metal | `#65717D` | Dark steel at collars, joints, controls and muzzle detailing |
| Accent | `#42677E` | Storm-blue inset areas, used sparingly |
| Hydro | `#67E9E4` | Transparent cyan water, narrow bright edges and a visible internal current |
| Spark | `#E5FFFF` | White-cyan lightning and flash peaks |
| Glass | `#A9E5E9` | Pale translucent hydro-core glass with silver collars |

**Storm Shadow** is the base. **Amethyst Gale** uses obsidian and gunmetal with deep royal-purple water and violet sparks. **Mist Ivory** uses porcelain-white and pale silver with icy seafoam energy. **Midnight Eclipse** uses charcoal and blackout alloy with white-blue arcs. Keep shared geometry and semantic finish roles across all four. The base hero establishes finish quality before the chromas are produced.

## Animated assemblies

Author independent controls for the long sliding silver plates, front water guides, rear hydro-ring guides, magazine assembly, magazine water and charm pivot. The exact plate count follows the silhouette and movement. Put pivots at believable slide directions and leave real clearance throughout travel. The water path must follow its owning part when the magazine detaches or the stock moves.

| State | Intended performance and visual cues |
| --- | --- |
| Equip | Crisp one-handed forward flip into a confident grip. A water ring sweeps from muzzle toward stock and locks the sliding silver plates in sequence. Resolve the flip and catch with the actual hand anchor. Settle at the current Vandal ready time. |
| Idle | Restrained circulation along the shroud grooves and stock ring. Tiny vent arcs occur intermittently. The rifle stays composed during breathing, movement and ADS. |
| Firing | The action and plate response remain tight. Compact four-point cyan-white flash, a few droplets and a thin electric-cyan tracer establish the shot. A brief pulse runs through the hydro-conduits. |
| Reload release | The rifle rolls slightly, the old magazine leaves the well, and its water breaks into a short splash. Keep a recognizable magazine until its release is readable. |
| Reload summon | The off hand opens palm-up. A small swirling water sphere condenses into the new magazine. The sphere is an action effect, with a clear reveal into solid geometry. |
| Reload seat | An upward hand gesture guides the magazine into the well. Align the magazine, hand and water tether on one action clock. The seat triggers one sharp lock and a narrow cyan pulse toward the muzzle. |
| Empty reload | Stage its own release, form, seat and chamber events on the current empty-reload duration. Show how the new action cover resolves the stock chamber beat. |
| Inspect | Release the trigger hand, levitate the rifle inside a hovering water ring, turn it through a complete horizontal 360 degrees, then catch the wrapped grip cleanly. The hands communicate the release, control and catch. Keep the spin centered around a measured balance pivot. |
| Cancel and transition | Return plates, hands, magazine visibility, ring and charm to valid states on early ADS, firing, reload cancel, weapon switch, sprint, Mod use and death. An interrupted inspect skips the unperformed catch sound. |

Use the current Vandal ready, ammo-commit and reload events as anchors. The new visible motions need their own authored hand and rifle staging. Measure the current runtime instead of treating an old Vandal clip duration as permanent. Timing values for this concept are implementation proposals until tested in the game.

## Effects brief

- Idle uses about two or three thin curved water ribbons along the grooves. A loop can use several Beam spans where its curve needs them. Start with a translucent scrolling caustic texture and `LightEmission` around `0.7`, then tune against the actual exposure. Author texture alpha to give water a fine bright edge and a transparent center. Beam emission does not light the surrounding meshes.
- Vent lightning uses short segmented Beam arcs inside defined vent anchors. Begin with a `0.05`-second flash every few seconds, varying its interval. This sparse arc treatment replaces the earlier continuous `Rate 4–6`, `Lifetime 0.15` particle proposal. Small droplet accents can use emitters when they improve the read.
- The muzzle flash is a compact, directional four-point star lasting about `0.04` seconds. Seat it on the muzzle anchor and test from hip and ADS during automatic fire. Keep droplets brief and outside the sight opening.
- Tracers are thin electric-cyan streaks with sparse droplet accents. Match existing shot paths and visual travel rules. A cosmetic tracer conveys the theme while the server continues to own hit results.
- Surface hits combine a short water splash with a fading static-spark mark. Use the existing material-impact routing, pooled effects and cleanup. Keep surface identity readable and check the mark against moving parts and grazing surfaces.
- Variant colors drive water, arcs, flash, round core and charm consistently. Tune neutral material values independently so white and black chromas retain visible facets.
- Preserve a clean opaque silhouette when effects are reduced or unavailable. Record effect counts, transparency overdraw and low-graphics appearance during the later runtime pass.

## Ammunition and charm

The hydro-core round uses a faceted translucent cyan body, an internal current, pale silver collars and a sharp dark-silver tip. Make a separate enlarged visual concept and an appropriately sized cosmetic model. Verify its scale against the host's visible round and ejection contracts. Recolor the internal water by chroma. Keep presentation separate from the game's ammunition and projectile rules.

The charm is an original compact **spinning shuriken** suspended below a short mount ring on the player-facing side. Give it a dark center, silver points and a narrow circulating cyan accent. Spin around the charm's own center, with bounded mount swing. Test reward-icon size and the held view, full inspect spin, reload and ADS. Establish a proper mount seat on the fixed receiver. This replaces the older Stormglass Buoy direction for this revised hero.

## Sound direction

| Cue | Intended source and behavior |
| --- | --- |
| Fire | Crisp ballistic snap with a whip transient and subtle high-frequency electric crackle. The suppressed-leaning mix is an artistic timbre. Keep the Vandal's firing cadence and world audio behavior recognizable. Starting report pitch range `0.98–1.02`. |
| Draw | Short directional water sweep followed by a precise metallic plate lock. |
| Magazine release | Release click and a brief liquid break. |
| Summon and glide | Rushing water gathers in the off hand, condenses and travels upward with the magazine. Split into separately cancellable cues. |
| Seat and chamber | One katana-sheathing-style ring at the seat with a small mechanical core. Distinguish the chamber event in the empty reload. |
| Inspect | Quiet circulating water, restrained static and a clean grip catch. Hold audio fades on cancel. |
| Elimination ladder | Original wind-chime or taiko-accented bell notes rising from Kill 1 to Kill 5+. An Ace adds distant thunder when the game confirms that event. Map the ladder to Gauntlet's actual round and team structure in the integration pass. |

Source original or licensed recordings and keep custom playback in separate private assets per take. Reuse the Ruin-Blighted Vandal's event infrastructure where it fits. Its stone locks and mist recordings are references for timing and mix weight. Tempest-Strike needs its own water, metal and electric identity.

## Continuity and open inputs

The earlier Kuronami-inspired project was Spindrift. Its prior six-gun roster was Vandal, Spectre, Ghost, Marshal, Guardian and Bucky, with Sounding Arc melee and Stormglass Buoy charm. Keep those records as history. This request starts the revised Vandal hero under the working folder `TempestStrike`. The remaining roster and melee identity need confirmation for this revision before a full line production queue is established.

Only the Vandal reference PNG was attached to this request. A separate knife image, grip, proportions and animation breakdown are pending. The shared storm palette and laminar water language are ready for the later melee brief. A knife design cannot be inferred from this rifle sheet.

The owner asks for a prepared handoff in this chat. Production begins from the [build handoff](Build%20Handoff.md) in the next build chat.
