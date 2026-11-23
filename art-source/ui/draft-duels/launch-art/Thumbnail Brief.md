# Draft Duels thumbnail production brief

Use the supplied Draft Ticket logo, Roblox Studio match assets, and the game’s own first-person viewmodel. Black and Lobby Gold `#FFD23F` lead the brand. Blue and orange identify teams where the shot calls for them. The gold fighter is an unadorned, faceless Roblox silhouette with a light gold rim. The bacon wears Roblox’s Pal Hair, Blue and Black Motorcycle Shirt, and Dark Green Jeans.

Build and pose the dressed S15 avatars in a separate copy of Match Studio. Use the in-game third-person stance and grip for stills and the in-game viewmodel for first person. Capture a clean avatar, weapon, map and effects plate before compositing. Keep elbows, wrists, and both weapon contacts visible in a check angle. The starter Blender rig is a local lighting and accessory study. Use the actual S15 rig for release poses.

Render each shot at 1920 × 1080. Preserve the clean plate, transparent FX or UI, and layered master. Check the final at 256 × 144. Overlay the supplied logo after rendering wherever indicated. Use the attached style studies as composition reference.

## 1. Gold Duelist

**Prompt.** A wide three-quarter portrait of a single faceless gold Roblox S15 duelist in Draft Duels’ Canyon Outpost. Frame the duelist on the right with their actual Vandal, stock carried close to the shoulder, right hand around the grip and left hand supporting the handguard. Let the map’s industrial timber and stone cover recede to the left. Keep the background cooler and darker than the duelist. Use a narrow warm rim and enough contrast to show the head and arms at a glance. Make a second version with the same framing and a classic bacon avatar. Leave the upper left clear for the supplied Draft Ticket logo.

**Inputs.** CanyonOutpost, stock Vandal, third-person AimLevel, gold S15 and bacon S15 variants.

## 2. Foundry Slide

**Prompt.** Draft Duels first-person action at real slide height inside Foundry4. The actual Vandal viewmodel enters from the bottom right and the barrel leads to one orange opponent beyond the furnace runner. Show the slide through the low viewpoint, a tilted horizon, and the nearside wall moving past. Use one short tracer and a tight muzzle flash. Let the finished Foundry architecture read in a single warm plane behind the opponent.

**Inputs.** Foundry4, Vandal in the viewmodel, game slide pose and camera, orange S15 opponent, existing muzzle flash, tracer, and foundry lighting.

## 3. Draft Firewall

**Prompt.** A classic bacon avatar controls a bright angular Firewall curtain in a Draft Duels match. Place the bacon on the left, the moving leading edge through the center, and the orange opponent offset on the far right. Use the actual Firewall visual vocabulary, including a jagged opaque curtain, a bright leading edge, and a few embers. Leave room for one large selected Firewall card from Draft Duels’ UI. Keep the card and the effect independently readable at tile size.

**Inputs.** Foundry4 or CanyonOutpost, Firewall meshes and effect, bacon S15, orange S15, current DraftScreen card layout and Firewall icon. Composite the card after rendering.

## 4. Rooftop 2v2

**Prompt.** Draft Duels 2v2 on Rooftops4, seen from player height across real cover. Frame two blue silhouettes in the foreground and two orange silhouettes across the lane. Allow visible space between teammates. Place one fighter higher on the rooftop structure to show the map’s verticality. Use a cool open sky, friendly cyan-blue highlights, warm orange opposing highlights, and a clean center line between teams. Keep the neutral structures quieter than the four avatars.

**Inputs.** Rooftops4, blue and orange S15, stock Vandal and a second in-game weapon, game cover and height differences.

## 5. Snowpeak Inspect

**Prompt.** First-person Draft Duels weapon inspect at Snowpeak4. Frame an approved release skin diagonally across the view using its actual inspection pose and both hands. Use the map’s cold ambient light to separate the weapon silhouette. Show a single bright skin effect along the actual seam or receiver. Keep the background quiet with enough visible terrain and structure to identify Snowpeak. Reserve the corners for the hands and the weapon’s silhouette.

**Inputs.** Snowpeak4 and Slipframe Vandal r03x are the first combination to shoot. The local skin master is included. Match the installed version and use its in-game inspect pose and seam effect.

## Square icon

Use the faceless gold Roblox head against charcoal, with one soft rim and the approved wordmark. Keep the head large and center the identifying shape in the safe area. The bacon alternative should retain the actual Roblox hair, expression and shirt blue. Use the packaged square candidates and 48-pixel previews for comparison. The Gold icon is the initial editorial pick.

## Asset locations

| Asset | Source |
| --- | --- |
| Match place | Roblox Studio place 133387545285290, inspected in Edit |
| Runtime maps | `Workspace.CanyonOutpost`, `Foundry4`, `Rooftops4`, `Snowpeak4` |
| Runtime gun and skin | `ReplicatedStorage.Weapons.Vandal`, `ReplicatedStorage.WeaponSkins` |
| Runtime card and Mods | `StarterGui.DraftScreen`, `ReplicatedStorage.UiTemplates`, `ReplicatedStorage.Abilities`, `src/shared/Config/Mods.luau` |
| S15 combat body | `src/shared/Config/Avatar.luau`, `src/shared/MatchBody.luau` |
| Actual poses and grips | `src/shared/Config/Animations.luau`, `tools/anim/tp_clips.py`, `src/client/Controllers/GripController.luau` |
| First-person staging | `src/shared/Config/Viewmodel.luau`, `src/client/Controllers/ViewmodelController.luau` |
| Bacon outfit | Roblox Pal Hair 63690008, motorcycle shirt 144076358, jeans 144076760 |
| Brand | `art-source/ui/draft-duels/draft-ticket-lobby-gold` |

The asset ZIP includes the authored map kits, Match layout captures, cached map images, weapon and FX masters, hold and slide clips, logo, card icon, and the three bacon wardrobe inputs. The map kits provide props and the layout JSON provides placement and material data. Use the actual Match place for full geometry where the package has a mesh ID reference.
