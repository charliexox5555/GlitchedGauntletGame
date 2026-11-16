--!strict
-- The aimed view: the sniper scope picture (Util/ScopeOverlay; guns with
-- `scope` in Config/Weapons) and the corner darkening while any gun is aimed
-- (Util/AimVignette). 2026-11-15, owner: "revamp the ADS for snipers, make all
-- ADS feel better". Measured in the owner's clips at 60 fps (vault/05
-- Production/Playtests/2026-11-15 Gunplay Overhaul.md §1):
--   scope   a black overlay with a FEATHERED round window (fully clear out to
--           0.72 of the screen height, half dark at 0.84, black at 0.97), a
--           thin see-through cross and a red dot. It cuts in when the gun
--           reaches the eye: the window opens from where the eyepiece was
--           (half size, down and to the right) and reaches the centre in
--           ~0.2 s. A scoped shot drops straight out of the scope.
--   aimed   every gun darkens the screen's corners 40-50% within ~0.1 s.
-- Ours was a hard-edged black mask that popped on, with no darkening at all.
-- On top of the clip: the window's surround lags the turn of the view a
-- little and springs back (the reticle never leaves the screen centre: the
-- shot goes there), and a scoped shot jolts and blurs the picture for the
-- few frames before it drops out.
-- Sizes are px at 1080p (scaled with the screen height) unless they say "of
-- the screen height". Times are seconds.

local Scope = {}

Scope.COLOR = Color3.new(0, 0, 0)
Scope.DOT = Color3.fromHex("FF3233")

-- The window: black from `outer` (its diameter, of the screen height) out;
-- inside that the black thins out over `feather` (of the screen height, per
-- side) in `steps` rings, to nothing.
Scope.WINDOW = table.freeze({ outer = 0.97, feather = 0.125, steps = 28 })

-- Reticle: a thin see-through cross over the whole window and a red dot.
Scope.RETICLE = table.freeze({
	line = 2, -- px
	lineFade = 0.6, -- the lines' transparency
	dot = 9, -- px
})

-- Coming in: the window starts at `scale` of its size, `from` (of the screen
-- height, right and down of the centre: where the eyepiece was), and opens
-- to the centre over `time` (ease-out), under a blur of `blur`
-- (BlurEffect.Size) that clears over `blurTime`.
Scope.IN = table.freeze({
	scale = 0.5,
	from = Vector2.new(0.19, 0.2),
	time = 0.2,
	blur = 10,
	blurTime = 0.14,
})
-- Dropping out (the gun comes back at once): a shorter blur.
Scope.OUT = table.freeze({ blur = 7, blurTime = 0.1 })

-- The surround lags the view: it moves `lag` of the picture's own motion per
-- frame of turning, limited to `max` px, and springs back at `frequency`
-- (rad/s, critically damped). The clip's scope does not do this; kept small.
Scope.LAG = table.freeze({ lag = 0.3, max = 30, frequency = 16 })

-- A scoped shot: the window jumps `rise` px up and `scale` bigger and rings
-- back (frequency in cycles per second, damping ratio), under a blur.
Scope.SHOT = table.freeze({
	rise = 30,
	scale = 0.06,
	frequency = 5.5,
	damping = 0.5,
	blur = 14,
	blurTime = 0.2,
})

-- Aimed, any gun: the screen's edges darken. Each edge is a black band
-- `depth` of the screen deep, `edge` solid at the very edge (0..1) and clear
-- at its inner side; two bands overlap in a corner, so `edge` 0.27 darkens
-- the corners about 47%. It follows the aim blend (in by ~0.1 s).
Scope.AIM_VIGNETTE = table.freeze({ depth = 0.34, edge = 0.27 })

return table.freeze(Scope)
