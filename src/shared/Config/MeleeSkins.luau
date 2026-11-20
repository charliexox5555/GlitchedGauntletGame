--!strict
-- Knife-slot skins that move differently from the stock knife (Studio skin
-- preview, round two 2026-11-14). The stock knife tracks (Config/Viewmodel
-- Slash1-3, HeavyStab, InspectMelee, the melee draw) still carry the arm;
-- these layer the skin's own motion on top.
--
-- FAN: the Giltfold Fan (vault/02 Art/Skins/Giltfold/concept.md, "Fan poses
-- and animation"). Rib_00..Rib_10 are Motor6Ds in the Knife variant's rig
-- (installed by tools/studio/InstallFlatSkin.luau from the Fan's Blender rig).
-- Rest is the open fan; closed, every rib folds onto the centre rib, so the
-- closed fan is a slim stack pointing forward. Rib i turns about its own Z by
-- (i - CENTER) * STEP_DEG * closed. Curves are the Blender actions Fan_Open
-- and Fan_Close sampled per frame at 24 fps (closed fraction 0 = open,
-- 1 = shut), with their overshoot and settle; Util/FanMotion plays them.
export type Key = { number } -- { seconds, closed }

local function frames(values: { number }, fps: number): { Key }
	local keys: { Key } = table.create(#values)
	for i, v in values do
		keys[i] = { (i - 1) / fps, v }
	end
	return keys
end

return table.freeze({
	-- First-person size of a knife-slot skin relative to the stock knife's
	-- (Viewmodel SCALE), by the variant's SkinItem attribute. The fist stays put;
	-- the model shrinks about its grip. The open Fan filled a third of the view.
	VIEWMODEL_SCALE = table.freeze({
		Fan = 0.8,
		RuinedReaver = 0.84, -- 2026-11-21: its tip reached 72% up the screen (Util/RuinedReaver READY)
	} :: { [string]: number }),
	-- The camera's lead into a swing, per knife-slot motion (2026-11-21, owner:
	-- "not enough lead, punch or follow-through" on the Reaver). Replaces
	-- Config/Animations KNIFE_FEEL leadRoll / leadEarly / leadTime for that
	-- motion (ViewmodelController.meleeMotion). CameraController.rollKick
	-- rises over the first 20% of `leadTime`, so leadEarly = 0.2 * leadTime
	-- puts the full roll on the contact and the rest is the follow-through.
	FEEL = table.freeze({
		RuinedReaver = table.freeze({ leadRoll = 2.4, leadEarly = 0.084, leadTime = 0.42 }),
		Bat = table.freeze({ leadRoll = 2.2, leadEarly = 0.09, leadTime = 0.45 }),
		-- The Fan swings on the stock knife tracks: the knife's lead, timed onto the contact.
		Fan = table.freeze({ leadRoll = 1.6, leadEarly = 0.064, leadTime = 0.32 }),
	} :: { [string]: { leadRoll: number, leadEarly: number, leadTime: number } }),
	FAN = table.freeze({
		RIB_PREFIX = "Rib_",
		CENTER = 5,
		STEP_DEG = 10.4,
		-- Fan_Open (13 frames): shut -> open, a 6% overshoot past open, settle.
		OPEN = frames(
			{ 1, 0.93, 0.76, 0.53, 0.3, 0.11, -0.015, -0.06, -0.04, 0, 0.02, 0.01, 0 },
			24
		),
		-- Fan_Close (9 frames): open -> shut, a 3% overshoot past shut, settle.
		CLOSE = frames({ 0, 0.11, 0.37, 0.65, 0.86, 0.99, 1.03, 1.015, 1 }, 24),
		-- Draw: comes up shut, spreads open once the pull-out is this far through.
		DRAW_OPEN_AT = 0.3,
		-- Heavy: folds shut for the thrust, reopens on the recovery.
		HEAVY_REOPEN_AT = 0.68,
		-- Light: a small fold on the windup, a flick past open at contact.
		SLASH = table.freeze({
			{ 0, 0 },
			{ 0.12, 0.1 },
			{ 0.3, -0.06 },
			{ 0.5, 0.01 },
			{ 0.65, 0 },
		}),
		-- Inspect (fractions of the inspect): shut and reopen to show the leaf,
		-- then two fanning pulses toward the camera, then idle.
		INSPECT = table.freeze({
			{ 0, 0 },
			{ 0.14, 0 },
			{ 0.24, 1.02 },
			{ 0.3, 1 },
			{ 0.4, -0.05 },
			{ 0.46, 0 },
			{ 0.56, 0 },
			{ 0.61, 0.3 },
			{ 0.66, -0.03 },
			{ 0.71, 0.3 },
			{ 0.76, -0.03 },
			{ 0.82, 0 },
		}),
	}),
})
