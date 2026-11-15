# Payload build ledger

**Status** · Line complete in Blender (Claude, 2026-11-14 overnight; Blender only, Studio later). Brief: [concept.md](concept.md). Eight guns, no Knife-slot variant (the stock Knife stays). Order: Bulldog (hero), Ghost, Vandal, Operator, Ares, Odin, Classic, Stinger.

## Round two (2026-11-14, owner feedback: plates read as a reskin)

**Vandal v02** (`tools/blender/model_payload_vandal.py` on `model_vandal_shell_base.py`), quality bar of the Endeavour reference with original layout and marks: white enamel upper with engraved service seams, twin vents, a glowing mission-blue tube window with steel end caps and two champagne pinstripes; carbon-twill lower, receiver core and grip; a crumpled thermal-foil pillow in a graphite frame on the handguard (broad highlights, not glitter); a quilted white padded magazine on a graphite core, carbon spine, smoked-steel base with a pull loop; a graphite magwell collar; a boxy white stock with a carbon-floored window, a quilted cheek pad, a foil strap with a steel buckle, a graphite butt pad and the line's clipped foil inset with two blue marks; a white muzzle sleeve with a graphite ring and a foil crown with teeth; mission-blue trigger and selector. Owner note fixed: the grip squares crossed the grip's edge; they are now a raked grid kept fully inside the grip face. A shared bug that folded the grip outline over itself (holes in the grip side, all three Vandals) is fixed in `vandal_grip_outline`. Checks: 0 hits on the moving parts over all four clips, only the stock-position magazine-catch contact, nothing floating, widths at stock.

### Round two: rest of the line (2026-11-14, built while the owner was away)

Builder: `tools/blender/model_payload_guns2.py` on the shared helpers in `model_vandal_shell_base.py`. Every gun passed the clearance check (all moving parts and the magazine over every clip) and the floating-part check; parts that ride moving bones (slides, barrels, ammo boxes) were checked against every static part too. Grades: round-one rubric, full / Blender-scope; honest reading: a few points under the Vandals because receivers and slides with moving-part channels stay stock-shaped.

| Item | v02 build | Grade | Holds the grade back |
| --- | --- | ---: | --- |
| Bulldog | graphite handguard frame with a crumpled foil pillow, carbon grip with the raked square grid and steel cap, quilted padded magazine on a steel base, quilted cheek pad, foil strap, blue tube glow line and pinstripe, foil crown, blue controls | 84 / 89 | bullpup stock body stays stock-shaped (the magazine well is inside it) |
| Operator | boxy white stock with a carbon window, graphite butt pad, foil strap and a quilted cheek on a white cheek core; graphite / foil handguard; carbon grip; quilted magazine; white scope; glow line, pinstripe, foil inset and blue marks; foil crown | 84 / 89 | receiver stock-shaped (bolt) |
| Ares | white stock with carbon window, butt pad and strap; graphite / foil handguard; carbon grip; white drum with steel bands; trim and crown | 83 / 88 | drum and receiver stock-shaped |
| Odin | white stock with window, butt pad and strap; carbon grip; foil pillow on the ammo box (AmmoBox bone); white receiver with glow line, pinstripe, foil inset and marks (clear of the charging handle); foil crown | 84 / 89 | receiver stock-shaped |
| Ghost | suppressor rebuilt as a white housing with engraved seams, a graphite break ring and a foil crown; white slide with a blue glow line and marks (Slide bone); carbon frame and grip with the square grid kept clear of the magazine release | 83 / 88 | pistol: cladding and finishes on stock shapes |
| Classic | white slide with glow line, pinstripe and marks (Slide bone); carbon frame and grip with the square grid; blue controls | 82 / 87 | least changed silhouette in the line |
| Stinger | wire stock rebuilt as a boxy white stock with carbon window, butt pad and strap; graphite / foil handguard; white receiver with glow line, pinstripe, inset and marks; carbon grip grid; foil crown | 83 / 88 | grip stock-shaped (magazine runs through it) |

## Line language (as built)

Flight-hardware white enamel (`#E2E7ED`, satin) service panels with cool-grey bevel rims and a cool-grey or graphite second plane, black working surfaces (grips, magazines, lower frames), one rectangular champagne thermal-foil inset (`#C89B49`) with a clipped corner per gun, folded into three broad facets with a fine crumple so a few highlights break across it, and two short mission-blue alignment marks (`#2E67B2`) beside it. Static throughout. Kit: `tools/blender/model_payload_kit.py` (`panel`, `foil_inset`, `blue_marks`).

| Item | Version | Files | Grade (full rubric) | Blender-scope |
| --- | --- | --- | ---: | ---: |
| Bulldog (hero) | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Bulldog/v01/Bulldog_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Bulldog/v01/review/matched_v01.jpg) · [manifest](../../../../art-source/weapons/Skins/Payload/Bulldog/v01/manifest.json) | 87 | 93 |
| Ghost | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Ghost/v01/Ghost_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Ghost/v01/review/matched_v01.jpg) | 86 | 91 |
| Vandal | **v02** (full flight-hardware shell, awaiting owner check) | [blend](../../../../art-source/weapons/Skins/Payload/Vandal/v02/Vandal_Payload_v02.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Vandal/v02/review/matched_v02.jpg) · [manifest](../../../../art-source/weapons/Skins/Payload/Vandal/v02/manifest.json) | 87 | 92 |
| Vandal | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Vandal/v01/Vandal_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Vandal/v01/review/matched_v01.jpg) | 87 | 93 |
| Operator | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Operator/v01/Operator_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Operator/v01/review/matched_v01.jpg) | 86 | 91 |
| Ares | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Ares/v01/Ares_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Ares/v01/review/matched_v01.jpg) | 85 | 90 |
| Odin | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Odin/v01/Odin_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Odin/v01/review/matched_v01.jpg) | 86 | 91 |
| Classic | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Classic/v01/Classic_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Classic/v01/review/matched_v01.jpg) | 86 | 91 |
| Stinger | v01 | [blend](../../../../art-source/weapons/Skins/Payload/Stinger/v01/Stinger_Payload_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Payload/Stinger/v01/review/matched_v01.jpg) | 86 | 91 |

## Per item

| Item | Build | Holds the grade back |
| --- | --- | --- |
| Bulldog | White wraparound forward shoulder (ahead of the charging handle's travel) with the foil inset and two blue marks, white rear shoulder over the butt (clear of the bolt and the rear magazine), charcoal lower frame; bullpup outline and the hand clearance behind the grip unchanged | the rear magazine is plain stock |
| Ghost | Slim white slide cap (Slide bone) with a small foil segment near the slide end and two blue marks, white suppressor housing with a black break ring at the join, black frame | — |
| Vandal | Long white shell split at the receiver seam (upper / lower / handguard panels), the clipped foil inset in the handguard with blue marks, dark curved magazine with a short white base trim | — |
| Operator | White receiver shell (below the bolt band), long white fore-end over a graphite underside with a narrow foil inset below the side, scope housing in white with blue on its panel slot (optic glass, reticle and zoom untouched) | — |
| Ares | Wide white shoulder over the handguard (starting past the receiver front block so no face sits coplanar with it), modest foil inset, blue witness pair, dark lower frame; the drum stays dark | the brief's single white face segment on the drum is not added yet |
| Odin | Wide white rear panel with the compact foil inset behind the feed area (clear of the feed cover), graphite lower face, ammo box with a white outer face over a dark lower edge (AmmoBox bone) | — |
| Classic | One white slide panel (Slide bone) on the black frame, short foil trapezoid plus two blue marks, dark grip | — |
| Stinger | Short white fore-end panel over the black lower body, foil inset just forward of the main body seam, one blue fitting pair; thin magazine and stock outline unchanged | — |

All eight: **0 intersections** with every animated stock part (charging handles, bolts, triggers, selectors, slides, magazines, Odin feed cover / belt / ammo box) over Fire, Inspect, Reload and ReloadEmpty; widths equal to stock; no new part floating. Grades: round-one rubric; Blender-scope leaves out the 6 Studio-only points. **Open (Studio pass):** live ADS (Operator scope view), hands (Bulldog reload behind the grip), texture load.
