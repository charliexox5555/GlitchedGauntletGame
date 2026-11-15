# Sealwork build ledger

**Status** · Line complete in Blender (Claude, 2026-11-14 overnight; Blender only, Studio later). Brief: [concept.md](concept.md). Order: Marshal (hero), Vandal, Guardian, Shorty, Sheriff, Sealwork Dagger.

## Round two (2026-11-14, owner feedback: plates read as a reskin; dagger unlike the Ruin example)

Full sculpts at the Ruin reference's quality bar, original shapes, checked with the owner one item at a time.
- **Sealwork Dagger v02** (`tools/blender/model_sealwork_dagger.py`): a talon blade rising to a raised tip with a hooked tooth near the guard, gold edge and spine lines, a dark fuller built into the blade section; a gold guard with swept flame flares, a spine thorn and a gold ferrule; a new carved grip of overlapping slanted bands with gold studs (stock section where the fist sits); a faceted pommel holding a vermilion gem in a clipped-corner gold setting, ending in a gold-rimmed talon hook.
- **Sealwork Vandal v02** (`tools/blender/model_sealwork_vandal.py` on `model_vandal_shell_base.py`): black-jade upper with a gold ridge and gold frame lines, swept gold talons on the handguard shoulders (kept low and outside the sight picture), gold-framed leaf windows onto a vermilion core, filigree with scroll curls, the clipped seal behind the magazine well, a single sculpted looped stock growing out of the receiver with a gold scroll and gem, a red crystal magazine in a gold shoe with a gold spine and line, a gold magwell collar, a solid matte-charcoal grip seated into the receiver (gold rim, one gold line along its fold, a cap cut from its own outline), gold barrel, crown and collar. Owner notes fixed in this build: grip not connected and reading hollow (glossy black mirrored the sky; now matte and seated), the lower stock strut starting in mid-air (stock is now one piece), the magazine reading half-empty (satin ruby). Checks: 0 hits on the bolt, charging handle, trigger and selector over all four clips; the magazine clears the collar through both reloads; only the stock-position magazine-catch contact; nothing floating.
- Kit changes: richer gold with a faint roughness drift, a satin marbled jewel red, a softer black-jade coat.

### Round two: rest of the line (2026-11-14, built while the owner was away)

Builder: `tools/blender/model_sealwork_guns2.py` on the shared helpers in `model_vandal_shell_base.py`. Every gun passed the clearance check (all moving parts and the magazine over every clip) and the floating-part check; parts that ride moving bones (slides, barrels, ammo boxes) were checked against every static part too. Grades: round-one rubric, full / Blender-scope; honest reading: a few points under the Vandals because receivers and slides with moving-part channels stay stock-shaped.

| Item | v02 build | Grade | Holds the grade back |
| --- | --- | ---: | --- |
| Guardian | jade handguard with gold-framed red leaf windows and gold talons, looped stock with gold scroll and gem, red crystal magazine in a gold shoe, carved grip with gold line and cap, notched receiver plate with the seal and filigree | 85 / 90 | receiver stays stock-shaped (bolt / charging-handle channel) |
| Marshal | jade fore-end with leaf windows and talons, carved butt with a dark relief, gold scroll and gem enclosing the stock rear (wrist stays stock in jade), jade-and-gold scope with collars, gold barrel, lever and hammer, sealed receiver plate | 85 / 90 | long gold barrel and tube are a lot of gold |
| Shorty | new jade barrel shroud riding the Barrels bone with leaf windows, talons and a gold collar; sealed frame plate with filigree; frame and grip stay stock in Sealwork finishes (their cut-outs hold the barrels, latch, shells, trigger) | 84 / 89 | frame silhouette is stock |
| Sheriff | jade barrel shroud with a red leaf window and talons, gold cylinder, carved grip with gold rim and seal gem, sealed rear plate | 83 / 88 | stock Reload drives the speedloader through the frame / grip (stock clip issue, same frames as round one) |

## Line language (as built)

Polished black-jade faces (`#202825`, clear-coated, low-frequency stone drift) with a charcoal-green second plane, warm gold rim chamfers as the sparse gold frame lines (`#C49543`), one clipped-corner vermilion seal (`#8F222D`, jewel coat) with an original offset groove in a two-step gold setting, narrow gold collars. Large dark areas carry the line so the gold breaks read at first-person size. The seal is static (the brief's optional drifting highlight during inspect is a Studio prototype on the seal's own chamber mesh). Kit: `tools/blender/model_sealwork_kit.py` (`jade_plate`, `seal`, `collar`).

| Item | Version | Files | Grade (full rubric) | Blender-scope |
| --- | --- | --- | ---: | ---: |
| Marshal (hero) | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Marshal/v01/Marshal_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Marshal/v01/review/matched_v01.jpg) · [manifest](../../../../art-source/weapons/Skins/Sealwork/Marshal/v01/manifest.json) | 86 | 91 |
| Vandal | **v02** (full sculpted shell, awaiting owner check) | [blend](../../../../art-source/weapons/Skins/Sealwork/Vandal/v02/Vandal_Sealwork_v02.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Vandal/v02/review/matched_v02.jpg) · [manifest](../../../../art-source/weapons/Skins/Sealwork/Vandal/v02/manifest.json) | 87 | 92 |
| Vandal | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Vandal/v01/Vandal_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Vandal/v01/review/matched_v01.jpg) | 86 | 91 |
| Guardian | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Guardian/v01/Guardian_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Guardian/v01/review/matched_v01.jpg) | 85 | 90 |
| Shorty | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Shorty/v01/Shorty_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Shorty/v01/review/matched_v01.jpg) | 86 | 91 |
| Sheriff | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Sheriff/v01/Sheriff_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Sheriff/v01/review/matched_v01.jpg) | 83 | 88 |
| Sealwork Dagger (Knife slot) | **v02** (full sculpt) | [blend](../../../../art-source/weapons/Skins/Sealwork/Dagger/v02/Dagger_Sealwork_v02.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Dagger/v02/review/matched_v02.jpg) | 86 | 91 |
| Sealwork Dagger (Knife slot) | v01 | [blend](../../../../art-source/weapons/Skins/Sealwork/Dagger/v01/Dagger_Sealwork_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Sealwork/Dagger/v01/review/matched_v01.jpg) | 84 | 89 |

## Per item

| Item | Build | Checks (Blender) | Holds the grade back |
| --- | --- | --- | --- |
| Marshal | Long black-jade receiver, fore-end and stock faces framed by gold rims; the seal on the receiver's rear shoulder near the stock; one narrow gold collar on the outside of the scope | 0 intersections incl. lever, hammer, bolt and the shell path; the stock face was re-seated after floating 1 mm off the stock | — |
| Vandal | Broad dark receiver faces with thin gold frames, a handguard face, the seal behind the magazine well, a small matching vermilion accent on the magazine base (Mag bone) | 0 intersections; widths at stock | — |
| Guardian | Long black-jade side plane with a gold border tapering toward the front, short vermilion seal below the rear profile | 0 intersections; widths at stock | quiet by design; the seal is small at range |
| Shorty | Compact black-jade body plate with the red seal, one short gold collar on the barrels (Barrels bone, tips with them) | 0 intersections incl. the break-open barrels, latch and shells | — |
| Sheriff | Black-jade top strap over the cylinder window, the seal on the upper rear band behind the cylinder, thin gold front band on the barrel | The stock Reload already drives the speedloader and rounds through the stock frame (frames 5-56) and grip (15-56). The seal band sits above most of that path; 13 frames still cross it (was 21 behind the cylinder). No skin part touches the cylinder, crane or ejector. | stock reload clip clips the frame; worth fixing in the Sheriff animation, not the skin |
| Sealwork Dagger | Compact smooth-curved blade (no hook, lower guard than Moltframe's), black-jade blade face, short gold bevel on the forward third of the edge, gold guard, sculpted black grip on the stock grip core, clipped pommel holding the recessed seal in its gold setting | Inspect / Slash1 / HeavyStab poses rendered with the stock Knife clips | the brief reserves draw / slash / heavy / inspect frames for the owner's Ruin Dagger video (still pending) |

Grades: round-one rubric (look 30, fit 25, ADS/animation 20, craft 15, evidence 10). Blender-scope leaves out the 6 Studio-only points. **Open (Studio pass):** live ADS (Marshal scope view), hands, texture load, optional seal highlight drift, Ruin Dagger video for the dagger's poses.
