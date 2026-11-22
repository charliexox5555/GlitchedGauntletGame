---
name: gauntlet-build-style
description: Apply Gauntlet's faceted modeling and worldbuilding direction to maps, Lobby rooms, fixtures, signs, props, weapons and Mod models in Blender or Roblox Studio.
---

# Gauntlet build style

Read [Style Bible](../../../vault/02%20Art/Style%20Bible.md), [Art Direction](../../../vault/02%20Art/Art%20Direction.md) and the area brief. For any multi-part model, also load `gauntlet-model-joins` (union-before-bevel, seated details, close-up join renders). Active hub is Lobby V5 ([Lobby V5 Plan](../../../vault/02%20Art/Lobby%20V5%20Plan.md)); Lobby V4 and light-grey Sunwell belong to older builds.

- Use planar facets and weighted or flat normals. Build curves from visible angled plates, typically 6–12 on large round forms. End bars, frames and walls with readable tapers, cuts or chamfers. Start with a silhouette, then secondary forms, then details at real joints.
- Give every junction a deliberate transition such as a flange, collar, plinth, bracket or shadow gap. Keep reusable objects separate with their own meshes, colliders and lights. Reuse the area builder and kit for consistent profiles and instancing.
- Use matte, faint texture variation and one room accent. Frame screens quietly and build them with SurfaceGui. Keep sign mounts and colliders seated or inset. Assess light pools and Neon in Studio at player height.
- For a new visual style, use the owner's reference interview in [Model Style Interview](../../../vault/02%20Art/Model%20Style%20Interview.md). Write the agreed method and show a small representative piece before committing the full build.
- Audit gaps, coplanar surfaces, unintended intersections, collider step-ups and sightlines. Capture a close-up and the actual player view when reviewing new geometry. Log the result in the area note. The [original modeling field notes](../../../.claude/skills/gauntlet-build-style/SKILL.md) contain builder helpers and case-specific measurements.

## Exotic weapon families

Use the approved hero weapon as the look-development fixture, and follow the [Elite skin playbook](../../../vault/02%20Art/Skins/RuinBlighted/Elite%20Skin%20Playbook.md). For Ruin-Blighted, that fixture is Shadow Mist Vandal v05. Carry the actual approved material datablocks and Studio material roles across the family. Rebuild each visible chassis around its current stock host's rig and contact points. Shape the receiver, barrel housing and stock before placing shards, then seat the shards in deliberate breaks and use the hero's seam and lighting vocabulary. Verify the installed mesh version and compare stock, hero and candidate at gameplay scale in Match Studio, including the real ADS camera and scope.
