--!strict
-- The default crosshair (vault/05 Production/Playtests/2026-11-13 Hit Feedback
-- Pass.md §10). Owner, 2026-11-13: "the default crosshair could be a bit
-- improved" (customisation comes later). The fields mirror the options
-- RIVALS' crosshair settings expose (scale, rotation, static, show while
-- aiming, bars with spacing / length / thickness / per-side toggles, dot,
-- outline), so a later settings screen can write a per-player copy of this
-- table. Sizes are px at 1080p, scaled with the screen height (`minScale` /
-- `maxScale`) and rounded to whole pixels so the lines stay crisp.

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- State reactions (2026-11-15, RIVALS pass: vault/05 Production/Playtests/
-- 2026-11-15 Gunplay Feel RIVALS.md; RIVALS numbers in vault/03 Research/
-- Rivals Reference/Body, Viewmodel, Guns and VFX.md -> Hit feedback and
-- crosshair). Like RIVALS, each reaction rides a spring that SNAPS to a bigger
-- target at once and only eases back down (`snapUp`), so the crosshair reacts
-- on the frame it happens and settles softly. Set a number to 0 to turn that
-- reaction off (the settings screen will write these).
export type Motion = {
	speed: number, -- spring angular speed, 1/s (RIVALS 20)
	damping: number, -- damping ratio (RIVALS 0.875: a hair of overshoot on the way down)
	snapUp: boolean, -- jump straight to a bigger target (false: spring both ways)
	slideTilt: number, -- degrees the whole crosshair (and hit marker) turns while sliding
	airGap: number, -- px the gap opens while airborne
	dashGap: number, -- px kick on a Dash
	shotGap: number, -- px kick per shot at recoil.up = 1 (scaled by the gun's kick)
	shotGapMin: number, -- px: the smallest per-shot kick (low-recoil automatics still bloom)
	shotGapMax: number, -- px: the biggest single kick
	bloomMax: number, -- px: shots stack up to this
	adsCollapse: boolean, -- aiming pulls the bars into the dot as it fades (RIVALS)
}

export type Crosshair = {
	scale: number, -- the player's size multiplier
	minScale: number, -- screen scale floor (phones)
	maxScale: number,
	designHeight: number, -- px the sizes are designed at
	rotation: number, -- degrees (0 = a plus; 45 = an x)
	static: boolean, -- true: the gap ignores spread
	showWhileAiming: boolean,
	color: Color3,
	transparency: number,
	bars: {
		enabled: boolean,
		length: number,
		thickness: number,
		spacing: number, -- px from the centre to the bars' inner ends at zero spread
		top: boolean,
		bottom: boolean,
		left: boolean,
		right: boolean,
	},
	dot: {
		enabled: boolean,
		size: number,
	},
	outline: {
		enabled: boolean,
		thickness: number,
		color: Color3,
		transparency: number,
	},
	-- Spread (degrees of the real cone) opens the gap: the bars' inner ends sit
	-- on the cone's edge (+ spacing), eased toward it at `followRate` (1/s),
	-- never wider than `maxGap` px.
	followRate: number,
	maxGap: number,
	fadeRate: number, -- 1/s, showing / hiding (aim)
	-- Sprinting (owner, 2026-11-15: "it should still be there but be dynamic"):
	-- the crosshair stays and its gap opens by this many px more, on top of
	-- the spread the run already adds.
	sprintGap: number,
	motion: Motion,
}

local DEFAULT: Crosshair = {
	scale = 1,
	minScale = 0.9, -- phones: a 2 px line stays 2 px
	maxScale = 1.5,
	designHeight = 1080,
	rotation = 0,
	static = false,
	showWhileAiming = false,
	color = hex("FFFFFF"),
	transparency = 0,
	bars = {
		enabled = true,
		length = 6,
		thickness = 2,
		spacing = 4,
		top = true,
		bottom = true,
		left = true,
		right = true,
	},
	dot = {
		enabled = true,
		size = 2,
	},
	-- The same near-black as the hit markers' outline (Config/HitFx), so the
	-- crosshair and the X read as one system; strong enough to hold on the
	-- bright range and on white-flashed bodies.
	outline = {
		enabled = true,
		thickness = 1,
		color = hex("06080C"),
		transparency = 0.3,
	},
	followRate = 22,
	maxGap = 70,
	fadeRate = 20,
	sprintGap = 8,
	motion = {
		speed = 20,
		damping = 0.875,
		snapUp = true,
		slideTilt = 20, -- owner, 2026-11-15: "20 degree tilt, like RIVALS"
		airGap = 10,
		dashGap = 14,
		shotGap = 3,
		shotGapMin = 2,
		shotGapMax = 7,
		bloomMax = 16,
		adsCollapse = true,
	},
}

return table.freeze({
	DEFAULT = DEFAULT,
})
