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

-- `still`: the camera stops on this key (a beat of anticipation, a settle)
export type Key = {
	t: number,
	eye: Vector3,
	at: Vector3,
	fov: number,
	roll: number?,
	still: boolean?,
}
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
	-- where it stands for the final shot (moved on the cut into it, so the
	-- group closes up for the pose); nil = stays put
	final: { pos: Vector3, yaw: number }?,
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
	{ t = 6.2, fov = -4, shake = 0.45, decay = 0.45 }, -- the slam lands
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

-- The final shot's camera (solo and groups): `wide` opens it for a group
-- (how far the outermost winner stands to the side in the final spots),
-- `back` = how far back their back row stands, `cx` the group's middle.
local function FINAL_KEYS(wide: number, back: number, cx: number): { Key }
	local z = 4.4 + 0.5 * wide -- the held distance
	local low = 0.4 + 0.12 * wide -- the camera height (a group: up a touch, so the kneelers don't stack)
	local lens = 70 - 0.4 * wide
	local aim = v(-0.1 + 0.15 * cx, 4.05 - 0.05 * wide, -0.25 * back)
	return {
		-- the cut: high over the coil
		{
			t = 5.8,
			eye = v(0.9, 7.2 + 0.3 * wide, 6.4 + 0.5 * wide),
			at = v(0.1 * cx, 2.6, -0.3 * back),
			fov = 46 + wide,
		},
		-- the anticipation: eases up and back, and stops
		{
			t = 6.08,
			eye = v(0.8, 7.7 + 0.3 * wide, 7.0 + 0.5 * wide),
			at = v(0.1 * cx, 2.8, -0.3 * back),
			fov = 46 + wide,
			still = true,
		},
		-- 6.14: the slam down to the floor, a hair past its mark
		{
			t = 6.26,
			eye = v(0.45, low - 0.12, z - 0.45),
			at = aim + v(0, -0.15, 0),
			fov = lens + 2,
			roll = 2.5,
		},
		-- settles
		{ t = 6.62, eye = v(0.55, low, z), at = aim, fov = lens, roll = 1.5, still = true },
		-- creeps in through the ring-out
		{
			t = 8.15,
			eye = v(0.5, low - 0.03, z - 0.2),
			at = aim + v(0, 0.05, 0),
			fov = lens,
			roll = 1.2,
		},
	}
end

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
			-- shot, studied not copied). Round 4 (owner: the transition into
			-- the pose more professional, the pose closer to the camera): the
			-- cut finds them coiled from high above; the camera eases up a
			-- touch (the anticipation), then on the 6.14 hit slams down to the
			-- floor right in front of them as they snap into the pose, passes
			-- its mark, settles, and creeps in through the ring-out, very low
			-- and close, a little to their right so the raised gun spreads out
			-- beside the face. HOLD_FLOAT sways it on the pose.
			{
				name = "E low hero",
				from = 5.8,
				to = 8.15,
				keys = FINAL_KEYS(0, 0, 0),
			},
		},
		kicks = KICKS,
		cues = CUES,
		flashes = FLASHES,
	},
}

-- 2 to 5 winners (owner 2026-11-20: everybody does something, in order of
-- performance, the best in front). Slot 1 (the best) plays the solo clip;
-- slots 2-5 each have their own (tools/anim/win_group.py).
-- While they move they stand spread out (the owner: the best one is the
-- main subject, the others off to the sides). On the cut into the final
-- shot they close up into a pose for the camera (round 4, after RIVALS'
-- end shot, studied not copied): the best in front, #2 and #3 down on one
-- knee at their sides, #4 and #5 standing behind on the outside, everyone
-- turned to face the camera.
local RANKS = {
	{ pos = v(0, 0, 0), yaw = 0, clip = "Win1_1", final = v(0, 0, 0) },
	{ pos = v(4.2, 0, -2.6), yaw = 12, clip = "WinS2", final = v(2.7, 0, -1.1) },
	{ pos = v(-4.2, 0, -2.6), yaw = -12, clip = "WinS3", final = v(-2.7, 0, -1.1) },
	{ pos = v(9.0, 0, -4.0), yaw = 22, clip = "WinS4", final = v(5.8, 0, -2.3) },
	{ pos = v(-9.0, 0, -4.0), yaw = -22, clip = "WinS5", final = v(-5.8, 0, -2.3) },
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

-- The group's shots: A-D are the solo shots on the best player, pulled round
-- toward the front, a touch higher and in (the others at the edges; the wide
-- orbit had put #3 as big as the lead); the final shot is the solo's, opened
-- for the group's final spots.
local FRONT_PULL = 0.45 -- the side cameras' sideways offset, scaled
local FRONT_LIFT = 0.8 -- and lifted (studs)
local FRONT_NEAR = 0.85 -- and brought in toward the lead

local function group(n: number): Scene
	local slots: { Slot } = {}
	local cx, w, d = 0, 0, 0
	for i = 1, n do
		local r = RANKS[i]
		local f = r.final
		-- turned to face the final camera (about 5 in front, on the middle)
		local face = math.deg(math.atan2(f.X, 5.6 - f.Z))
		table.insert(slots, {
			pos = r.pos,
			yaw = r.yaw,
			clip = r.clip,
			hold = r.clip .. "Hold",
			root = HOPS[i],
			final = if i > 1 then { pos = f, yaw = face } else nil,
		})
		cx += f.X / n
		w = math.max(w, math.abs(f.X))
		d = math.max(d, -f.Z)
	end
	local shots: { Shot } = {}
	for i = 1, 4 do
		local solo = SCENES[1].shots[i]
		local keys: { Key } = {}
		for _, key in solo.keys do
			local e = key.eye
			local front = e.Z > 0
			local eye = if front then v(e.X * FRONT_PULL, e.Y + FRONT_LIFT, e.Z) else e
			if front then
				eye = key.at + (eye - key.at) * FRONT_NEAR
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
	table.insert(shots, { name = "E low hero", from = 5.8, to = 8.15, keys = FINAL_KEYS(w, d, cx) })
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
	-- On the final pose every winner looks down into the camera (owner
	-- 2026-11-20: "that's going to sell it"): the head turns to the lens on
	-- top of the clip, eased in from `from` to `full` (song time), at most
	-- `max` degrees from where the clip has it (so a head never spins), the
	-- neck taking it all but `chest` of it (the chest turns a little too).
	LOOK = table.freeze({ from = 6.3, full = 6.75, max = 70, chest = 0.25 }),
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
