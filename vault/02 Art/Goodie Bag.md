# Goodie Bag (Season 1)

2026-11-27. The battle pass goodie bag: a chunky faceted gift sack tied at the neck, used for the Backpack and Shop card, the pass tile and the in-world opening. It's our own design in the spirit of a shooter goodie bag; nothing is copied from RIVALS. Built in a second live Blender (bridge on port 9881, PID 16516, started with `tools/blender/start_bridge.py`); the owner's Blender on 9876 wasn't touched.

## Files
- **Builder:** `tools/blender/crates/build_goodie_bag.py`. Exec it in a live Blender with `{"VERSION": "vNN"}`. It refuses to overwrite an existing version.
- **Masters:** `art-source/crates/GoodieBag/GoodieBag_vNN.blend`, with `.fbx` and `.json` (stats) beside them. **v03 is final.**
- **Card icon:** `art-source/ui/shop/bags/bag_season1.png`, 512², transparent, 3/4 view.
- **Review renders:** `art-source/crates/GoodieBag/review/v03/`. The `_sheet.png` covers the hero, sides, back, tie, tag, patch, base and top views, and the magenta back-face checks of the tie, tag and base. `_close.png` shows the tag and tie close up.

## Parts (Group_Role, painted by `Shared/CrateLook` from a `Config/Crates` tier)
| Part | What | Palette in Blender |
|---|---|---|
| `Sack_Body` | the 10-sided sack; pleats gather into the neck | 2C1650 |
| `Sack_Frame` | the cut-corner front patch | 47297C |
| `Sack_Light` | the cyan four-point sparkle (plus a small one) on the patch | 3FE0F2, emission 1.3 |
| `Sack_Interior` | a dark neck cap, hidden until the top lifts | 140A24 |
| `Top_Frame` | the hollow, scalloped 16-facet ruffle | 47297C |
| `Top_Interior` | the dark floor inside the ruffle | 140A24 |
| `Top_Hardware` | the tie band, knot, bow loops, V-notched tails, tag cord and tag plate (one exact union) | FFC83D plastic |
| `Top_Gem` | the raised star on the tag | F03CA8, emission 1.3 |

**Pivots:**
- `Sack` sits at the base centre (0, 0, 0).
- `Top` sits at the neck, (0, 0, 1.221) in Blender (Z up), which is Roblox Y 1.221. An opening can pop the top off the neck.
- Height is 1.60 studs.

## Versions
- **v01:** the first pass. It read as a pot or jar: a straight barrel wall, a cyan hem ring at the base and a wide 10-sided rim. The pixel emblem looked like a figure.
- **v02:** a rounder sack with a wide belly and pleat folds the whole way up. The hem ring is gone. The ruffle has 16 facets with deep pleats. The patch and tag sit on exactly planar pleated facets. The bow loops are bigger, lie along the band's facets and are buried 0.02. The tails are shorter and rest on the shoulder. The emblem became a pixel cross, which read as a plus sign.
- **v03 (final):** the emblem is a cyan four-point sparkle with a small sparkle beside it. The ruffle points are shallower so it doesn't read as a crown.

## Checks (v03)
- 2,500 tris, under the ~3k budget.
- Every part: 0 non-manifold edges, 0 smooth faces, no subdivision.
- 0 coplanar face pairs between parts.
- One island per part, except `Sack_Light`: its 2 sparkles are both seated on the patch.
- Union before bevel: each part's shells go through an exact union, then a 1-segment bevel with a 40° angle limit, so the facets stay flat and only real corners are chamfered.
- The magenta back-face renders show no holes or flips.

## Grade (v03): 9/10
| Area | Score | Note |
|---|---|---|
| Silhouette | 9 | reads as a tied gift sack in the Backpack card and at a distance |
| Crispness | 9 | flat facets with 1-segment chamfers; no curves |
| Layering | 9 | patch, sparkle, tag and star each have their own lift (0.012 to 0.02) |
| Connections | 9 | band, knot, loops, tails and cord buried 0.02+; tag and patch sit in the sack's facets |
| Palette | 9 | Season 1 purple and violet, a gold tie, one cyan and one magenta accent |
| Budget | 10 | 2.5k tris |

## Uploaded
- **Model:** asset `100430777047300`, from `GoodieBag_v03.fbx`.
- **Card icon:** decal `130134893356594`. Resolve the image id in Studio.
