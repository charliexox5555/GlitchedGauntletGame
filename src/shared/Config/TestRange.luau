--!strict
-- Test range for testers (vault/04 Tech/Architecture.md → Test range). Runs
-- only while test mode is on (shared/TestMode). Positions are in range space:
-- X to the right, Y up from the floor, -Z downrange from the firing line.

-- Label colours over the dummies (plain, readable on the grey range).
local WHITE = Color3.fromHex("F2F2F2")
local YELLOW = Color3.fromHex("F2C94C")
local ORANGE = Color3.fromHex("F2994A")
local RED = Color3.fromHex("EB5757")
local GREEN = Color3.fromHex("6FCF97")

export type DummyKind = "Idle" | "Strafe" | "StrafeJump" | "Crouch" | "LongRange" | "Shooter"

export type DummySpot = {
	kind: DummyKind,
	x: number,
	distance: number, -- studs downrange from the firing line
	y: number?, -- standing height (platforms)
	weapon: string, -- the gun it holds (third-person hold check)
	label: string?, -- overrides the kind's label
}

export type KindInfo = {
	label: string,
	accent: Color3,
	speed: number?, -- studs/s while moving
	sway: number?, -- moves at most this far left/right of its spot
	turnAfter: { number }?, -- min/max seconds before it changes direction
	jumpAfter: { number }?, -- min/max seconds between jumps
	crouch: boolean?,
}

export type Behaviour = { id: string, default: boolean }

return table.freeze({
	-- Where the firing line's centre sits in the world (the range is built
	-- around it, facing -Z). Kept away from the origin so a future arena can
	-- use the middle of the baseplate.
	ORIGIN = Vector3.new(0, 0.2, 500),

	-- Distance markers on the lanes (studs from the firing line). Falloff in
	-- Config/Weapons uses the same units.
	MARKERS = { 10, 25, 50, 100, 150 },
	LANE_WIDTH = 12,
	LANES = 7, -- lane centres at -36, -24, ... 36
	LANE_LENGTH = 170,

	KINDS = table.freeze({
		Idle = table.freeze({ label = "STATIC", accent = WHITE }),
		Strafe = table.freeze({
			label = "STRAFE",
			accent = YELLOW,
			speed = 14,
			sway = 5,
			turnAfter = { 0.35, 1.1 },
		}),
		StrafeJump = table.freeze({
			label = "STRAFE + JUMP",
			accent = ORANGE,
			speed = 14,
			sway = 5,
			turnAfter = { 0.35, 1.1 },
			jumpAfter = { 0.8, 1.6 },
		}),
		Crouch = table.freeze({
			label = "CROUCH",
			accent = GREEN,
			speed = 9,
			sway = 4,
			turnAfter = { 0.5, 1.4 },
			crouch = true,
		}),
		LongRange = table.freeze({ label = "LONG RANGE", accent = WHITE }),
		Shooter = table.freeze({ label = "SHOOTER", accent = RED }),
	}) :: { [DummyKind]: KindInfo },

	DUMMIES = table.freeze({
		-- Falloff row: one static dummy per marker.
		{ kind = "Idle", x = -36, distance = 10, weapon = "Vandal" },
		{ kind = "Idle", x = -24, distance = 25, weapon = "Vandal" },
		{ kind = "Idle", x = -12, distance = 50, weapon = "Vandal" },
		{ kind = "Idle", x = 0, distance = 100, weapon = "Vandal" },
		-- Moving targets.
		{ kind = "Strafe", x = 12, distance = 25, weapon = "Vandal" },
		{ kind = "StrafeJump", x = 24, distance = 35, weapon = "Vandal" },
		{ kind = "Crouch", x = 36, distance = 20, weapon = "Vandal" },
		-- Sniper target on the back platform.
		{ kind = "LongRange", x = 24, distance = 150, y = 6, weapon = "Vandal" },
		-- Fires harmless tracers at the firing line (see SHOOTER).
		{ kind = "Shooter", x = -54, distance = 40, y = 4, weapon = "Vandal" },
		-- Cover section: penetration and peeking.
		{ kind = "Idle", x = -78, distance = 30, weapon = "Vandal", label = "BEHIND THINWALL" },
		{ kind = "Idle", x = -94, distance = 30, weapon = "Vandal", label = "BEHIND WALL" },
		{ kind = "Idle", x = -62, distance = 30, weapon = "Vandal", label = "LOW COVER" },
	}) :: { DummySpot },

	RESPAWN = 2.5, -- seconds after a dummy dies
	REGEN_DELAY = 2, -- "Dummies heal": full health this long after the last hit

	-- Shooter dummy: bursts at the nearest player it can see, always missing
	-- by MISS_OFFSET studs (no damage is ever applied).
	SHOOTER = table.freeze({
		range = 140,
		burst = 3,
		shotGap = 0.11,
		burstGap = { 1.1, 1.8 },
		missOffset = { 1.6, 3.2 },
		turnResponsiveness = 18,
	}),

	-- Range switches (fixed for now; the tester menu that flipped them is gone
	-- until the new UI pass).
	BEHAVIOURS = table.freeze({
		{ id = "Move", default = true }, -- strafe, jump and crouch dummies keep moving
		{ id = "Shoot", default = true }, -- the shooter fires harmless tracers
		{ id = "Regen", default = true }, -- full health REGEN_DELAY after the last hit
	}) :: { Behaviour },

	-- Roblox's stock R15 clips, for dummies moving without the Animate script.
	ANIMATIONS = table.freeze({
		Run = "rbxassetid://913376220",
		Jump = "rbxassetid://507765000",
		Fall = "rbxassetid://507767968",
	}),
})
