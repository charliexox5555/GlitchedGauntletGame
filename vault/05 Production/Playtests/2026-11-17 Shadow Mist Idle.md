# Shadow Mist idle playtest

**2026-11-17.** Match place `133387545285290`, solo Studio range with `TestMode` temporarily enabled. The owner asked to start with idle animation and color. Source is [Ruin-Blighted v03](../../02%20Art/Skins/RuinBlighted/Build%20Review.md#shadow-mist-v03-pistol-grip-and-studio-idle).

- [Hip capture](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/studio_hip.jpg) | [ADS capture](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/studio_ads.jpg) | [Runtime samples](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/studio_playtest.json)
- The F7 preview path selected the imported Vandal. In hip, all four cosmetic child motors breathed on a 3.8-second cycle, three teal inlay parts changed color and both mist emitters were enabled with the Gauntlet vapor texture loaded. A visible shard changed position relative to the receiver by 0.0073 studs over one sample interval.
- Right-click changed the camera from 80 to 68 FOV. Both mist emitters disabled, all four shard transforms returned to rest, and the inlays settled to their base teal. The front post stayed clear in the fractured rear sight. Releasing ADS restored the idle effects. Switching to Stock removed both emitters from the camera model.
- Checked 54 mesh welds and the matching AimPoint, grips, muzzle, ejection and charm locators in Studio Edit. The serialized model was deserialized to verify its rig, mesh count and mist marker. Returned to Edit and restored the original `TestMode = false` and `AuthorityMode = Automatic`.
- Scope is the local camera idle. The shipped player actions and release are later phases. The low-graphics and reduced-motion preference checks remain open.

Setup follows [Skin Build Pitfalls](../../02%20Art/Skins/Skin%20Build%20Pitfalls.md) and [Particle Emitters In Depth](../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Particle%20Emitters%20In%20Depth.md).


## Readability pass after owner review

The first idle looked static in the owner's daylight range view. The original breakdown already held the Shadow Mist base and three chromas. The owner confirmed the crown removal and delegated the motion and effect tuning. Reused v03 and tuned from the actual range camera.

- Raised shard lift from 0.021 to 0.14 model studs and added up to 11 degrees of tilt on a three-second loop. The front shard ranged from 7.5 to 46.7 pixels from its rest position in the 1920-pixel-wide range viewport. That movement was measured relative to the stock rig.
- Added two tapered teal tethers under the fore-end shards, a point light at each existing seam socket, broader upward wisps and a softer haze beneath them. All four emitter textures loaded in the range. The receiver and magazine inlay pulse reads at hip in daylight.
- ADS reached 68 FOV with all eight idle effects disabled, the four motors at rest and all seven sight MeshParts visible. Released ADS and confirmed both lights returned at 80 FOV. The same local range session is open for the owner to review.

[Hip capture](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/idle_readability_hip.jpg) | [ADS capture](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/idle_readability_ads.jpg) | [Measured samples](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v03/review/idle_readability_samples.json)


## v04 full shard motion and continuous seafoam light

The owner asked for motion across all of the loose pieces and for the energy to stay visible whenever the gun is held. The installed Match preview now animates 15 loose fragments and nine larger outer plates. Their direction and timing vary across the handguard and stock.

- All 24 moved in the Studio range at hip. The new cowl and receiver veins, magazine bindings and stock wrap use phased seafoam highlights and four local lights. Narrow tethers span the gaps under the larger fore-end and stock plates.
- The final ADS shot showed two lit fissures below the fractured ring. The front post stayed unobstructed. All four lights and all four tethers remained active at 68 FOV as the shards settled and the airborne mist cleared.
- The inspect kept all four lights active. During a tactical reload, the receiver stayed lit. The magazine light turned off while the stock reload hid the magazine and returned with it. Left the range open at hip with v04 equipped.
- The Blender motion sweep checked all 24 rigid pieces at 48 phases with zero new mesh or archived hand-block intersections. The lowest fore fragment travels forward and outward to clear the supporting hand.

[Hip](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/review/studio_hip.jpg) | [ADS](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/review/studio_ads.jpg) | [Inspect](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/review/studio_inspect.jpg) | [Studio samples](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/review/studio_samples.json) | [Motion clearance](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v04/review/idle_clearance.json)


## v05 full-body lighting and moving aperture

The owner's concept shows a bright narrow energy core with a translucent teal falloff. v05 uses that balance across both flanks, the magazine binding and the entire rear assembly. The fore-end and stock collars have two-sided moving ribbons with tinted smoke. The magazine effect inherits magazine motion and visibility.

- The Match range measured all 33 body pieces and eight rear-sight pieces moving at 80 FOV hip and 68 FOV ADS. ADS keeps all six lights, 24 beams, and the glowing fractured ends active. It reduces the travel and clears airborne smoke and the broad aura from the sight picture.
- Inspect kept all six lights and seven localized auras active. A tactical reload moved the magazine 0.645 studs, culled its effects while hidden, and restored them with the magazine. Receiver light stayed active.
- Both full-gun captures ran the same local effects module on the installed Studio asset in a temporary client review stage. The range captures use the actual gameplay camera. The review stage was removed after capture.

[Full-body lighting](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_full.jpg) · [Far side and underside](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_underside.jpg) · [Hip](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_hip.jpg) · [ADS](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_ads.jpg) · [Inspect](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_inspect.jpg) · [Measurements](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/studio_samples.json)


## v05 soft idle polish

The owner asked for a quiet, steady idle. Six local emitters now place a thin seafoam haze at the handguard, receiver, magazine, collar and heel. The smoke rises slowly and fades close to the gun. Twelve narrow stationary tethers and six close lights support the emissive seams with a small brightness change over the loop. This pass removes the broad animated ribbons and foreground aura sprites from the v05 test.

Read the live Workspace RIVALS asset pack in Match Studio. The closest samples were low-emission, fading smoke layers from explosion effects. Used that falloff idea with the existing Gauntlet frost mist texture, sized for the viewmodel. [RIVALS effect research](../../03%20Research/Rivals%20Reference/Body%2C%20Viewmodel%2C%20Guns%20and%20VFX.md)

Local Match Solo verified six steady emitters at hip and inspect, with four particles per second per emitter at hip. The 68 FOV aim kept all six lights and eight moving rear-sight fragments active with the front post unobstructed. Tactical reload culled the light and smoke as the magazine was hidden and restored both when it returned. The receiver stayed lit through the action.

[Hip](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/polish_hip.jpg) · [ADS](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/polish_ads.jpg) · [Inspect](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/polish_inspect.jpg) · [Studio measurements](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/polish_samples.json)


## v05 first-person action effects

The owner approved the quiet idle and requested a coordinated draw, firing, reload and inspect pass. The passive finish grades 9/10 in the local range. The action effects use the same sustained seafoam light and build short accents into the existing motion. The draw and inspect use their track time. The reload follows the native magazine markers and seating pose. [VFX timing reference](../../LihFolk/08%20Animation/05%20Systems/VFX%20Timing%20with%20Animation.md)

- **Draw.** The 66 outer shard mesh groups fade in as the plates converge from a short mist burst and settle at the core. Studio measured the fully hidden start, partial assembly and all 66 opaque after the close. The low-pitched lock cue played during the draw.
- **Fire.** A sharp teal flash, tapered teal tracer, short muzzle vapor and brief fore-end light pulse accompany the regular shot. A trigger tap from the open inspect completed the recovery in about 0.17 seconds. The measured barrel alignment rose from a 0.32 to a 0.98 dot product with camera forward before the flash.
- **Reload.** The detached magazine fell and faded, the replacement became solid beside the support hand, and the new magazine reached its seated transform. Tactical and empty reloads passed. The empty reload still exercised the action bone.
- **Inspect and ADS.** The dedicated upward turn allowed all 33 body shards to open. The measured excursion was 0.29 studs at the capture point. Transitioning to ADS brought the body excursion under 0.024 studs with all six lights active and the idle smoke clear.

Studio captures were slowed or frozen on the action beats. Playback was restored to normal and v05 was left equipped in the local Match range. StyLua, Selene and both Rojo builds passed.

[Draw](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/draw.jpg) · [Firing](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/firing.jpg) · [Magazine release](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/reload_release.jpg) · [Magazine forming](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/reload_form.jpg) · [Inspect](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/inspect.jpg) · [Measurements](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/actions/studio_samples.json)
