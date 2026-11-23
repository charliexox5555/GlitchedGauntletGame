# Slipframe

**Round one · Line 2 of 6**  
**Status** · The five Epic guns and Legendary Slipframe Arc are installed in the merged Studio place. The Arc's first-person animation, effects and audio passed Edit-mode checks. [Studio integration](Rework%20Ledger.md#arc-in-the-merged-place)

## Identity

Smooth blue-grey metal with an otherworldly industrial design. The body reads as an uninterrupted satin titanium shell around a darker inner frame. A broad anodised blue face meets the grey frame at one shallow seam. The signature is a short silver-blue glint that passes along the recessed seam and stops at a solid metal break. Keep broad open surfaces and crisp bevel highlights so the finish reads at first-person size.

The Intergrade Guardian reference shows long intersecting planes, cool edge reflections, and graphics tucked into the panels. The dagger shows how the same palette and bevels work at a smaller scale. Sean Bigham describes the source concept as one form encasing another, using coloured glass and circuitry. Slipframe translates that layered construction into opaque alloy with one simple metal inlay. Give Gauntlet its own silhouette and inlay placement. [Sean Bigham’s concept notes](https://bigham.artstation.com/projects/ZaBDom)

## Proposed roster and structure

| Item | Concept |
| --- | --- |
| Guardian · hero | Give the long body a smooth blue upper shell above a narrow charcoal-grey inset. Use one shallow, uninterrupted bevel along the player-facing side. End the seam at a solid grey shoulder ahead of the grip. |
| Operator | Carry the blue over a long, clean outer shell. Echo the bevel shapes on the scope housing while keeping the stock optic view, reticle, and zoom. |
| Classic | Use a broad blue cap, a charcoal-grey frame, and a short silver inlay on the left side. Keep the signature legible on a compact face. |
| Spectre | Fit a compact blue shell over the charcoal inner frame. Use a short silver-blue seam below the sightline and keep the stock suppressor profile readable. |
| Vandal | Carry a broad blue face across the upper receiver and handguard, with a charcoal lower frame. End the recessed inlay at a grey break ahead of the grip and keep the curved magazine and stock profile identifiable. |
| Knife slot · Slipframe Arc | A swept titanium crescent with a recessed cobalt inlay, a continuous frame around the open guard, and seated graphite grip pads. |

Keep gameplay behavior, sight alignment, grip anchors, and the stock gun animation set. Separate the decorative outer shell at stock moving-part boundaries and check the clearances in the normal fire, reload, and inspect clips. The first draft gets a stock ADS crop to check visibility. The line can read clearly through the outer shell and finish alone.

## Slipframe Arc

The owner asked for a new melee shape and set Legendary as the quality target after seeing the first Knife concept. The owner’s reference clip shows how a turn can briefly carry an edge effect, especially around 6–16 seconds. Arc uses Gauntlet’s RemasterV2 Knife grip and pose envelope as its starting point. Its forward-swept crescent, cut-through guard and split titanium rails are original game geometry. The [revised Blender concept sheet](../../../../art-source/weapons/Skins/Slipframe/Knife/Concept/v02/Slipframe_Arc_Concept_v02.png) supersedes the [first study](refs/Slipframe_Knife_Concept_v01.png).

- **Draw.** A quick one-handed turn rolls from the dark handle to the titanium face. The recessed inlay wakes up as the hand settles.
- **Inspect.** Hold the player-facing side for the reveal. The cobalt plate lifts out of its pocket, three contacts illuminate, and an ice-blue ribbon briefly follows a controlled wrist turn. The plate seats on the catch with a dry, close click.
- **Attack.** A thin edge trace marks the main slash frames. The heavy swing gets one longer two-tone arc. The cue disappears as the hand returns to the hold.

The Legendary grade is a target for the playable build. Check the first-person grip and clearances, readable motion at gameplay size, restrained falloff, and timed foley against the concept before assigning the tier. Keep the existing gameplay timing and first-person-only skin presentation.

### High-density Blender master

The owner asked for sleeker geometry, cleaner joins and full detail before any triangle reduction. The rebuilt titanium blade flows into a single frame around the guard. The mirrored cobalt and graphite inserts each sit in matching machined pockets. The cobalt keeps a narrow ice-blue seam for the later inspect effect.

The master uses the stock Knife Root, blade-base, blade-tip and right-grip anchors. The swept blade has its own modeled tip for future cosmetic effects through `Arc_FX_VisualTip`. The evaluated model has 16,714 triangles in ten closed mesh parts. The blade meets the frame at its seat and clears the guard opening. The geometry check found no nonmanifold edges, zero-area faces or insert intersections with their pocket walls. Five samples per stock action confirmed that the Arc follows the stock knife transform. Review the finish and shape before the optimization, effect and Studio passes.

[Blender master](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/Knife_Slipframe_Arc_hd01.blend) · [Hero render](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/Arc_Hero.jpg) · [Guard and matched-camera renders](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/Arc_Geometry_Review.jpg) · [Offline 3D comparison](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/Slipframe-Arc-share.html) · [Geometry audit](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/geometry_audit.json) · [Stock pose audit](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/hd01/pose_audit.json)

### Faceted export and motion block

The owner asked for less rounded shading, a cleaner blade-to-handle joint, and an export under 10,000 triangles before starting animation. The r01 model retains the crescent outline and replaces the soft shoulder with a chamfered alloy collar. Its blade-shaped socket clears the blade while the rear of the collar meets the hilt. The guard stays open. Using fewer loft sections and smaller pocket-corner grids brought the model from 16,714 to **7,264 triangles** with its two inspect guides and three reveal contacts.

The r01x Roblox flat FBX reimported with all 13 parts. The part bounds match the manifest within 0.000043 studs. Both sides and the rear passed a backface-culling render review. The manifest supplies the cosmetic `ArcPlate` joint, the three stock mesh prefixes it replaces, and the visual tip position for effects. The stock gameplay anchors remain in the Blender master.

The first 24 fps animation blocks are a 0.583-second draw roll and a 2.667-second inspect that turns the knife to present the cobalt face, raises the panel on two guides, and reseats it. The guided release, hold, seat and seam wake have markers for later effects and foley. Both motions return to their rest pose. Half-frame samples through the inspect confirmed that the plate and guides clear the blade while retaining at least 0.0038 studs of guide engagement. The stock playback and first-person hands remain to be checked in Studio alongside the custom effects and foley.

[r01 Blender master](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/r01/Knife_Slipframe_Arc_r01.blend) · [Hero render](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/r01/Arc_Hero.jpg) · [Collar close-up](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/r01/Arc_Guard.jpg) · [Offline 3D comparison](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/r01/Slipframe-Arc-share.html)

[FBX](../../../../art-source/weapons/Skins/Slipframe/Knife/r01x/Knife_Slipframe_RobloxFlat.fbx) · [Manifest](../../../../art-source/weapons/Skins/Slipframe/Knife/r01x/manifest_flat.json) · [Reimport audit](../../../../art-source/weapons/Skins/Slipframe/Knife/r01x/reimport_audit.json) · [Animation Blender file](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/anim01/Knife_Slipframe_Arc_anim01.blend) · [Motion preview](../../../../art-source/weapons/Skins/Slipframe/Knife/Arc/anim01/Slipframe_Arc_Motion_Block.mp4)

## Materials and details

| Role | Draft direction |
| --- | --- |
| Body | Satin titanium grey `#697785` |
| Panel | Smoky anodised blue `#23648A` with long, polished bevels |
| Dark | Charcoal `#212831` with low sheen |
| Grip | Matte microtextured graphite `#343C46` |
| Metal | Brushed silver `#A9B8C5` |
| Accent | Pale blue-grey inlay `#86AABF` |
| Neon | Ice-blue `#97D8EB`, reserved for the optional glint and tiny existing indicators |
| Brass | Cool grey casing `#9CAAB6` with one dark-blue band `#204D76` |
| Glass | Stock optic glass |

**Motion.** Show a short silver-blue sweep within one recessed inlay during the stock inspect. Keep the at-rest inlay readable as a thin strip of brushed metal. If useful, test a texture offset on a flat cosmetic insert in the Gauntlet Studio test range. Recess the insert inside the metal and check where the glint terminates. The first build can use the static strip if the sweep reads like a glow effect or projects poorly. [Roblox texture animation documentation](https://create.roblox.com/docs/parts/textures-decals)

**Ammunition.** Give the visible game cartridge and spent casing a cool grey finish and one dark-blue band. Keep the host shape, stock shot effects, projectile behavior, and ejection motion. Show the colour change in the reload detail.

**Buddy or charm.** Leave the mount empty for the draft. A small brushed-metal calibration tag with a blue inset is an option once buddies are integrated.

## References and draft order

| File | Study |
| --- | --- |
| [01_intergrade-blade.png](refs/style/01_intergrade-blade.png) | The crisp diagonal bevel and balance of blue and grey at dagger scale. |
| [02_intergrade-guardian.png](refs/style/02_intergrade-guardian.png) | The long silhouette, nested planes, and sharp blue edge highlights. |
| [03_intergrade-lineup.png](refs/style/03_intergrade-lineup.png) | The consistent metal and blue palette across weapon classes. Use the single-item images to judge how much glow belongs on the surface. |

After the six planning discussions, draft the Guardian first. Carry the reviewed hero finish into Operator, Classic, Spectre, Vandal, and the dagger. See the [saved image prompt](prompt.md) for the views and detail crops.
