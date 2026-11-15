# Slipframe build ledger

**Status** · Line complete in Blender (Claude, 2026-11-14 overnight, owner's call: Blender only, Studio later). Brief: [concept.md](concept.md). Hero first (Guardian), then Operator, Classic, Spectre, Vandal, Dagger.

## Line language (as built)

Satin titanium shell (brushed, ±3.5% value drift) around a charcoal inner frame; broad smoky anodised blue faces `#2E5E7D` with polished bevel rims `#CFDBE7`; one recessed silver-blue inlay strip per item that stops at a solid grey break; raked vents with dark floors on long handguards; open-triangle frame stocks; blue faces on magazines and butts. Opaque alloy only (no glass, no circuit glow). Motion: a short silver-blue glint runs along the inlay once per 6 s loop (frame-driven emission band; static at rest = plain brushed strip, which is also the baked map). Kit: `tools/blender/model_slipframe_kit.py`.

| Item | Version | Files | Grade (full rubric) | Blender-scope |
| --- | --- | --- | ---: | ---: |
| Guardian (hero) | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Guardian/v01/Guardian_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Guardian/v01/review/matched_v01.jpg) · [glint loop](../../../../art-source/weapons/Skins/Slipframe/Guardian/v01/review/glint_motion_loop.webp) · [manifest](../../../../art-source/weapons/Skins/Slipframe/Guardian/v01/manifest.json) | 89 | 95 |
| Operator | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Operator/v01/Operator_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Operator/v01/review/matched_v01.jpg) | 89 | 95 |
| Classic | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Classic/v01/Classic_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Classic/v01/review/matched_v01.jpg) | 88 | 94 |
| Spectre | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Spectre/v01/Spectre_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Spectre/v01/review/matched_v01.jpg) | 88 | 94 |
| Vandal | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Vandal/v01/Vandal_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Vandal/v01/review/matched_v01.jpg) | 88 | 94 |
| Slipframe Dagger (Knife slot) | v01 | [blend](../../../../art-source/weapons/Skins/Slipframe/Dagger/v01/Dagger_Slipframe_v01.blend) · [sheet](../../../../art-source/weapons/Skins/Slipframe/Dagger/v01/review/matched_v01.jpg) | 87 | 93 |

Grades use the round-one rubric (look 30, fit 25, ADS/animation 20, craft 15, evidence 10). Blender-scope leaves out the 6 Studio-only points (live ADS and hand contact, Studio texture load, Studio captures).

## Per item

| Item | Build | Checks (Blender) | Holds the grade back |
| --- | --- | --- | --- |
| Guardian | New titanium shell (rear / channel / front lofts, mirrored channel for the charging handle +Y and bolt -Y, magwell cavity), blue vented handguard face, blue receiver cap, charcoal inset band with the inlay ending at a grey shoulder (x .90), frame stock, blue magazine face with a vertical inlay; stock rail, sights, lower receiver, bolt catch, selector, grip, barrel kept | 0 intersections (charging handle, bolt, trigger, selector, bolt catch, magazine) over Fire / Inspect / Reload / ReloadEmpty; widths stock / +6% handguard; 2 stock pins re-seated (only the lower-receiver pins kept) | inlay reads thin from the far side |
| Operator | Stock receiver (bolt channel) and scope kept; blue receiver faces below the bolt band clear of the handle's travel, inset inlay ending at a grey shoulder, new titanium handguard with blue vented face and inlay, faceted blue bevel collars on both scope bells (outside the tube: optic view, reticle and zoom untouched), frame stock kept under the bolt line, blue magazine face | 0 intersections (bolt incl. handle travel, trigger, magazine); widths equal to stock; nothing floating | scope tube itself stays stock dark |
| Classic | Blue cap plates on the slide (Slide bone, move with it), short inlay ending at a grey break, polished rails either side of the sight line (below the notch), charcoal frame and grip panel | 0 intersections incl. slide-borne caps vs frame parts over every clip; sight picture unchanged (review aim point at the rear-notch height: the stock Classic has no AimPoint empty) | a grip inlay was dropped after a failed boolean (one short inlay per the brief) |
| Spectre | Stock receiver, skeletal stock and suppressor re-finished; blue vented handguard face, inset inlay ending at a grey break, blue rear receiver face, charcoal magwell face, blue magazine face, blue butt face; nothing placed in the charging ring or bolt travel | 0 intersections; widths equal to stock | mostly a finish pass on the receiver |
| Vandal | Stock receiver, curved magazine and triangle stock kept; broad blue face across the upper receiver (above the channel) and the handguard (vented), charcoal lower frame, inlay along the lower receiver ending at a grey break ahead of the grip, blue magazine face with inlay, blue butt face | 0 intersections; widths equal to stock; flagged "floating" items are stock indicator strips, pins and magazine internals in their stock positions | upper face is a band (the channel takes the middle) |
| Slipframe Dagger | Asymmetrical tanto wedge: wider cobalt grind on the player side, brushed silver faces, graphite spine; slim dark handle on the stock grip core (hand surface and Knife clips unchanged) with a short inlay; angular titanium guard and pommel with cobalt bands | Inspect / Slash1 / HeavyStab poses rendered | wrist and knuckle checks need the arms (Studio) |

**Open (Studio pass, later):** live ADS, viewmodel hands, Roblox texture load, inlay glint motion test (same `ChamberFlow` path with a glint tile), world-model read. Charm loops on Guardian / Operator / Spectre / Vandal sit half inside the inset bands (cosmetic mount; check in Studio).
