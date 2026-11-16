--!strict
-- Combat feedback and movement cues. Config/GunSoundAssets and
-- Config/SharedSoundAssets map symbolic cue names to complete audio assets.

return table.freeze({
	LowAmmo = "gun:gun_semi_auto_rifle_safety_switch_03|gun_rifle_safety_switch_01", -- a small click on each shot from a near-empty mag (pro pack)

	-- Feedback (2026-11-05: real CC0 recordings; the synthesized v2 ones are
	-- still in the atlas: HitTick, HeadDing, Kill, KillHead, to go back).
	-- 2026-11-09 (owner: RIVALS / Valorant): an impact for a body shot, a
	-- prominent slash for a headshot, a boom + ring for a kill that climbs per
	-- kill in the round (Config/Audio KILL_LADDER, Util/KillFeed). Gun atlas
	-- slices (tools/audio/build_gun_sfx.py hit_clips). The 2026-11-05 glass
	-- clink / fork / bell are still atlas:HitConfirm / HeadConfirm / KillConfirm.
	--
	-- 2026-11-13 (owner: "the impact sounds are pretty bad"): all from the pro
	-- pack, layered short (tools/audio/build_pro_atlas.py built_clips). Each has
	-- an A and a B take in the atlas: swap the letter here to try the other.
	-- Body: a punch + a slap's snap (B: wet punches). Head: the wood block's
	-- bright tonal tock over a punch (B: a slap + a sheet-metal ring). Kill: a
	-- sheet-metal clang over a wet punch (B: the wood block's ring + a slap).
	-- 2026-11-13 (owner): the hit marker is his pick, "hitmarker_2" (a 66 ms
	-- click, uploaded by NeoDoesStuff), and plays on EVERY hit, kills too
	-- (WeaponController). A headshot adds HitHead on top: a high metallic
	-- "shing" (RIVALS / Valorant), a sword unsheathe's ring sped up 1.5x over a
	-- sped-up fast whoosh (CC0 + pro pack; takes A / B / C, swap the letter).
	-- The pack-built hits are still gun:hit_body_A/B, gun:hit_head_A/B.
	HitBody = "rbxassetid://125235091454234",
	-- 2026-11-15 (owner's pick, "H5", from a batch built to measurements of
	-- his own RIVALS clip): a deep thump under a clean bell-like ding (a struck
	-- wine glass tuned to the clip's 5.0 and 3.1 kHz partials, about a tenth
	-- of the sound's energy), three takes a few % apart in pitch as in the
	-- clip. tools/audio/hit_candidates.py final. Was "gun:hit_head_A" (a
	-- wood-block tock over a punch).
	-- 2026-11-15, later (he did not like H5 in the game, nor any ding or
	-- shing: "annoying", "too metallic"; his pick from batch 5: "H18"): a
	-- bright bubble pop with a short dry crack on its front, the kill pop's
	-- (kill_F) crisper, higher sibling. No metal, no ring. Three takes 3%
	-- apart in pitch. tools/audio/hit_candidates.py final-head. Was
	-- "gun:hit_head_E" (H5).
	HitHead = "gun:hit_head_F",
	-- 2026-11-14 (owner: "a nice little positive kind of thing", RIVALS /
	-- Valorant): a CC0 game pop over a short punch; C a warm pop, D a brighter
	-- one (kill_head_* add a faint ring). Its pitch climbs per kill (KILL_LADDER).
	-- 2026-11-15 (owner's pick, "K5"): two rising glass notes on a thump;
	-- the headshot kill adds the headshot's ding. Were kill_C / kill_head_C.
	-- 2026-11-15, later (owner after playing K5: "I still don't like" it; his
	-- pick from batch 4: "I like K13"): a soft bubble pop, slowed a little and
	-- low-passed at 3 kHz, on a muffled thud, 3 dB under the old kill level
	-- (a softer take of kill_C's pop). tools/audio/hit_candidates.py
	-- final-kill. The headshot kill plays the same sound until a headshot is
	-- picked (he passed on every headshot of batches 3 and 4). Were kill_E /
	-- kill_head_E.
	Kill = "gun:kill_F",
	KillHead = "gun:kill_F",
	Damage = "gun:damage", -- a muffled body thud (pro pack)

	-- Bullet impacts on surfaces (by Util/ImpactFx's Surface kinds), built from
	-- the pack's slap, sheet-metal, wood-block and wet-punch hits. Played by
	-- the impact effect (hit-feedback lane's hook, 3D at the hit point).
	IMPACTS = table.freeze({
		Hard = "gun:impact_hard",
		Metal = "gun:impact_metal",
		Glass = "gun:impact_metal",
		Wood = "gun:impact_wood",
		Soft = "gun:impact_soft",
	} :: { [string]: string }),

	-- Optional per-surface footsteps when the engine character sounds are off.
	-- These are the project's previously licensed CC0 recordings.
	STEPS = table.freeze({
		Concrete = "gun:step_concrete",
		Metal = "gun:step_metal",
		Wood = "gun:step_wood",
		Grass = "gun:step_grass",
		Snow = "gun:step_gravel",
	} :: { [string]: string }),
	SlideStart = "sfx:SlideStart", -- (the slide plays Config/Juice's sound)
	UiClick = "sfx:UiClick",
})
