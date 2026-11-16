--!strict
-- The damage direction indicator (Util/DamageIndicator; vault/05 Production/
-- Playtests/2026-11-15 Gunplay Overhaul.md §12). Owner, 2026-11-15, with a
-- RIVALS screenshot: a thick red arc round the crosshair with an arrowhead on
-- its outside pointing at whoever hit you; "it rotates as you move on the
-- screen to show where you actually got hit, and it also will grow / shrink as
-- you get further from where you got hit or closer". Ours was a thin 80 px
-- line that was aimed once, at the moment of the hit.

local DamageIndicator = {}

-- The shape (tools/vfx/make_damage_indicator.py → art-source/vfx/hit/
-- damage_arc.png, decal 121870947037186): white, tinted by `COLOR`.
DamageIndicator.IMAGE = "rbxassetid://105976537709544"

-- The image's numbers, px at 1080p (as in the tool): the band's centre line
-- sits `radius` from the crosshair, so the arc is part of a circle round it.
DamageIndicator.ART = table.freeze({
	radius = 285,
	thick = 20,
	triHeight = 50,
	margin = 6,
	width = 368,
	height = 136,
})

DamageIndicator.COLOR = Color3.fromHex("FF1F2D")
DamageIndicator.TRANSPARENCY = 0.06

-- Screen scale: px are designed at `designHeight` and follow the screen
-- height between these limits.
DamageIndicator.SCREEN = table.freeze({ designHeight = 1080, min = 0.55, max = 1.4 })

-- One arc per shooter: a hit from within `sameSource` studs of an arc's
-- source renews that arc; up to `pool` arcs at once (the oldest is reused).
DamageIndicator.POOL = 4
DamageIndicator.SAME_SOURCE = 10

-- A hit: the arc starts at `from` times its size and shrinks to it over
-- `pop` seconds (fading in over `fadeIn`), holds, then fades over `fade`.
-- A renewed arc (hit again by the same shooter) pulses from `again`.
-- 2026-11-15 (RIVALS pass): RIVALS keeps the wedge 5 s, following the shooter,
-- so you can turn and find them; ours held 0.85 s. 2.5 s here (4v4 clutter).
DamageIndicator.TIME = table.freeze({ pop = 0.14, fadeIn = 0.05, hold = 2.5, fade = 0.4 })
DamageIndicator.POP = table.freeze({ from = 1.3, again = 1.12 })

-- Distance to the shooter sets the size, live: `nearScale` at `near` studs
-- or closer, `farScale` at `far` or more, eased at `rate` (1/s) as you move.
DamageIndicator.DISTANCE = table.freeze({
	near = 12,
	far = 110,
	nearScale = 1.2,
	farScale = 0.7,
	rate = 9,
})

return table.freeze(DamageIndicator)
