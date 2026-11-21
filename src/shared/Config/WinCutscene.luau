--!strict
-- The end-of-match winner cutscene (vault/02 Art/Win Cutscene.md), played by
-- Util/WinCutscene for MatchEndController. Same cutscene every time, cut to
-- the ending song (Config/UiSounds MatchEnd: APM "Victory Slam stinger 1",
-- 8.15 s). Every time below is SONG time: the cutscene starts the song and
-- reads its clock from it.
--
-- One scene per winning-team size (SCENES[1] .. SCENES[5]); a size with no
-- scene of its own uses the largest one below it, its extra winners standing
-- at EXTRA_SLOTS. Each scene: the winners' slots and clips, then the shots.
--
-- Stage space: the origin is the stage anchor on the floor; a point is
-- { right, up, forward } in studs, forward = where the winners face (the
-- front camera side). The anchor is a part tagged STAGE_TAG inside the map
-- (workspace.ActiveMap; its LookVector = where the winners face); a map
-- without one uses FALLBACK on the place's Baseplate.
--
-- A shot: { from, to, keys = { { t, eye, at, fov, roll? } }, still = { start?, finish? } }.
-- The camera runs through the keys on a time-parameterised Catmull-Rom curve
-- (eye, look-at point, FOV, roll), driven per frame from the song clock: a
-- cut is a new shot, a move is the curve. `still.start` = the first key
-- starts from rest (default: moving, as a cut in on motion reads); `finish`
-- = the last key comes to rest (default true).

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

export type Key = { t: number, eye: Vector3, at: Vector3, fov: number, roll: number? }
export type Shot = {
	name: string,
	from: number,
	to: number,
	keys: { Key },
	startStill: boolean?,
	finishStill: boolean?,
}
-- A hit on an accent: the FOV pushed `fov` degrees and/or a shake of
-- `shake` degrees, in over `attack` s, out over `decay` s.
export type Kick = { t: number, fov: number?, shake: number?, decay: number }
export type Flash = { t: number, peak: number, decay: number }
-- A key of a slot's root move (song time): the whole copy turned `yaw`
-- degrees (+ = to its left) and lifted `lift` studs (a spin, a hop), on a
-- curve that starts and ends at rest.
export type RootKey = { t: number, yaw: number, lift: number }
export type Slot = {
	pos: Vector3, -- stage space, on the floor
	yaw: number, -- degrees, + = turned to its left
	clip: string, -- Config/Animations WIN key (the one-shot, ends on the pose)
	hold: string, -- the loop that holds the pose
	root: { RootKey }?, -- whole-body moves the clip can't do (it's keyed about a fixed root)
}
export type Scene = {
	length: number, -- the camera holds the last key after this
	slots: { Slot },
	shots: { Shot },
	kicks: { Kick },
	flashes: { Flash },
}

local SCENES: { [number]: Scene } = {
	-- 1 winner. Shots on the song's accents (measured 2026-11-20): 0.14 slam,
	-- 0.68, 1.48 (the band comes in), 1.82, 2.02 (loudest), 3.14, 4.02 +
	-- 4.16, 4.80, 5.36, 5.80, 6.14, 6.80 (last hit), ring-out to 8.05.
	[1] = {
		length = 8.15,
		slots = {
			{
				pos = v(0, 0, 0),
				yaw = 0,
				clip = "Win1_1",
				hold = "Win1_1Hold",
				-- the spin-hop on 5.36: off the floor at 5.34, a full turn, down at 5.57
				root = {
					{ t = 5.32, yaw = 0, lift = 0 },
					{ t = 5.45, yaw = 190, lift = 0.75 },
					{ t = 5.56, yaw = 360, lift = 0 },
				},
			},
		},
		shots = {
			-- A: behind the right shoulder, craning down and in while they
			-- catch their breath; the head comes up on 0.68.
			{
				name = "A over the shoulder",
				from = 0,
				to = 1.48,
				keys = {
					{ t = 0, eye = v(4.4, 7.6, -9.8), at = v(0.4, 3.0, 4), fov = 50, roll = -2 },
					{ t = 1.48, eye = v(3.0, 5.4, -6.2), at = v(-0.7, 3.7, 6), fov = 46, roll = 0 },
				},
				finishStill = false,
			},
			-- B: cut to the front three-quarter (their left: the raised gun arm
			-- stays behind the head) on the snap (1.48); the camera whips round
			-- and brakes by the point on 2.02, then drifts.
			{
				name = "B front three-quarter",
				from = 1.48,
				to = 3.14,
				keys = {
					{
						t = 1.48,
						eye = v(-7.6, 2.9, 6.2),
						at = v(-0.3, 3.4, 0),
						fov = 46,
						roll = -2,
					},
					{ t = 1.9, eye = v(-4.6, 4.1, 8.1), at = v(0, 3.6, 0), fov = 43, roll = -0.5 },
					{ t = 3.14, eye = v(-3.3, 4.3, 8.5), at = v(0.1, 3.7, 0), fov = 41, roll = 0 },
				},
				finishStill = false,
			},
			-- C: close on the face from the front left (the "too easy" look
			-- turns into it), a slow truck.
			{
				name = "C close up",
				from = 3.14,
				to = 4.02,
				keys = {
					{
						t = 3.14,
						eye = v(-2.9, 5.0, 5.0),
						at = v(-0.1, 4.2, 0),
						fov = 38,
						roll = -1,
					},
					{
						t = 4.02,
						eye = v(-2.2, 4.8, 5.6),
						at = v(0, 4.15, 0),
						fov = 37,
						roll = -0.5,
					},
				},
				finishStill = false,
			},
			-- D: wide, orbiting from their left round the front to the right
			-- while the gun comes down, sweeps and twirls.
			{
				name = "D wide orbit",
				from = 4.02,
				to = 5.8,
				keys = {
					{ t = 4.02, eye = v(-8.2, 2.6, 4.8), at = v(0, 3.0, 0), fov = 48, roll = 0 },
					{ t = 4.9, eye = v(-3.7, 3.2, 8.3), at = v(0, 3.2, 0), fov = 47, roll = 1 },
					{ t = 5.8, eye = v(2.4, 3.8, 8.5), at = v(0, 3.4, 0), fov = 46, roll = 0 },
				},
				finishStill = false,
			},
			-- E: the final pose. Starts at eye level on the coil, cranes down
			-- fast as they snap up on 6.14 (the camera falls while they rise),
			-- then settles low, looking up, and holds through the ring-out.
			{
				name = "E low hero",
				from = 5.8,
				to = 8.15,
				keys = {
					{ t = 5.8, eye = v(1.0, 3.6, 7.6), at = v(0, 3.3, 0), fov = 46, roll = 0 },
					{
						t = 6.3,
						eye = v(1.5, 0.9, 9.0),
						at = v(-0.3, 3.4, 0),
						fov = 51,
						roll = -1.5,
					},
					{ t = 8.15, eye = v(1.7, 0.7, 9.6), at = v(-0.3, 3.3, 0), fov = 50, roll = -1 },
				},
			},
		},
		kicks = {
			{ t = 0.14, shake = 0.35, decay = 0.35 },
			{ t = 1.48, fov = -3, shake = 0.3, decay = 0.3 },
			{ t = 1.82, shake = 0.25, decay = 0.2 },
			{ t = 2.02, fov = -4, shake = 0.3, decay = 0.4 },
			{ t = 4.02, shake = 0.2, decay = 0.25 },
			{ t = 4.16, fov = -2, decay = 0.3 },
			{ t = 5.36, fov = -2, decay = 0.35 },
			{ t = 6.14, fov = -3, shake = 0.35, decay = 0.45 },
			{ t = 6.8, fov = -1.5, shake = 0.15, decay = 0.4 },
		},
		flashes = {
			{ t = 0.1, peak = 0.55, decay = 0.35 }, -- the slam: in from the replay
			{ t = 1.46, peak = 0.18, decay = 0.2 },
			{ t = 6.12, peak = 0.22, decay = 0.3 },
		},
	},
}

return table.freeze({
	SONG = "MatchEnd", -- Config/UiSounds cue; the cutscene's clock
	STAGE_TAG = "WinnerStage", -- a part in the map: position on the floor, LookVector = the winners' facing
	-- No tagged part: this spot on workspace.Baseplate (its top), facing -Z
	-- turned `yaw` degrees. Clear of every map's footprint (the maps sit
	-- ~200 studs up at their own x/z) and of the TestRange.
	FALLBACK = table.freeze({ part = "Baseplate", at = Vector3.new(600, 0, 600), yaw = 0 }),
	-- The winners stand on the floor found under the anchor (a ray down from
	-- this far above it), else on the anchor's own height.
	GROUND_PROBE = 6,
	SCENES = SCENES,
	-- Extra winners past a scene's slots (a size with no scene of its own
	-- yet): a V behind the lead, all on the scene's first slot's clips.
	EXTRA_SLOTS = {
		v(-3.4, 0, -2.4),
		v(3.4, 0, -2.4),
		v(-6.6, 0, -4.6),
		v(6.6, 0, -4.6),
	},
	-- When the results screen and the name plates come in (song time): after
	-- the last hit, as the song rings out over the held pose.
	SCREEN_AT = 6.95,
	-- Any click or key after SKIP_AFTER jumps to SKIP_TO (the final pose)
	-- and brings the screen in.
	SKIP_AFTER = 0.8,
	SKIP_TO = 6.6,
	-- The clip → its hold loop crossfade, and the fade into the first clip.
	HOLD_FADE = 0.3,
	-- Handheld drift on top of every shot (degrees; periods in seconds): slow
	-- enough that the held final shot breathes rather than wobbles.
	HANDHELD = table.freeze({
		pitch = { 0.35, 5.3, 0.15, 2.9 },
		yaw = { 0.45, 6.7, 0.15, 3.7 },
		roll = { 0.25, 7.9, 0.1, 4.3 },
	}),
	SHAKE_RATE = 17, -- Hz of a kick's shake
	KICK_ATTACK = 0.04,
	-- Cinema bars (share of the screen height each), in at the start, out
	-- as the results screen comes in.
	BARS = table.freeze({ size = 0.085, inTime = 0.35, outTime = 0.45 }),
	-- A light grade while it plays (a ColorCorrectionEffect of its own).
	GRADE = table.freeze({ contrast = 0.08, saturation = 0.1, fadeIn = 0.4 }),
	-- If the song hasn't started this long after the cutscene did (still
	-- loading), the cutscene runs on its own clock.
	SONG_WAIT = 0.35,
	-- Song and cutscene clocks further apart than this snap together.
	SYNC_SNAP = 0.06,
})
