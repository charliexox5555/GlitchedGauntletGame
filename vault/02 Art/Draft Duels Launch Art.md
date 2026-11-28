# Draft Duels Launch Art

## Visual direction

Use the approved [Draft Ticket in Lobby Gold](Draft%20Duels%20Logo.md#approved-title) for the brand. The gold fighter is faceless, with gold on the body and a soft edge glow against charcoal. The bacon study uses Roblox's Pal Hair, Blue and Black Motorcycle Shirt, and Dark Green Jeans. The blue and orange studies use a color wash to identify the teams. Keep each composition readable at 256 × 144 and each icon readable at 48, 96 and 150 pixels. Use the game's own weapons, maps, Mods, and effects.

## Reference archive

All 11 attachments are preserved in order in the [local reference folder](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/). The copies match the original attachment hashes. The references stay local.

| Image | What reads at a glance | What Draft Duels can use |
| --- | --- | --- |
| 01 | One saturated figure, a large barrel, and a cool room separate the shapes. The scope gives the eye a second place to look. | Gold fighter against a cool, desaturated arena. Keep a single dominant silhouette. |
| 02 | The weapon and arena edges converge on an energetic midair event. | Place the first-person barrel, one movement arc, and the opponent on the same visual path. |
| 03 | A large foreground opponent and a small opponent across a doorway establish scale and two sides. | Show an opposing fighter across a real lane. Preserve the space between silhouettes. |
| 04 | The bright trail links the gun to its target across several depth layers. | Use an existing shot tracer or movement streak with one clear endpoint. |
| 05 | The wall edge, hands, and open sky sell the corner peek and point of view. | Frame a player-height combat shot from real cover and use the actual viewmodel. |
| 06 | One card, oversize effect, and expressive avatar explain the upgrade. | Put a single selected Draft Duels Mod beside a clear effect. |
| 07 | The foreground reaction makes the consequence of the upgrade immediate. | Frame the caster and opponent around a visible change in the lane. |
| 08 | Group staging, a single effect, and a separate card establish the team's role. | Give each team member their own silhouette. Keep the Mod card large if it appears. |
| 09 | A circular scope is a strong framing device, with an instantly identifiable avatar at its center. | Explore an authentic ADS crop as a control study. |
| 10 | A near-diagonal weapon with an effect on the model reads as an inspect even at small size. | Use a tested Draft Duels skin and preserve the actual color and effect language. |
| 11 | An interrupted reload provides stakes, with the player's hands and the enemy peek clearly separated. | Leave room for the hands and one opponent when a weapon action is the subject. |

## Five launch candidates

| Priority | Shot | Studio and Blender layout |
| --- | --- | --- |
| 1 | **Gold Duelist** | Medium three-quarter Vandal hold at Canyon Outpost. Gold figure on the right, graphic rim light, arena cover on the left. A natural bacon treatment is the alternate for the same composition. |
| 2 | **Foundry Slide** | Match first-person viewmodel at slide height in Foundry4. The barrel and a short bright tracer frame one orange opponent. Furnace light provides the warm accent. |
| 3 | **Draft Firewall** | Two-thirds action with one visible Firewall curtain and one selected Firewall card composited from the current draft UI. Use the actual fire-wall shape. A bacon caster carries this variant. |
| 4 | **Rooftop 2v2** | Blue foreground pair and orange opposing pair, using Rooftops4 elevation and cover to separate them. Keep the brightest background near center so both team edges read. |
| 5 | **Snowpeak Inspect** | First-person inspect of an approved release weapon skin with Snowpeak4 as the cool backdrop. Preserve both grip contacts and one effect highlight on the weapon. |

Start the detail page with Gold Duelist and the Home page set with all five once the shot exports pass review. Use the resulting qualified play-through data during the soft launch to evaluate the art. The icon pick is an editorial judgment based on small-size legibility. [Roblox thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) · [Roblox icons](https://create.roblox.com/docs/production/publishing/experience-icons)

## Avatar and accessory workflow

- Open the [local Blender master](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/rig-study/Draft%20Duels%20-%20Avatar%20Look%20Development.blend) and pick **Gold**, **Bacon**, **Blue** or **Orange** from the scene menu. Frame 13 is the portrait pose. Frames 1–25 show the rifle move through a low-to-level hold. The scene uses the game's Vandal model and the Starter Blocky Rig from the supplied ZIP. The ZIP's README allows use in commercial renders and prohibits redistribution of the modified rig. The working Blend stays local. [Starter Rigs course](https://www.youtube.com/watch?v=gXA67QZrGyQ)
- To bring in another actual outfit, stage a temporary avatar in Studio and read the Shirt and Pants **template image IDs** issued by the HumanoidDescription. Clothing uses the `Roblox classic clothing` UV map. Replace the image in the `Image Texture` node of the appropriate body material. The bacon outfit's catalog IDs are 144076358 for the shirt and 144076760 for the pants. Studio resolved the atlas image IDs to 144076357 and 144076759.
- To fit another real accessory, use the Studio item's Handle mesh, texture, and the live accessory weld frames. Align the Handle by `bodyAttachment.CFrame * handleAttachment.CFrame:Inverse()` after converting the axes, then parent to the rig's matching named attachment empty. The bacon scene applies this to Pal Hair's original mesh and image. The head sockets follow the neck pose. Keep the faceless gold scene clean. [Pal Hair](https://www.roblox.com/catalog/63690008/Pal-Hair) · [Roblox rigid accessory specs](https://create.roblox.com/docs/avatar/rigid-accessories/specifications)
- [Studio's Match Avatar setup](../01%20Design/Match%20Avatar.md) uses the skinned S15 body and the player's own head, clothing, and accessories. The Blender study reuses the established rifle movement against its own armature and has its own arm deformation. For first-person staging, match the camera and grip data in [Viewmodel](../../src/shared/Config/Viewmodel.luau). The third-person pose source is [tp_clips.py](../../tools/anim/tp_clips.py).

## Outputs and verification

- [Thumbnail prompts and asset map](../../art-source/ui/draft-duels/launch-art/Thumbnail%20Brief.md) · [Local thumbnail handoff ZIP](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/Draft%20Duels%20-%20Thumbnail%20Handoff.zip)
- [Avatar and icon comparison](../../art-source/ui/draft-duels/launch-art/draft-duels-avatar-studies.jpg)
- [512 × 512 Gold icon candidate](../../art-source/ui/draft-duels/launch-art/draft-duels-icon-gold.png) · [512 × 512 bacon variant](../../art-source/ui/draft-duels/launch-art/draft-duels-icon-bacon.png) · [Local layered icon master](../03%20Research/Rivals%20Reference/third-party/draft-duels-thumbnails/rig-study/Draft%20Duels%20-%20Gold%20Icon.ora)
- The four named map layouts were captured from the Match Studio Edit DataModel (place 133387545285290). The local capture contains visible part transforms, sizes, colors, materials, mesh IDs, and texture IDs. Several map meshes require Studio access and returned HTTP 401 from public Asset Delivery. Scene assembly and final thumbnail renders are pending. The map capture was read-only.
- Blender MCP on port 9067 verified the four scenes and their retargeted hold actions through a library inspection. The Blender starter-rig elbow and wrist deformation still falls short of the Match body. Use the actual S15 animation path in the brief for production renders. The staged Blender file remains a wardrobe, lighting, and framing aid.

## Twelve thumbnail concepts

The expanded set pairs neutral and cinematic lighting on the same 12 compositions. Each full-size export is 1920 × 1080. The single comparison sheet places the 256 × 144 previews side by side and marks Gold Duelist, Foundry Slide, Draft Firewall, Rooftop 2v2 and Snowpeak Inspect as the launch shortlist. Draft Firewall and Updraft Crossfire show the selected Mod card from the current draft design alongside the effect it produces.

The revision uses the Match S15 meshes and attachment positions, the installed Roblox classic head mesh, the catalog accessories and classic clothing, and the authored third-person poses. The gun grips use the actual weapon contact points. In first person, the Blender render uses recorded viewmodel arm poses and the animated weapon joints, including the magazine joint during the reload. Both lighting passes use the same camera, pose and effect placement. Cinematic adds colored keys, rim lights and a selective glow grade.

The four environments use the recorded Match Edit layouts and local map kit geometry. The local handoff lacks matching geometry for some Canyon Outpost and Snowpeak props. These are Blender compositions for review using those captures.

[Paired contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/DraftDuels-ContactSheet.png) · [24 full-size exports](../../art-source/marketing/draft-duels/thumbnail-concepts/DraftDuels-12-Thumbnail-Pairs.zip) · [Concept list and source notes](../../art-source/marketing/draft-duels/thumbnail-concepts/README.md)

## Second thumbnail pass

The owner asked for clearer action, believable holds, faceless team fighters, real Bacon wardrobe, larger ability cards and unbranded Gold Duelist and Snowpeak Inspect. The second Blender stage uses the original fingerless arm and hand meshes, keeps the forearm and grip rigid together on the trigger side, and solves the support hand beneath the long gun. First-person shots use plain Roblox block arms. The detached magazine and the opponent each have their own space in Reload Window.

The built-in ImageGen edit tool created 12 lighting studies from the scene proofs and numbered visual references. The finish samples their low-frequency illumination and color. All visible models, contours, poses and effects come from the Blender plates. Neither the generated character shapes nor hands are used in the exports.

[Revised contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/DraftDuels-Revised-ContactSheet.png) · [Revision package](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/DraftDuels-Revised-Thumbnails.zip) · [ImageGen prompts](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/ImageGen-prompts.md)

## Polished thumbnail set

The 12 final grades use the revision-02 Draft Duels plates. ImageGen received three four-shot groups of those plates and contributed broad lighting and color. The original staged cameras, poses, weapons, faces and fingerless hands supply the visible geometry. The Blender effect pass reduced muzzle flashes and scattered sparks while preserving the game’s Firewall, Updraft and directional tracers.

The official Match Firewall and Updraft card artwork was composited with larger names. Bacon Lock-In uses the approved Draft Ticket wordmark. Gold Duelist and Snowpeak Inspect are logo-free. Reload Window has a dedicated highlight on the detached magazine and support block.

[Named contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/polished/DraftDuels-Polished-ContactSheet.png) · [12 full-size PNGs](../../art-source/marketing/draft-duels/thumbnail-concepts/revision-02/polished/DraftDuels-12-Polished-Thumbnails.zip)

## Featured three thumbnails

The owner selected Updraft Crossfire, Gold Duelist and Draft Firewall for a focused pass. Draft Firewall now stages Bacon in three-quarter view with the casting arm clear of the face, the actual flame wall angled across the lane, and the official card on the right. Gold Duelist uses a tighter unbranded Vandal portrait. Updraft Crossfire has more air above the launched duelist and a wider view of the ground fight.

The original Match S15 blocks, fingerless hands, weapons and maps supply all rendered geometry. Built-in ImageGen contributed three empty environmental lighting studies. Their broad light and color were applied to the Blender plates. The export check decoded all three 1920 × 1080 RGB PNGs, matched each against its 256 × 144 contact tile and tested the ZIP.

[Contact sheet](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/DraftDuels-Three-Thumbnail-ContactSheet.png) · [Full-size PNGs](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/DraftDuels-Three-Thumbnails.zip) · [ImageGen prompts](../../art-source/marketing/draft-duels/thumbnail-concepts/three-shot-pass/ImageGen-prompts.md)

## High-CTR thumbnail overhaul (v3)

A fresh overhaul targeting Home Recommendation qPTR after the post-launch release pass. Compared against the 11 reference tiles (`ref-01`–`ref-11`), the earlier Blender-plus-wash exports suffered from dark/brown mid-tone backgrounds, stiff folded blocky limbs, neutral faces, faint pale Firewall geometry, and weak value separation at 320 × 180 and 160 × 90.

The v3 set adopts the two proven high-CTR Roblox FPS patterns from the references while keeping every weapon, sleeve, Mod card, and map faithful to Draft Duels (**G1 Truthful**, **G2 Policy-Safe**, strictly fingerless rectangular blocky Roblox hands):

| File | Ref DNA | Subject & Draft Duels tie-in | LihFolk Score |
| --- | --- | --- | --- |
| `01_arena_headshot_pov.png` | `ref-04`, `ref-02` | First-person tactical Vandal (gold-cuffed Arena sleeves) firing curving golden tracers into two white-rimmed crimson enemies with headshot crown bursts in white cross-grid Arena | 9.5 / 10 |
| `02_draft_firewall_duel.png` | `ref-07`, `ref-06` | Angry/shouting Bacon firing Classic pistol over a blazing faceted Firewall toward a panicked wide-eyed rival, with a composited Lobby-Gold `FIREWALL` Draft Card (`cards_v2/Firewall.png`) + pixel cursor in the open cyan sky pocket | 9.5 / 10 |
| `03_sniper_scope_duelist.png` | `ref-01` | Faceless white-rimmed crimson duelist aiming a foreshortened Draft Duels Operator toward top-left, with an opposing leaping duelist reflected in the octagonal scope lens | 9.5 / 10 |
| `04_knife_peek_arena.png` | `ref-05` | Corner-peek in sunlit cross-grid Arena with gold-cuffed fingerless left arm bracing wall, right hand holding the **Riftforge Riftfang Knife**, and one glowing crimson enemy centered under blue sky (no corner marks) | 9.5 / 10 |
| `05_skin_inspect_hero.png` | `ref-10` | Diagonal inspect of the **Riftforge Operator** (plasma reactor core, purple energy vents, bold ink outlines, neon lightning arcs) held from below by two fingerless blocky arms over vibrant sky and skyline | 9.5 / 10 |

All five exports were verified at `1920 × 1080` RGB PNG, checked at `320 × 180`, `160 × 90`, greyscale, and bottom-18% / 5%-inset safe areas, and packaged for Roblox Creator Hub Thumbnail Personalization testing (track qPTR alongside average playtime per qualified play).

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v3/qa/DraftDuels-V3-ContactSheet.png) · [Build & composite script](../../art-source/marketing/draft-duels/thumbnail-v3/scripts/build_v3_thumbnails.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v3/DraftDuels-V3-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v3/exports/)

## Original game-accurate thumbnail set (v4)

After owner review flagged that v3 cloned competitor maps, solid-red enemies, and sleeved hands too closely, v4 rebuilt the set strictly from Draft Duels' own assets (`Arena.jpg`, `OldTown4.jpg`, `Snowpeak4.jpg`, `Rooftops4.jpg`, `Vandal`, `Classic`, `Operator`, `Riftforge`, `cards_v2/Firewall.png`, and `revision-02/plates/` monolithic FPS arms) with zero competitor references passed to image generation. Headless Blender 5.2 and Python Pillow/numpy finished the original shocked right-side rival, Bacon classic-smile A/B swap, tracer bridge, and monolithic knife-arm cleanup after image generation hit its capacity window.

| File | Subject & Draft Duels assets used | Key fix vs. v3 |
| --- | --- | --- |
| `01_arena_headshot_pov.png` | Real **Arena** (central pillar on pedestal, ramp, `+` blocks, blue sky), two monolithic plain-tan rectangular block arms, **Vandal**, and two glowing **Orange** faceless enemies with charcoal rifles & headshot bursts | Replaced sleeves/hands, red enemies, and RIVALS layout; bridged both tracers cleanly to muzzle |
| `02a_draft_firewall_expressive.png` | Shouting **Bacon** firing **Classic** across faceted **Firewall**, sunlit **OldTown4** lower platform, Lobby-Gold **`FIREWALL`** Draft Card + cursor, and new Blender-rendered Ally-Blue hoodie / Lobby-Gold cap shocked rival | Swapped out right-side cloned character & updated lower floor/wall |
| `02b_draft_firewall_classicface.png` | Exact A/B match to `02a` with Bacon's original classic Roblox smile (`Smile.png`) blended seamlessly onto his face | Added no-face-change Bacon option alongside `02a` |
| `03_sniper_scope_duelist.png` | Radiant **Lobby-Gold** faceless duelist aiming Draft Duels **Operator** diagonally left-to-right over **Snowpeak4** (red gondola, pines, peak) with an **Orange** Updraft opponent reflected in the scope lens | Original composition, Gold hero, Snowpeak4 backdrop, Draft Duels Operator |
| `04_knife_peek_arena.png` | Tight right-side **Arena** cover peek with **one** seamless monolithic plain-tan rectangular block arm holding **Riftforge Riftfang Knife** against an **Orange** enemy holding a dark charcoal rifle | Removed extra wrist/hand block & sleeves; swapped red enemy/gun and map |
| `05_skin_inspect_hero.png` | Diagonal **Riftforge Operator** inspect with neon violet lightning held from below by two monolithic plain-tan rectangular block arms over Draft Duels' real **Rooftops4** skyline (water tower, brick roofs, star sign, navy towers) | Replaced generic skyscrapers & cuffed arms with real `Rooftops4` and monolithic FPS block arms |

All six exports decoded cleanly at `1920 × 1080` RGB PNG and passed `320 × 180`, `160 × 90`, greyscale, and bottom-18% safe-area verification.

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v4/qa/DraftDuels-V4-ContactSheet.png) · [Blender rival renderer](../../art-source/marketing/draft-duels/thumbnail-v4/scripts/render_firewall_rival.py) · [Build & composite script](../../art-source/marketing/draft-duels/thumbnail-v4/scripts/build_v4_thumbnails.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v4/DraftDuels-V4-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v4/exports/)

---

## Grounded characters & editable Firewall plates (v5)

Addresses the owner's v4 feedback in headless Blender 5.2 Cycles + Pillow (`1920x1080 RGB PNG`):

- **[01_arena_headshot_pov.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/01_arena_headshot_pov.png)** — Grounded both floating Orange fighters squarely onto their Arena cover block tops with cool blue-grey contact AO and directional cast shadows, and smoothly reconnected both golden tracer arcs into their lowered headshot bursts.
- **02 Draft Firewall variants** — Preserved Bacon (`OldTown4` floor update, tilted Lobby-Gold `FIREWALL` Draft Card, pixel cursor) and extended the diagonal Firewall cleanly off the right edge with an open cyan speed-ray sky:
  - **[02a_draft_firewall_open_angry.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/02a_draft_firewall_open_angry.png)** — Open right-third editable plate keeping Bacon's angry face.
  - **[02b_draft_firewall_open_classic.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/02b_draft_firewall_open_classic.png)** — Open right-third editable plate with Bacon's classic Roblox `Smile.png` face.
  - **[02c_draft_firewall_roblox_rival.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/02c_draft_firewall_roblox_rival.png)** — Authentic Blender S15 rival (`ClassicHead.mesh` + transparent shocked face decal, catalog `Fedora.mesh`, 2× Cobalt/Gold Roblox jacket texture, open arms-up shock pose) composited into the scene.
- **[03_sniper_scope_duelist.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/03_sniper_scope_duelist.png)** — Carried forward approved v4 export (`Lobby-Gold` `Operator` duelist on `Snowpeak4` with `Orange` Updraft scope reflection).
- **[04_knife_peek_arena.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/04_knife_peek_arena.png)** — Replaced the unnatural AI enemy and warm floor puddle with a grounded Blender S15 Orange fighter (`AimLevel@0.24`, real `Vandal`, Cycles `is_shadow_catcher` cool-blue cast shadow) while preserving the plain-tan FPS block arm + `Riftforge Riftfang Knife`.
- **[05_skin_inspect_hero.png](../../art-source/marketing/draft-duels/thumbnail-v5/exports/05_skin_inspect_hero.png)** — Carried forward approved v4 export (`Riftforge Operator` inspect with two seamless monolithic tan block arms over `Rooftops4`).

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v5/qa/DraftDuels-V5-ContactSheet.png) · [Decal prep script](../../art-source/marketing/draft-duels/thumbnail-v5/scripts/prepare_v5_decals.py) · [Blender overlay renderer](../../art-source/marketing/draft-duels/thumbnail-v5/scripts/render_v5_characters.py) · [Build & composite script](../../art-source/marketing/draft-duels/thumbnail-v5/scripts/build_v5_thumbnails.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v5/DraftDuels-V5-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v5/exports/)

---

## Square experience icons (v5)

Generated 5 `1024×1024 RGB PNG` (`< 3 MB`) candidate Roblox game icons from the verified v5 thumbnails in ranked small-tile CTR order:

1. **[01_icon_gold_sniper.png](../../art-source/marketing/draft-duels/icon-v5/exports/01_icon_gold_sniper.png)** (Top Pick #1, `1,075,123 bytes`) — Tight crop on the `Lobby-Gold` duelist, heavy `Operator` rifle, and bright cyan scope reflection with the `Orange` Updraft target + `+140 px` extrapolated daylight sky (`1220×1220` -> `1024×1024`). Strongest figure/background contrast at `150×150`, `96×96`, and `48×48`.
2. **[02_icon_draft_firewall.png](../../art-source/marketing/draft-duels/icon-v5/exports/02_icon_draft_firewall.png)** (Top Pick #2, `1,177,897 bytes`) — Angry Bacon, Classic pistol flash, surging Firewall flames, and the complete Lobby-Gold `FIREWALL` Draft Card + cursor (`1160×1160` with `+80 px` radial speed-line sky continuation). Clearly communicates the core drafting twist inside a square icon.
3. **[03_icon_arena_headshot.png](../../art-source/marketing/draft-duels/icon-v5/exports/03_icon_arena_headshot.png)** (`1,078,863 bytes`) — Native `1080×1080` square crop framing both grounded Arena Orange targets, golden crossed X-tracers, muzzle flash, and the monolithic tan FPS block arms + `Vandal`.
4. **[04_icon_riftfang_knife.png](../../art-source/marketing/draft-duels/icon-v5/exports/04_icon_riftfang_knife.png)** (`896,262 bytes`) — Tight `1180×1080` crop featuring the Blender S15 Orange `Vandal` fighter and full `Riftforge Riftfang Knife` blade with `+100 px` periodic Arena pillar and tiled wall continuation.
5. **[05_icon_riftforge_sniper.png](../../art-source/marketing/draft-duels/icon-v5/exports/05_icon_riftforge_sniper.png)** (`1,213,448 bytes`) — Close-up inspect crop of the glowing purple crystal `Riftforge Operator`, crackling lightning arcs, and both monolithic tan block arms over `Rooftops4` (`1260×1260` -> `1024×1024`).

[Icon QA contact sheet](../../art-source/marketing/draft-duels/icon-v5/qa/DraftDuels-V5-Icons-ContactSheet.png) · [Icon build script](../../art-source/marketing/draft-duels/icon-v5/scripts/build_v5_icons.py) · [1024×1024 Icons ZIP package](../../art-source/marketing/draft-duels/icon-v5/DraftDuels-V5-Icons.zip) · [Icons exports folder](../../art-source/marketing/draft-duels/icon-v5/exports/)

---

## High-CTR v6 challengers (4%+ CTR push)

Created 5 `1920×1080 RGB PNG` (`< 3 MB`) challenger thumbnails built from the initial Roblox Ads data (`03_sniper_scope_duelist` leading at `3.2% CTR` across `655` impressions / `21` clicks; inspect/1v1 variants at `2.0–2.2%`), varied Draft Duels maps (`Foundry4`, `CanyonOutpost`, `Pier`), custom S15 Bacon expressions (`face_bacon_locked_in.png`, `face_bacon_grin.png`), and clean Draft Card hooks grounded in [Mods.luau](../../src/shared/Config/Mods.luau):

1. **[01_v6_gold_sniper_foundry_lock.png](../../art-source/marketing/draft-duels/thumbnail-v6/exports/01_v6_gold_sniper_foundry_lock.png)** (`1,243,079 bytes`) — Direct upgrade of the `3.2% CTR` Gold `Operator` sniper control placed over depth-blurred warm/cool `Foundry4`, adding a glowing red sniper target-lock reticle on the `Orange` Updraft victim inside the scope and molten embers.
2. **[02_v6_bacon_sniper_scope.png](../../art-source/marketing/draft-duels/thumbnail-v6/exports/02_v6_bacon_sniper_scope.png)** (`1,307,384 bytes`) — Fresh Blender S15 Bacon sniper with a confident locked-in smirk aiming `Operator` across depth-blurred `CanyonOutpost`, featuring the cyan Updraft scope reflection & red target lock seated directly onto the scope bell (`744, 508`).
3. **[03_v6_pick_your_mod_3cards.png](../../art-source/marketing/draft-duels/thumbnail-v6/exports/03_v6_pick_your_mod_3cards.png)** (`927,958 bytes`) — Minimal high-clarity Draft mechanic hook over bright cyan sky: 3 clean Mod cards (`Firewall` 60 Studs / 30/s / +2, hero Emerald `Heal Orb` +180 HP / 2 Hits / +3, `Dash` 1.0s Cloak / 28 Studs / +2) with a large white mouse cursor + click ripple on `Heal Orb`, all inside top-5% / bottom-18% safe zones.
4. **[04_v6_bacon_card_arrow_blast.png](../../art-source/marketing/draft-duels/thumbnail-v6/exports/04_v6_bacon_card_arrow_blast.png)** (`1,163,679 bytes`) — Expressive shark-grinning S15 Bacon firing an outstretched `Classic` pistol across bright cyan sky with a blazing starburst and 3D cel-shaded golden projectile, a 4-card fanned Draft hand (`Frost`, `Dash`, hero Lobby-Gold `Stim` +25% Fire Rate / +25% Speed, `Heal Orb`), and a bold glossy curved red arrow connecting `Stim` straight up to the blast.
5. **[05_v6_recon_xray_sniper.png](../../art-source/marketing/draft-duels/thumbnail-v6/exports/05_v6_recon_xray_sniper.png)** (`1,206,284 bytes`) — Tactical NVG night-vision `Pier` composition showing a crouching neon-red X-ray S15 enemy + `Vandal` & sonar ping rings concealed inside the left crate, foreground `Operator` traced in razor-sharp neon-green edge wireframes held by a clean monolithic plain-tan FPS block arm (`#CB9A6D`), emerald moon, and top-left `Recon` card (`Wallhack 4.0 s`, `Damage +20%`).

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v6/qa/DraftDuels-V6-ContactSheet.png) · [Face decal script](../../art-source/marketing/draft-duels/thumbnail-v6/scripts/prepare_v6_faces.py) · [Blender overlay renderer](../../art-source/marketing/draft-duels/thumbnail-v6/scripts/render_v6_blender.py) · [Build & composite script](../../art-source/marketing/draft-duels/thumbnail-v6/scripts/build_v6_thumbnails.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v6/DraftDuels-V6-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v6/exports/)

---

## High-CTR v7 AI-GFX challengers

Regenerated all 5 challengers natively via AI image generation (`image-generator`) with true `1:1` player-scale ground-level camera framing inside Draft Duels maps (`Arena`, `CanyonOutpost`), smooth GFX character renders (replacing Blender rig overlays and 2D background cutouts), exact Draft Duels weapons (`Operator`, `Riftforge Operator`, `Classic`), and normalized `1920×1080 RGB PNG` (`< 3 MB`):

1. **[01_v7_gold_sniper_arena.png](../../art-source/marketing/draft-duels/thumbnail-v7/exports/01_v7_gold_sniper_arena.png)** (`1,632,364 bytes`) — Faceless metallic Lobby-Gold duelist grounded at `1:1` scale on the sunlit white `+`-grid `Arena` floor behind cover with real floor shadows, aiming the `Operator` with an Updraft Orange scope target, crimson lock crosshair, and white glint.
2. **[02_v7_bacon_riftforge_sniper.png](../../art-source/marketing/draft-duels/thumbnail-v7/exports/02_v7_bacon_riftforge_sniper.png)** (`2,355,205 bytes`) — Smooth glossy GFX Bacon standing behind a waist-high timber railing on a sunlit `CanyonOutpost` porch (full buildings, water tower, and terracotta cliffs behind), gripping the purple-crystal and gold-trimmed `Riftforge Operator` skin with dark tinted scope glass (no scope enemy reflection).
3. **[03_v7_pick_your_mod_3cards.png](../../art-source/marketing/draft-duels/thumbnail-v7/exports/03_v7_pick_your_mod_3cards.png)** (`1,981,760 bytes`) — Upgraded sunlit electric-cyan cloud sky with micro-grid gloss cards (`Firewall` 60 Studs / 30/s / +2, hero `Heal Orb` +180 HP / 2 Hits / +3, `Dash` 1.0s / 28 Studs / +2), colored mini stat icons, and a 3D white cursor click swoosh cleanly inside Roblox safe zones.
4. **[04_v7_bacon_draft_blast.png](../../art-source/marketing/draft-duels/thumbnail-v7/exports/04_v7_bacon_draft_blast.png)** (`2,038,555 bytes`) — Glossy GFX shark-grinning Bacon firing Draft Duels' slate-grey `Classic` pistol + fiery muzzle blast and gleaming 3D gold bullet over cyan sky, above 4 fanned Draft Cards (`Frost`, `Dash`, raised golden hero `Stim` `+25% Fire Rate`, `Heal Orb`) and a curved glossy red arrow up to the muzzle flash.
5. **[05_v7_recon_wallhack_duel.png](../../art-source/marketing/draft-duels/thumbnail-v7/exports/05_v7_recon_wallhack_duel.png)** (`1,642,852 bytes`) — Ultra-clean daylight `Arena` ground-level first-person `Operator` held by Draft Duels' monolithic plain warm-tan rectangular block arms (`#CB9A6D`), aiming a red laser through solid white `+`-grid cover at a blazing neon crimson X-Ray enemy framed inside one clean cyan Recon sonar ping ring (zero green filter, zero UI card clutter).

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v7/qa/DraftDuels-V7-ContactSheet.png) · [External AI prompt kit](../../art-source/marketing/draft-duels/thumbnail-v7/external-ai-kit/PROMPTS.md) · [Kit & strip builder](../../art-source/marketing/draft-duels/thumbnail-v7/scripts/build_v7_kits.py) · [Package builder](../../art-source/marketing/draft-duels/thumbnail-v7/scripts/build_v7_package.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v7/DraftDuels-V7-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v7/exports/)

---

## Live Engagement Ads readout & v8 challengers (4%+ CTR push)

Evaluated `13,272` total impressions across the live Engagement Ads cohort (`2026-11-24`):

- **Top performers (`2.9%–3.1%` CTR):** Gold Sniper Arena Close-Up (`4,357` imp, `3.1%` CTR, `133` clicks), Gold Sniper Arena Cover (`3,588` imp, `3.0%` CTR, `109` clicks), and Blue Sniper Snowpeak Ambush (`717` imp, `2.9%` CTR, `21` clicks).
- **Underperformers (`0.6%–2.0%` CTR):** Bright Arena FP Wallhack (`2,244` imp, `2.0%`), Bacon `CanyonOutpost` `Riftforge` (`1,484` imp, `1.6%`), Snowpeak FP Inspect (`382` imp, `1.0%`), and Pure 3-Card Draft (`500` imp, `0.6%`).

Built 5 `v8` `1920×1080 RGB PNG` (`< 3 MB`) challengers combining the proven `3.0%–3.1%` formula (glossy solid-color blocky `Gold` / `Cobalt-Blue` / `Neon-Orange` fighters + heavy `Operator` sniper + bright grounded `Arena`) with active live-shot/kill/ability hooks:

1. **[01_v8_gold_sniper_firing_shot.png](../../art-source/marketing/draft-duels/thumbnail-v8/exports/01_v8_gold_sniper_firing_shot.png)** (`1,838,825 bytes`) — Direct evolution of the `3.1%` champion captured mid-shot with blazing fiery muzzle blast, shockwave rings, sparks, and supersonic golden bullet streak ripping right across `Arena`, while keeping the cyan Updraft scope target + red reticle sharp.
2. **[02_v8_arena_headshot_ambush.png](../../art-source/marketing/draft-duels/thumbnail-v8/exports/02_v8_arena_headshot_ambush.png)** (`1,843,472 bytes`) — Grounded `Arena` over-the-shoulder ambush combining the `2.9%` Cobalt-Blue crouch framing with a Neon-Orange rifleman catching a blazing golden headshot beam and crisp `X` hitmarker impact starburst.
3. **[03_v8_midair_updraft_trickshot.png](../../art-source/marketing/draft-duels/thumbnail-v8/exports/03_v8_midair_updraft_trickshot.png)** (`2,132,057 bytes`) — Low-angle upward `Arena` trickshot featuring the Lobby-Gold sniper launched on a glowing cyan `Updraft` wind vortex locking a red laser beam down onto a peeking Cobalt-Blue enemy behind cover.
4. **[04_v8_gold_vs_blue_sniper_clash.png](../../art-source/marketing/draft-duels/thumbnail-v8/exports/04_v8_gold_vs_blue_sniper_clash.png)** (`2,101,108 bytes`) — Symmetrical `Gold vs Blue` 1v1 sniper duel across `Arena` cover with opposing orange-gold and electric-cyan rounds streaking mid-air plus fiery cover-edge ricochet sparks.
5. **[05_v8_firewall_sniper_arena.png](../../art-source/marketing/draft-duels/thumbnail-v8/exports/05_v8_firewall_sniper_arena.png)** (`1,977,583 bytes`) — Cobalt-Blue sniper crouched behind `Arena` cover aiming a crimson laser across a roaring diagonal faceted `Firewall` flame wall at a vaulting Lobby-Gold opponent (zero card overlays).

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v8/qa/DraftDuels-V8-ContactSheet.png) · [Package builder](../../art-source/marketing/draft-duels/thumbnail-v8/scripts/build_v8_package.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v8/DraftDuels-V8-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v8/exports/)

---

## Second Engagement readout & v9 breakthrough challengers

Evaluated `16,850+` live Engagement Ads impressions (`2026-11-25`):

- **Sustained winner:** `Gold Sniper Arena Close-Up` held **`3.1%` CTR** at **`13,515` impressions (`422` clicks)** (`7.48` Ad Credits).
- **Early & midrange pure-sniper contenders:** `Bacon + Riftforge CanyonOutpost` **`3.4%`** (`203` imp, `7` clicks — tiny sample), `Arena Headshot` **`2.9%`** (`452` imp, `13` clicks), `Gold vs Blue Clash` **`2.7%`** (`780` imp, `21` clicks).
- **Ability / card losers (`0.6%–1.4%` CTR):** `Firewall Arena` (`1.4%` / `1,146` imp), `Updraft Tornado` (`1.1%` / `178` imp), `Bacon + Cards` (`1.1%` / `176` imp), `FP Inspect` (`1.0%` / `382` imp), and `3-Card Draft` (`0.6%` / `500` imp).

Built 5 `v9` pure close-up gunplay challengers (`1920×1080 RGB PNG`, `< 1.84 MB` each, zero card UI or glowing cartoon abilities):

1. **[01_v9_scope_pov_headshot.png](../../art-source/marketing/draft-duels/thumbnail-v9/exports/01_v9_scope_pov_headshot.png)** (`1,805,803 bytes`) — Tight first-person sniper scope POV dead-locked with a glowing red crosshair and headshot ring on a wide-eyed panicked Bacon opponent peeking `Arena` cover.
2. **[02_v9_gold_riftforge_arena.png](../../art-source/marketing/draft-duels/thumbnail-v9/exports/02_v9_gold_riftforge_arena.png)** (`1,825,640 bytes`) — Direct upgrade of the `3.1%` (`13.5k`-imp) Gold Arena champion wielding the purple-crystal magenta-lightning `Riftforge Operator` skin while keeping the cyan Updraft scope target + crimson lock.
3. **[03_v9_bacon_riftforge_arena.png](../../art-source/marketing/draft-duels/thumbnail-v9/exports/03_v9_bacon_riftforge_arena.png)** (`1,809,112 bytes`) — Relocates the `3.4%` early Bacon + mythic `Riftforge Operator` out of muddy brown wood into crisp sunlit white `+`-grid `Arena` at big foreground scale (dark tinted scope glass).
4. **[04_v9_barrel_at_camera_gold.png](../../art-source/marketing/draft-duels/thumbnail-v9/exports/04_v9_barrel_at_camera_gold.png)** (`1,601,072 bytes`) — Forced-perspective Lobby-Gold crouched in `Arena` aiming the heavy `Operator` muzzle brake 3/4 straight at the viewer with blinding crimson-white optical scope glint and laser beam.
5. **[05_v9_dark_neon_gold_sniper.png](../../art-source/marketing/draft-duels/thumbnail-v9/exports/05_v9_dark_neon_gold_sniper.png)** (`1,832,330 bytes`) — High-contrast midnight-navy twilight `Arena` variation of the `3.1%` champion with molten-gold key lighting, electric-cyan rim glow, and radiant Updraft scope target.

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v9/qa/DraftDuels-V9-ContactSheet.png) · [Package builder](../../art-source/marketing/draft-duels/thumbnail-v9/scripts/build_v9_package.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v9/DraftDuels-V9-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v9/exports/)

---

## Third Ads readout & v10 Inner-Circle 5%+ pass

Evaluated `29,800+` total impressions across the updated Engagement Ads readout (`2026-11-25`):

- **Top performers & scaling winners:**
  - `03_v9` (`Bacon + Riftforge Arena`): **`5.0%` CTR** (`180` imp / `9` clicks — early breakout).
  - `04_v9` (`Barrel-At-Camera Gold`): **`4.0%` CTR** (`375` imp / `15` clicks — early breakout).
  - `Gold Sniper Arena Close-Up`: **`3.4%` CTR** across **`23,783` impressions (`802` clicks, `102` plays, `0.146` Ad Credit CPP, `2.2 hours` playtime)**.
  - `05_v9` (`Dark Neon Gold Sniper`): **`3.1%` CTR** (`2,350` imp / `74` clicks).
  - `Bacon CanyonOutpost Riftforge`: `2.9%` (`273` imp); `Gold Riftforge Arena`: `2.5%` (`161` imp).
- **Clutter & explosion losers:** `01_v8` (added muzzle blast/rings to the `3.4%` winner -> crashed to **`0.9%`** / `467` imp), `02_v8` (headshot burst -> **`1.8%`** / `833` imp, `1` play, `0.370` CPP, `Paused`), `01_v9` (Scope POV -> **`2.1%`** / `1,427` imp).

Applied Inner Circle **Prompt #2** (clean recreate/de-clutter/scale zoom) and **Insider Post #3** to produce 5 `v10` `1920×1080 RGB PNG` (`< 1.89 MB`) challengers + suggested High-PTR Experience Titles (`Draft Duels [SNIPERS]`, `SNIPER DUELS: Draft`, `1v1 Draft Duels [FPS]`):

1. **[01_v10_bacon_riftforge_ultra.png](../../art-source/marketing/draft-duels/thumbnail-v10/exports/01_v10_bacon_riftforge_ultra.png)** (`1,883,218 bytes`) — Prompt #2 upscale of `5.0%` `03_v9`: ~20% larger Bacon & `Riftforge Operator` (~65% frame) with fierce toothy grin and sharp furrowed brows over crisp sunlit `Arena`.
2. **[02_v10_barrel_at_camera_bacon.png](../../art-source/marketing/draft-duels/thumbnail-v10/exports/02_v10_barrel_at_camera_bacon.png)** (`1,759,397 bytes`) — Insider Post #3 fusion combining `5.0%` fierce-grinning Bacon + mythic `Riftforge Operator` with `4.0%` massive barrel-at-camera perspective, crimson scope star glint, and red laser beam.
3. **[03_v10_gold_barrel_closeup_clean.png](../../art-source/marketing/draft-duels/thumbnail-v10/exports/03_v10_gold_barrel_closeup_clean.png)** (`1,348,612 bytes`) — Prompt #2 Studio polish + precision `1.43×` close-up zoom on `4.0%` `04_v9` so Lobby-Gold, slotted `Operator` muzzle brake, crimson glare, and laser fill ~65% of tiny phone tiles.
4. **[04_v10_gold_arena_polish_clean.png](../../art-source/marketing/draft-duels/thumbnail-v10/exports/04_v10_gold_arena_polish_clean.png)** (`1,624,518 bytes`) — Pure Prompt #2 polish of the `3.4%` (`23.7k`-imp) champion: richer molten-gold gloss, smoother gunmetal bevels, saturated blue sky, and brighter higher-contrast cyan scope target (`+15%` clearer small-tile read, zero clutter).
5. **[05_v10_dark_neon_gold_clean.png](../../art-source/marketing/draft-duels/thumbnail-v10/exports/05_v10_dark_neon_gold_clean.png)** (`1,636,429 bytes`) — Prompt #2 de-cluttered cleanup of `3.1%` `05_v9`: strips every background dust speck/ember while boosting molten-gold warmth, electric-cyan rim glow, and scope target clarity.

[QA contact sheet](../../art-source/marketing/draft-duels/thumbnail-v10/qa/DraftDuels-V10-ContactSheet.png) · [Inner-Circle v10 prompts](../../art-source/marketing/draft-duels/thumbnail-v10/PROMPTS_V10.md) · [Package builder](../../art-source/marketing/draft-duels/thumbnail-v10/scripts/build_v10_package.py) · [1920×1080 ZIP package](../../art-source/marketing/draft-duels/thumbnail-v10/DraftDuels-V10-Thumbnails.zip) · [Exports folder](../../art-source/marketing/draft-duels/thumbnail-v10/exports/)

---

## Non-Operator FPS & First-Person concept kit (v11)

Built a complete external multi-attachment **Inner-Circle Two-Pass AI Prompt Kit** (`prompt_step1_create.txt` + `prompt_step2_polish.txt` per shot) testing Draft Duels' non-sniper weapons and true first-person (`#CB9A6D` monolithic tan block arms) RIVALS-style hooks without noisy explosion/card clutter:

1. **[01_fp_moltframe_vandal_arena](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/01_fp_moltframe_vandal_arena/)** — First-person `Moltframe Vandal` + monolithic tan block arms + violet-red laser on a panicked Bacon peeking white `Arena` cover.
2. **[02_fp_riftforge_shorty_ambush](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/02_fp_riftforge_shorty_ambush/)** — First-person point-blank `Riftforge Shorty` double-barrel corner ambush catching a wide-eyed panicked Bacon opponent.
3. **[03_bacon_riftforge_revolver](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/03_bacon_riftforge_revolver/)** — Fierce Bacon barrel-at-camera forced-perspective shot with the glowing purple cylinder `Riftforge Sheriff` revolver in sunlit `Arena`.
4. **[04_fp_riftforge_knife_backstab](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/04_fp_riftforge_knife_backstab/)** — First-person stealth peek holding the huge glowing `Riftforge Knife` (monolithic tan block arm) behind an unaware Lobby-Gold sniper in `Arena`.
5. **[05_fp_dark_neon_phantom_duel](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/05_fp_dark_neon_phantom_duel/)** — First-person dark midnight-navy twilight `Arena` holding the suppressed `Riftforge Phantom` aiming at a cyan-rimmed molten-gold rival.

[Master prompts & workflow guide](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/external-ai-kit/PROMPTS_V11.md) · [Kit generator script](../../art-source/marketing/draft-duels/thumbnail-v11-fps-variety/scripts/build_v11_fps_kit.py)

---

## High-CTR square icon prompt kit (icon-v6)

Built a `1:1` square (`1024×1024`) external multi-attachment **Inner-Circle Two-Pass Prompt Kit** (`prompt_step1_create.txt` + `prompt_step2_polish.txt`) adapting our verified `3.1%–5.0%` Ads winners to the small-size legibility rules in [Game Icon Design - Readable at Small Sizes](../LihFolk/27%20Marketing%20and%20Growth/Game%20Icon%20Design%20-%20Readable%20at%20Small%20Sizes.md) (`65–80%` single subject, clean radial studio backgrounds with zero clutter walls/blocks/smoke/text, central `~82%` rounded-corner safe bounds, high greyscale contrast down to `64px`/`48px`):

1. **[01_icon_bacon_riftforge_closeup](../../art-source/marketing/draft-duels/icon-v6/external-ai-kit/01_icon_bacon_riftforge_closeup/)** — Head-and-shoulders close-up of fierce-grinning glossy Bacon + forced-perspective obsidian-gold & glowing purple `Riftforge Operator` barrel + crimson optical scope flare & diagonal red laser on an electric-sky-blue radial gradient.
2. **[02_icon_dark_neon_gold_sniper](../../art-source/marketing/draft-duels/icon-v6/external-ai-kit/02_icon_dark_neon_gold_sniper/)** — Bust close-up of glossy molten **Lobby-Gold** + dark-gunmetal `Operator` with an oversized luminous cyan scope target (glowing orange rival + bold red crosshairs) wrapped in electric-cyan rim glow over a clean deep midnight-navy radial gradient.
3. **[03_icon_gold_crimson_barrel_lock](../../art-source/marketing/draft-duels/icon-v6/external-ai-kit/03_icon_gold_crimson_barrel_lock/)** — Tight crouched close-up of glossy Lobby-Gold behind the huge forced-perspective dark-steel `Operator` muzzle brake + blinding crimson-white scope flare & diagonal laser over a clean sunlit sky-blue/white radial gradient.

[Master square icon prompts & QA checklist](../../art-source/marketing/draft-duels/icon-v6/external-ai-kit/PROMPTS_ICON_V6.md) · [Kit generator script](../../art-source/marketing/draft-duels/icon-v6/scripts/build_icon_v6_kit.py)

---

## Fourth Ads readout (Play Ads 4.5% breakthrough) & v12 Laser-Lock multi-gun kit

Evaluated live **Play Ads** readout (`2026-11-26`):

- **Play Ads vs Engagement Ads baseline:** Play Ads optimize for game joins rather than casual clicks, so baseline CTR typically settles `~0.5–1.0%` lower (prior `3.4%` Engagement Gold Sniper tracked at `2.4%` over `698` Play-Ad imp).
- **Clear #1 scaling champion:** **`03_v10_gold_barrel_closeup_clean.png`** (`Lobby-Gold` + forced-perspective matte dark-gunmetal `Operator` + crimson scope star glare + red laser in sunlit `Arena`) hit **`4.5%` CTR across `21,354` impressions (`957` clicks, `6.78` Ad Credit)**.
- **Clear #2 breakout (non-sniper):** **First-Person `Moltframe Vandal` + Red Laser Dot on Panicked Bacon** hit **`3.6%` CTR** (`591` imp / `21` clicks, early `4.1%–4.5%` peak).
- **Verified visual insights:** `Lobby-Gold` + matte charcoal base steel + crimson glare (`4.5%`) crushed the matching pose with `Bacon` + flashy purple `Riftforge` (`2.4%` / `909` imp); `Dark-Neon Gold` held `3.0%` (`1,621` imp); external comic/ink renders scored `1.0%–2.2%`.

Built `v12` locking every prompt strictly to the `4.5%` smooth 3D Studio render (`03_v10_gold_barrel_closeup_clean.png`) + clean matte stock Blender models (explicitly blocking cartoon outlines/cel-shading/smoke):

1. **[01_v12_gold_sniper_5pct_push](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/01_v12_gold_sniper_5pct_push/)** — Tighter `+8–10%` crop on the `4.5%` champion (`Operator`), clearing the bottom-left block corner for a `5%+` push. **Generated & packaged:** **[01_v12_gold_sniper_5pct_push.png](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/exports/01_v12_gold_sniper_5pct_push.png)** (`1,892,998 bytes`, `1920×1080 RGB PNG`, `~7.5%` tighter crop + bottom-left block removed via [export_v12_shot01.py](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/scripts/export_v12_shot01.py); built-in `gemini-3.1-flash-image` then hit `429 RESOURCE_EXHAUSTED` with `~84h28m` remaining on Shots 02–05, staged in `external-ai-kit/`).
2. **[02_v12_gold_vandal_laser_barrel](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/02_v12_gold_vandal_laser_barrel/)** — Same `4.5%` Lobby-Gold + Crimson Laser-Barrel aesthetic with **Stock `Vandal`**.
3. **[03_v12_gold_sheriff_laser_barrel](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/03_v12_gold_sheriff_laser_barrel/)** — Same `4.5%` Lobby-Gold + Crimson Laser-Barrel aesthetic with **Stock `Sheriff` revolver**.
4. **[04_v12_gold_shorty_twin_barrel](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/04_v12_gold_shorty_twin_barrel/)** — Same `4.5%` Lobby-Gold + Crimson Laser-Barrel aesthetic with **Stock twin-barrel `Shorty` shotgun**.
5. **[05_v12_fp_vandal_laser_bacon_5pct](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/05_v12_fp_vandal_laser_bacon_5pct/)** — Direct `5%+` upgrade of the `3.6%` First-Person `Moltframe Vandal` + Red Laser Dot on a `+25%` larger panicked Bacon.

[Master v12 prompts & readout table](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/external-ai-kit/PROMPTS_V12.md) · [Kit generator script](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/scripts/build_v12_laser_kit.py)

---

## Power Duels PTR power kit (v13)

Built a `3`-shot `16:9` external multi-attachment kit showcasing real in-game **"Power Duels"** abilities on top of our proven `4.5%` (`21.3k` imp) and `3.6%` (`4.1%–4.5%` peak) Play Ads smooth 3D Studio templates — with **zero** old failed power thumbnails attached and **zero** UI cards, comic ink outlines, flame walls, or smoke clutter:

1. **[01_v13_fp_freeze_frame_bacon](../../art-source/marketing/draft-duels/thumbnail-v13-power-duels/external-ai-kit/01_v13_fp_freeze_frame_bacon/)** — **`Frost` (`Freeze Frame`)**: `3.6%` FP `Moltframe Vandal` + Red Laser Dot hitting a `+25%` bigger panicked Bacon frozen inside a **glass-clear faceted electric-cyan ice cube** beside a `Frost` cryo canister.
2. **[02_v13_gold_shock_bow_lock](../../art-source/marketing/draft-duels/thumbnail-v13-power-duels/external-ai-kit/02_v13_gold_shock_bow_lock/)** — **`ShockDart` Charged Bow**: exact `4.5%` Lobby-Gold aimed-at-camera 3D Studio formula drawing the faceted gunmetal `ShockDart` tactical bow + glowing electric-cyan charged arrowhead & tight energy ring.
3. **[03_v13_gold_ghost_dash_vandal](../../art-source/marketing/draft-duels/thumbnail-v13-power-duels/external-ai-kit/03_v13_gold_ghost_dash_vandal/)** — **`Dash` (`Ghost` / `Desync`) + Stock `Vandal`**: exact `4.5%` Lobby-Gold + Stock `Vandal` + crimson optic flare/laser mid-dash with **one crisp translucent glowing cyan holographic afterimage clone** trailing behind.

[Master v13 power prompts & PTR guide](../../art-source/marketing/draft-duels/thumbnail-v13-power-duels/external-ai-kit/PROMPTS_V13_POWERS.md) · [Kit generator script](../../art-source/marketing/draft-duels/thumbnail-v13-power-duels/scripts/build_v13_powers_kit.py)

---

## Fifth Ads readout (Three 4%+ winners) & v14 High-QPTR Power Evolution kit

Evaluated updated Play Ads performance (`2026-11-28`) across external renders of `v12`/`v13`:

- **Three `~4%+` stars:**
  1. `Lobby-Gold Barrel Sniper + Crimson Laser-Flare` (`03_v10`): **`4.5%` CTR** (remains #1; ready-to-test upgraded export **[01_v12_gold_sniper_5pct_push.png](../../art-source/marketing/draft-duels/thumbnail-v12-laser-lock/exports/01_v12_gold_sniper_5pct_push.png)** not yet tested).
  2. `First-Person Moltframe Vandal + Red Star Lock on Huge Bacon`: **`~4%+` CTR** (unobstructed panicked Bacon face + bright red forehead star lock won decisively).
  3. `Lobby-Gold ShockDart Bow + Cyan Energy Ring/Flare` (`02_v13`): **`~4%` CTR** (the **only ability winner**, preserving the `4.5%` aimed-at-camera silhouette + clean Studio Neon ring/star).
- **Why tested variants trailed:** Stock `Vandal` Barrel (`3.3%`), `Dash / Ghost` Clone (`2.8%` — second figure split single focal clarity), `Freeze Frame` Ice on Bacon (`2.5%` — ice over Bacon's face dimmed his panicked contrast vs the `~4%+` unobstructed version).

Built `v14` combining all `~4%+` learnings to push both **CTR** and **QPTR** via clean optical/energy cues (never ghost clones, never ice covering faces):

1. **[01_v14_gold_sniper_power_ring](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/external-ai-kit/01_v14_gold_sniper_power_ring/)** — `4.5%` Improved Sniper + ONE crisp glowing electric-cyan `ShockDart` barrel energy ring for QPTR clarity.
2. **[02_v14_gold_shock_bow_laser_upgrade](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/external-ai-kit/02_v14_gold_shock_bow_laser_upgrade/)** — `~4%` `ShockDart` Bow pulled back `~5–6%` (unclipping the top bow limb) + piercing diagonal cyan targeting laser.
3. **[03_v14_fp_shock_bow_panicked_bacon](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/external-ai-kit/03_v14_fp_shock_bow_panicked_bacon/)** — Double `~4%+` fusion: unobstructed huge panicked Bacon + first-person `ShockDart` tactical bow + cyan forehead star lock.
4. **[04_v14_gold_flash_canister_lock](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/external-ai-kit/04_v14_gold_flash_canister_lock/)** — New real ability (`Flash`) thrust in `4.5%` forced perspective with a blinding solar-cyan flare off the dome + compact sidearm.

[Master v14 prompts & 3-Winner analysis](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/external-ai-kit/PROMPTS_V14.md) · [Kit generator script](../../art-source/marketing/draft-duels/thumbnail-v14-4pct-evolution/scripts/build_v14_evolution_kit.py)
