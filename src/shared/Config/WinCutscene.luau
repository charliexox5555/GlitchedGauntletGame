--!strict
-- The end-of-match winner cutscene (vault/02 Art/Win Cutscene.md), played by
-- Util/WinCutscene for MatchEndController. Same cutscene every time, cut to
-- the ending song (Config/UiSounds MatchEnd: APM "Victory Slam stinger 1",
-- 8.15 s). Every time below is SONG time: the cutscene starts the song and
-- reads its clock from it.
--
-- One scene per winning-team size (SCENES[1] .. SCENES[5]; 2-5 are built by
-- group() from the same shots); a bigger team uses SCENES[5], its extra
-- winners standing at EXTRA_SLOTS. Winners come in order of performance
-- (MatchEndController), slot 1 = the best. Each scene: the winners' slots and clips, then the shots.
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
-- A designed sound accent under the song (owner 2026-11-20: an impact or
-- whoosh-hit when a strong angle slams in). It starts early so the loudest
-- point of the file (`hit` seconds in, measured) lands on song time `t`.
-- Licensed only (Pro Sound Effects / Roblox / APM); `vol` level-matched to
-- the song by measured PlaybackLoudness. Options per accent: the F4 board's
-- CUTSCENE tab (Shared/SoundAudition).
export type Cue = { name: string, t: number, id: number, vol: number, hit: number }
export type Scene = {
	length: number, -- the camera holds the last key after this
	slots: { Slot },
	shots: { Shot },
	kicks: { Kick },
	flashes: { Flash },
	cues: { Cue },
}

-- Shared by every scene: camera kicks on the accents, the sound accents
-- under the song, the white flashes on the cuts.
local KICKS: { Kick } = {
	{ t = 0.14, shake = 0.35, decay = 0.35 },
	{ t = 1.48, fov = -3, shake = 0.3, decay = 0.3 },
	{ t = 1.82, shake = 0.25, decay = 0.2 },
	{ t = 2.02, fov = -4, shake = 0.3, decay = 0.4 },
	{ t = 4.02, shake = 0.2, decay = 0.25 },
	{ t = 4.16, fov = -2, decay = 0.3 },
	{ t = 5.36, fov = -2, decay = 0.35 },
	{ t = 6.14, fov = -3, shake = 0.35, decay = 0.45 },
	{ t = 6.8, fov = -1.5, shake = 0.15, decay = 0.4 },
}

-- (first options on the F4 board; the owner picks by ear)
local CUES: { Cue } = {
	{ name = "OPEN", t = 0.12, id = 9120729792, vol = 0.261, hit = 0.5 }, -- PSE Whoosh Impact 3 (big stinger, up and hit)
	{ name = "CUT B", t = 1.48, id = 9120729925, vol = 0.238, hit = 0.56 }, -- PSE Whoosh Impact 5
	{ name = "CUT D", t = 4.02, id = 9120716440, vol = 0.234, hit = 0.3 }, -- PSE Whoosh Fast Swish By 4
	{ name = "SPIN", t = 5.44, id = 9126013644, vol = 0.262, hit = 0.14 }, -- PSE Swish Med High End Sharp 13
	{ name = "FINAL", t = 6.14, id = 9125484367, vol = 0.24, hit = 0.11 }, -- PSE Deep Hit, Big Reverberant Boom
}

local FLASHES: { Flash } = {
	{ t = 0.1, peak = 0.55, decay = 0.35 }, -- the slam: in from the replay
	{ t = 1.46, peak = 0.18, decay = 0.2 },
	{ t = 6.12, peak = 0.22, decay = 0.3 },
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
			-- E: the final pose, after the owner's reference (a RIVALS winner
			-- shot, studied not copied): starts at eye level on the coil, then
			-- drops fast to the floor right in front of them as they snap the
			-- gun up on 6.14 (the camera falls while they rise; the lens opens
			-- wide on the way), and holds very low and close, looking up past
			-- the raised gun, a little to their right so the raised gun spreads
			-- out beside the face (from their left it hid behind the head). HOLD_FLOAT sways it on the pose.
			{
				name = "E low hero",
				from = 5.8,
				to = 8.15,
				keys = {
					{ t = 5.8, eye = v(1.0, 3.6, 7.6), at = v(0, 3.3, 0), fov = 46, roll = 0 },
					{
						t = 6.3,
						eye = v(0.6, 0.55, 5.4),
						at = v(-0.1, 4.0, 0),
						fov = 64,
						roll = 2,
					},
					{
						t = 8.15,
						eye = v(0.55, 0.4, 4.9),
						at = v(-0.1, 4.15, 0),
						fov = 66,
						roll = 1.5,
					},
				},
			},
		},
		kicks = KICKS,
		cues = CUES,
		flashes = FLASHES,
	},
}

-- 2 to 5 winners (owner 2026-11-20: everybody does something, in order of
-- performance, the best in front; the same kind of shots, with the others
-- in view). Slot 1 (the best) plays the solo clip; slots 2-5 each have
-- their own (tools/anim/win_group.py) and their own hop or spin.
-- The spots by rank: 1 front and centre, then right, left, far right, far
-- left, each a step further back and turned a little toward the middle;
-- tight together (owner's 2-player reference: the pair shoulder to
-- shoulder, #2 a step back and down on one knee).
local RANKS = {
	{ pos = v(0, 0, 0), yaw = 0, clip = "Win1_1" },
	{ pos = v(4.2, 0, -2.6), yaw = 12, clip = "WinS2" },
	{ pos = v(-4.2, 0, -2.6), yaw = -12, clip = "WinS3" },
	{ pos = v(9.0, 0, -4.0), yaw = 22, clip = "WinS4" },
	{ pos = v(-9.0, 0, -4.0), yaw = -22, clip = "WinS5" },
}
-- Hops and spins by rank (only some: the others do grounded moves on 5.36)
local HOPS: { [number]: { RootKey } } = {
	[1] = SCENES[1].slots[1].root :: { RootKey }, -- the lead's spin-hop
	[2] = {
		{ t = 5.32, yaw = 0, lift = 0 },
		{ t = 5.45, yaw = 0, lift = 0.85 },
		{ t = 5.57, yaw = 0, lift = 0 },
	}, -- a hop
	[4] = {
		{ t = 5.3, yaw = 0, lift = 0 },
		{ t = 5.46, yaw = 0, lift = 1.05 },
		{ t = 5.6, yaw = 0, lift = 0 },
	}, -- a big hop
}

-- The group's shots: A-D are the solo shots on the best player (the others
-- at the edges), the final shot takes everyone in: `w` = how far the
-- outermost winner stands to the side, `d` how far back the back row is,
-- `cx` the group's middle. The final shot is the solo's low angle centred between
-- the lead and the group (owner's 2-player reference), the lens a little
-- wider and further back, so the others stand in it.
local FRONT_PULL = 0.45 -- the side cameras' sideways offset, scaled
local FRONT_LIFT = 0.8 -- and lifted (studs)
local FRONT_NEAR = 0.85 -- and brought in toward the lead

local function group(n: number): Scene
	local slots: { Slot } = {}
	local cx, w, d = 0, 0, 0
	for i = 1, n do
		local r = RANKS[i]
		table.insert(
			slots,
			{ pos = r.pos, yaw = r.yaw, clip = r.clip, hold = r.clip .. "Hold", root = HOPS[i] }
		)
		cx += r.pos.X / n
		w = math.max(w, math.abs(r.pos.X))
		d = math.max(d, -r.pos.Z)
	end
	-- (owner 2026-11-20: while they move, the camera stays on the best
	-- player and the others are only seen round the edges; everyone is in
	-- full view in the final shot. So A-D are the solo shots.)
	local shots: { Shot } = {}
	for i = 1, 4 do
		-- the solo shot with its camera pulled round toward the front and a
		-- touch higher, so the side cameras don't pass right by a flanker
		-- (2026-11-20: the wide orbit put #3 as big as the lead)
		local solo = SCENES[1].shots[i]
		local keys: { Key } = {}
		for _, key in solo.keys do
			local e = key.eye
			local front = e.Z > 0
			local eye = if front then v(e.X * FRONT_PULL, e.Y + FRONT_LIFT, e.Z) else e
			if front then
				eye = key.at + (eye - key.at) * FRONT_NEAR -- in a little on the lead
			end
			table.insert(
				keys,
				{ t = key.t, eye = eye, at = key.at, fov = key.fov, roll = key.roll }
			)
		end
		table.insert(shots, {
			name = solo.name,
			from = solo.from,
			to = solo.to,
			keys = keys,
			startStill = solo.startStill,
			finishStill = solo.finishStill,
		})
	end
	local final: Shot = {
		name = "E low hero",
		from = 5.8,
		to = 8.15,
		keys = {
			{
				t = 5.8,
				eye = v(1.0, 3.6, 7.6 + 0.4 * w),
				at = v(0.2 * cx, 3.3, -0.2 * d),
				fov = 46 + w,
				roll = 0,
			},
			{
				t = 6.3,
				eye = v(0.3, 0.55 + 0.06 * w, 5.4 + 0.25 * w),
				at = v(-0.1, 3.8 - 0.05 * w, -0.3 * d),
				fov = 64 + 0.9 * w,
				roll = 2,
			},
			{
				t = 8.15,
				eye = v(0.25, 0.4 + 0.06 * w, 4.9 + 0.25 * w),
				at = v(-0.1, 3.95 - 0.05 * w, -0.3 * d),
				fov = 66 + 0.9 * w,
				roll = 1.5,
			},
		},
	}
	table.insert(shots, final)
	return {
		length = 8.15,
		slots = slots,
		shots = shots,
		kicks = KICKS,
		cues = CUES,
		flashes = FLASHES,
	}
end

for n = 2, 5 do
	SCENES[n] = group(n)
end

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
	-- When the results screen and the name plates come in (song time): no UI
	-- during the cutscene (owner 2026-11-20); it all comes in together once
	-- the winner has landed the final pose (the clip ends at 7.3), as the
	-- song rings out.
	SCREEN_AT = 7.35,
	-- Any click or key after SKIP_AFTER jumps to SKIP_TO (the final pose)
	-- and brings the screen in.
	SKIP_AFTER = 0.8,
	SKIP_TO = 6.6,
	-- The clip → its hold loop crossfade, and the fade into the first clip.
	HOLD_FADE = 0.3,
	-- The held final shot also floats a little (studs, camera space; periods
	-- in seconds) once the last key is reached: the "slight sway" on the pose.
	HOLD_FLOAT = table.freeze({ x = 0.06, xPeriod = 5.1, y = 0.05, yPeriod = 3.9, fadeIn = 1.2 }),
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
