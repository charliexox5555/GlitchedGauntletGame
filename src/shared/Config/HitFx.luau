--!strict
-- Hit feedback numbers (vault/05 Production/Playtests/2026-11-13 Hit Feedback
-- Pass.md). Owner, 2026-11-13: crosshair markers that feel professional and
-- satisfying; the body you hit flashes white then red ("a fun highlight and
-- slash"), not yellow; a headshot pops a stylised flash from the head and gets
-- its own highlight. Used by Util/HitFeedback (the crosshair markers and the
-- damage numbers) and Util/HitFx (the body flash, the slash, the head flash).
-- Times are seconds, sizes on screen are px at 1080p (scaled with the screen
-- height), sizes in the world are studs.

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local HitFx = {}

-- Shared colours (UI theme v4.1: white text, damage red FF4D5E).
HitFx.COLOR = table.freeze({
	white = hex("FFFFFF"),
	red = hex("FF4D5E"), -- headshot and kill markers, headshot numbers
	deepRed = hex("FF2E3D"), -- the kill flash
	fire = hex("FF7A1F"), -- the headshot flash after its white frame
	blocked = hex("A9BCD6"), -- a guard took the hit: no damage
	outline = hex("06080C"),
})

-- Crosshair markers ------------------------------------------------------------
-- Owner, 2026-11-13 (after playing, with RIVALS screenshots in vault/02 Art/
-- References/hitfx/): "a white part of the crosshair that comes in and hits,
-- and then it's red for a headshot"; the old red/white headshot X was "a bit
-- too much... it should just be red, and more subtle". So: four small wedges
-- (TEXTURES.wedge, dark edge baked in, tinted by `color`) on the diagonals,
-- tips at the centre, that shrink IN from `fromGap` to `gap` (a damped
-- spring, see below), hold, and fade. The same marker for body, head and
-- kill, only the colour changes (the kill marker below is off).
-- Sizes are px at 1080p (scaled like the crosshair).
export type MarkerSpec = {
	color: Color3,
	length: number, -- blade length at rest, px (its width is MARKER_ASPECT of it)
	gap: number, -- px from the centre to the wedge tips at rest
	fromLength: number, -- wedge length at the hit (it starts big)
	fromGap: number, -- tip gap at the hit (it starts wide and shrinks in)
	speed: number, -- 1/s: the shrink is a critically damped spring (~95 % in 4.7 / speed s)
	life: number, -- s: fully gone
	fadePow: number, -- transparency = (t / life) ^ fadePow: solid most of its life, then a quick fade
	ring: boolean, -- a thin ring expands from the centre (kills)
}

-- 2026-11-15 (owner: "improve the hit markers, nicer and like RIVALS"). Measured
-- on his clip at 60 fps: the wedges sit OUTSIDE the crosshair, framing it:
-- they come in from about 40 px out to about 23 px (their centres, from the
-- screen centre) over ~100 ms, fading as they close, and restart on every
-- hit. Ours hugged the centre (tips 5 px out, 8 px long, in from 12 px), so
-- they sat on top of the crosshair's own ticks and read as one small blob.
-- Now: longer wedges, tips 17 px out, in from 2x that; the headshot's a
-- touch bigger and it lingers.
-- 2026-11-15, later (owner: "it should tween inwards: it starts a bit bigger
-- and then gets smaller"). The wedges did slide in, but at their final size
-- and in 100 ms with most of the way covered in the first frame, so it read
-- as a marker that just appears. Now the whole marker (wedges and gaps)
-- starts at `scale` times its size and shrinks onto the crosshair over
-- `punch`, the tips coming in a little further on top (`from`). A hit that
-- lands while the last marker is still shrinking (automatic fire) starts at
-- MARKER_REPOP of that extra size, so a spray pulses instead of jumping.
-- 2026-11-15, RIVALS pass (vault/05 Production/Playtests/2026-11-15 Gunplay
-- Feel RIVALS.md; RIVALS numbers in vault/03 Research/Rivals Reference/Body,
-- Viewmodel, Guns and VFX.md -> Hit feedback and crosshair). RIVALS' marker
-- starts BIG and WIDE (wedges 16 px, 32 px out) and shrinks in tight (8 px,
-- 6 px out) on a critically damped spring of speed 20 (~0.25 s), stays fully
-- visible ~1.4 s and fades by 2 s; the same marker on a kill, red on a crit.
-- Ours had a 0.32 s life and rested 8 px out ("doesn't get small enough").
-- Now the same motion: computed from the time since the hit (no per-frame
-- easing), so it looks the same at 15 fps and at 60. A hit while the last
-- marker is still showing restarts MARKER_REPOP of the travel (1 = from the
-- very start, like RIVALS), so a spray pulses.
HitFx.MARKER_REPOP = 0.85
-- Owner, 2026-11-15 (mid-pass): "the hit marker should look similar or same
-- as RIVALS and look better". RIVALS' marks are slim white kite blades on the
-- diagonals (four 16 px corner images, 8 px at rest, the inner corner 6 px
-- out on each axis); our wedge with its dark back plate read as a blob. Now
-- our own kite blade (TEXTURES.marker, tools/vfx/make_hit_vfx.py kite(),
-- soft halo baked in), `MARKER_ASPECT` wide for its length, at RIVALS'
-- geometry: tips 8 px out at rest (the corner's diagonal), 11 px blades;
-- 40 px / 22 px at the hit.
HitFx.MARKER_ASPECT = 0.4

HitFx.MARKER = table.freeze({
	Body = table.freeze({
		color = hex("FFFFFF"),
		length = 11,
		gap = 8,
		fromLength = 22,
		fromGap = 40,
		speed = 20,
		life = 1.7,
		fadePow = 10,
		ring = false,
	} :: MarkerSpec),
	-- RIVALS' default crit colour (FF3232); the same blades as the body.
	Head = table.freeze({
		color = hex("FF3232"),
		length = 11,
		gap = 8,
		fromLength = 22,
		fromGap = 40,
		speed = 20,
		life = 1.7,
		fadePow = 10,
		ring = false,
	} :: MarkerSpec),
	-- Off (KILL_MARKER = false): the owner wants the same marker on a kill.
	Kill = table.freeze({
		color = hex("FF3232"),
		length = 12,
		gap = 6,
		fromLength = 20,
		fromGap = 30,
		speed = 18,
		life = 1.2,
		fadePow = 6,
		ring = true,
	} :: MarkerSpec),
	Blocked = table.freeze({
		color = hex("A9BCD6"),
		length = 9,
		gap = 8,
		fromLength = 13,
		fromGap = 16,
		speed = 24,
		life = 0.9,
		fadePow = 4,
		ring = false,
	} :: MarkerSpec),
})

-- Uploaded with tools/opencloud/upload_asset.py from tools/vfx/make_hit_vfx.py
-- (art-source/vfx/hit/); image ids (decals 115701958881742, 99616835206256).
HitFx.TEXTURES = table.freeze({
	wedge = "rbxassetid://122694768720895", -- white wedge, tip at the bottom, dark edge baked in (retired 2026-11-15)
	-- The marker blade: white kite, tip at the bottom, soft dark halo baked in
	-- (art-source/vfx/hit/marker_kite.png, decal 106716197115622).
	marker = "rbxassetid://118720323174702",
	headFlash = "rbxassetid://81572027309067", -- radial streak burst, warm colours baked in (procedural, retired)
	-- The owner's ChatGPT headshot flare (art-source/vfx/hit/HeadshotFlare_chatgpt.png,
	-- keyed to alpha and frame-aligned by tools/vfx/make_hit_vfx.py into
	-- head_flare_2x2.png; decal 80426787467983). The one id to swap.
	headFlare = "rbxassetid://120765867865312",
	-- The headshot crown burst: a 4x4 one-shot flipbook of faceted blades
	-- (art-source/vfx/hit/head_crown_4x4.png, decal 138460998541469; drawn by
	-- tools/vfx/make_hit_vfx.py crown_flipbook() after studying RIVALS' burst).
	headCrown = "rbxassetid://99189286604521",
})

-- Wedge length by damage: `min` at `low` damage or less, `max` at `high` or more.
-- The predicted pop starts at the last confirmed size; the confirm eases the
-- wedges to their size at SIZE_RATE (1/s).
HitFx.DAMAGE_SCALE = table.freeze({ low = 10, high = 80, min = 0.9, max = 1.25 })
HitFx.SIZE_RATE = 40

-- The client pops the marker on its predicted hit; the server's confirm
-- arrives about a ping later. A confirm within this many seconds of an
-- unconfirmed pop merges into it instead of popping again.
HitFx.CONFIRM_WINDOW = 0.25

-- A dark wedge drawn behind each marker wedge, `grow` px bigger: the white
-- body-hit wedges sit on a white-flashed body (the baked edge alone was
-- under half a pixel at 4 px wide, 2026-11-13 capture).
-- Off since the kite blade (2026-11-15): its halo is baked in; a solid back
-- plate made the marks read as blobs.
HitFx.MARKER_BACK =
	table.freeze({ enabled = false, color = hex("06080C"), transparency = 0.25, grow = 2.5 })

-- Owner, 2026-11-13 (round 4): "there shouldn't be like a thing on the
-- crosshair when you get a kill". A kill shows the normal hit marker only;
-- true brings back the bigger red wedges and the ring (MARKER.Kill).
HitFx.KILL_MARKER = false

-- The kill ring: expands from `from` to `to` px radius and fades.
HitFx.MARKER_RING = table.freeze({
	from = 10,
	to = 30,
	thickness = 2,
	life = 0.3,
	color = hex("FF3B3B"),
})

-- Damage numbers -----------------------------------------------------------------
-- 2026-11-15 (the owner's hits clip, 60 fps): one number per target that adds
-- up while you keep hitting, ~48 px tall, white for the body and red E01F35
-- with a dark red edge for the head; it holds ~250 ms after the last hit,
-- then tips over clockwise, drops and shrinks over ~270 ms, and a new hit
-- snaps it upright and keeps counting. Ours was 30 px, held 0.9 s and flew
-- off to a random side.
HitFx.NUMBER = table.freeze({
	offset = Vector2.new(58, -44), -- px from the hit point, clear of the biggest X
	family = "Sarpanch",
	weight = Enum.FontWeight.Bold,
	textSize = 42,
	color = hex("FFFFFF"),
	headColor = hex("E01F35"),
	headOutline = hex("4A0810"),
	stroke = 2.5,
	hold = 0.28, -- s it stands after the last hit before it tips over
	killHold = 0.45, -- the same, for the number that made the kill
	stackTime = 0.9, -- s after the last hit on a target that a new hit still adds to its number
	-- The exit: it tips `tip` degrees clockwise, drops `drop` px and drifts
	-- `drift` px right, shrinking to `shrink` of its size, over `time`.
	fall = table.freeze({ time = 0.3, tip = 118, drop = 44, drift = 10, shrink = 0.55 }),
	popScale = 0.5, -- extra scale at a hit, settling over `popTime`
	headPopScale = 0.8,
	popTime = 0.12,
	headSize = 1.15,
	killSize = 1.3,
	-- One number per target, over its head (2026-11-16, owner: it didn't
	-- size with distance and stacked into new numbers). `headLift`: studs
	-- above the head's top. `distance`: sized like a BillboardGui of `studs`
	-- in the world plus `px` on screen (RIVALS' DamageGui: 15 + 250), 1 at
	-- `ref` studs, clamped to `min`..`max`.
	headLift = 0.6,
	distance = table.freeze({ ref = 20, studs = 15, px = 250, min = 0.5, max = 1.35 }),
})

-- Body flash ----------------------------------------------------------------------
-- A Highlight on the body you hit (the character model plus each skinned limb
-- mesh in Workspace.GGBodyLimbs, which live outside it). The fill shows
-- `white` (colour WHITE at `whiteFill`) for `whiteTime`, blends to `color` at
-- `fill` over `blend`, holds until `hold`, then fades out by `time`. The
-- outline starts at `outlineFrom` and fades by `outlineTime`.
-- Owner, 2026-11-13 (RIVALS references): a body hit turns the whole body
-- solid WHITE with a thin red rim; a headshot turns it solid RED.
export type FlashSpec = {
	whiteTime: number,
	whiteFill: number, -- FillTransparency of the white frame
	color: Color3,
	fill: number, -- FillTransparency once it turns `color`
	blend: number,
	hold: number, -- s the fill holds before fading
	time: number,
	outline: Color3,
	outlineFrom: number, -- OutlineTransparency at the hit
	outlineTime: number,
}

-- Owner, 2026-11-13 (third look): "the flash is a bit too prominent. It
-- should be more subtle... that like background kind of effect that just
-- like adds to like the nice feeling of gunplay, but it's not actually like
-- that apparent." So the solid flashes are now see-through (peak fill about
-- 0.6), hold 20-30 ms and are gone in 110-150 ms; still white to red, the
-- head redder than the body.
HitFx.FLASH = table.freeze({
	body = table.freeze({
		whiteTime = 0.03,
		whiteFill = 0.62,
		color = hex("FF6A6A"),
		fill = 0.74,
		blend = 0.04,
		hold = 0.02,
		time = 0.11,
		outline = hex("FF2E3D"),
		outlineFrom = 0.55,
		outlineTime = 0.09,
	} :: FlashSpec),
	head = table.freeze({
		whiteTime = 0.02,
		whiteFill = 0.6,
		color = hex("FF3535"),
		fill = 0.56,
		blend = 0.03,
		hold = 0.03,
		time = 0.15,
		outline = hex("FF5A5A"),
		outlineFrom = 0.6,
		outlineTime = 0.12,
	} :: FlashSpec),
	kill = table.freeze({
		whiteTime = 0.02,
		whiteFill = 0.5,
		color = hex("FF2E3D"),
		fill = 0.46,
		blend = 0.03,
		hold = 0.06,
		time = 0.24,
		outline = hex("FFFFFF"),
		outlineFrom = 0.5,
		outlineTime = 0.2,
	} :: FlashSpec),
	search = 1.5, -- studs around the hit point to find the body
	-- Highlights alive at once for the flash (the engine caps how many draw:
	-- 255 per client in the 2026 docs, 31 in older engines; other systems hold
	-- some, 8 were enabled on the range). A body costs 6 (the model + 5 limb
	-- meshes); past the budget a body flashes its model only, then nothing.
	-- One shooter rarely flashes more than 2-3 bodies inside a kill flash.
	maxHighlights = 18,
	limbs = true, -- also flash the skinned limb meshes
	-- On a kill, DeathFxController hides the body and shows a falling copy
	-- named body.Name .. copySuffix with tag copyTag: the flash moves onto it
	-- if it appears within copyWait seconds.
	copySuffix = "Down",
	copyTag = "DeathFxCopy",
	copyWait = 0.25,
})

-- Slash accent ---------------------------------------------------------------------
-- A small slanted streak at the hit point, facing the camera: a red edge under
-- a white core that wipes in from one end, then thins and fades. Drawn in the
-- world (BillboardGui), `size` studs square with a `minPx` floor so it still
-- reads at range, pulled `towardCamera` studs off the body. `alpha` is its
-- base transparency.
-- Owner, 2026-11-13: "I kind of love it, but I think it's a bit obnoxious":
-- kept, but about half the size, shorter, see-through, one per kill (was a
-- crossed pair) and at most one every `minGap` seconds in a spray.
export type SlashSpec = {
	size: number,
	minPx: number,
	length: number, -- share of the square
	core: number, -- core thickness, share of the square
	edge: number, -- edge thickness, share of the square
	wipe: number,
	life: number,
	count: number, -- 2 = a crossed pair
	alpha: number,
}

HitFx.SLASH = table.freeze({
	body = table.freeze({
		size = 1.9,
		minPx = 24,
		length = 0.9,
		core = 0.04,
		edge = 0.09,
		wipe = 0.035,
		life = 0.1,
		count = 1,
		alpha = 0.2,
	} :: SlashSpec),
	head = table.freeze({
		size = 1.8,
		minPx = 24,
		length = 0.9,
		core = 0.04,
		edge = 0.09,
		wipe = 0.035,
		life = 0.11,
		count = 1,
		alpha = 0.18,
	} :: SlashSpec),
	kill = table.freeze({
		size = 2.4,
		minPx = 30,
		length = 0.95,
		core = 0.04,
		edge = 0.09,
		wipe = 0.045,
		life = 0.15,
		count = 1,
		alpha = 0.15,
	} :: SlashSpec),
	-- Owner, 2026-11-13 (round 4): the slash "still looks a bit off". RIVALS
	-- shows no slash on a body hit (the body flash and the marker carry it)
	-- and Valorant only a small neutral puff at the hit point, which
	-- Util/ImpactFx already draws; so it is off. True brings it back.
	enabled = false,
	angle = NumberRange.new(-62, -38), -- degrees, randomly mirrored
	towardCamera = 1.2,
	minGap = 0.14, -- s between slashes (kills always get one)
	core = hex("FFFFFF"),
	edge = hex("FF3B4A"),
	pool = 4,
})

-- Headshot flash -------------------------------------------------------------------
-- The owner's ChatGPT headshot flare (TEXTURES.headFlare): four frames, left
-- to right, top row first ("the impact flashes, the flame shoots upward, then
-- breaks apart and fades into embers"), each frame's base lined up on one
-- anchor in the sheet (tools/vfx/make_hit_vfx.py). Swap TEXTURES.headFlare for
-- a new version (same 2x2 layout, base at `anchorY`).
-- Owner, 2026-11-13 after seeing it: "The flare effect is just dull and boring.
-- please fix". So it stays short and small but is LOUD while it lasts: a hard
-- white pop and an orange shockwave ring on the hit frame; the flame at full
-- colour and over the Bloom threshold (it glows); it snaps in with an
-- overshoot, rises off the head, stretches up and flicks sideways; sparks and
-- embers fly out with gravity; size, tilt and mirroring change every hit.
export type FlareFrame = { start: number, peak: number, stop: number }

HitFx.HEAD_FLASH = table.freeze({
	rigs = 3,
	grid = 2, -- the sheet is grid x grid frames
	life = 0.3, -- s
	-- Cross-fade windows (s): fade in start -> peak, hold, fade out by stop.
	frames = table.freeze({
		table.freeze({ start = 0, peak = 0.012, stop = 0.08 } :: FlareFrame), -- the impact flash
		table.freeze({ start = 0.03, peak = 0.055, stop = 0.18 } :: FlareFrame), -- the flame shoots up
		table.freeze({ start = 0.12, peak = 0.155, stop = 0.25 } :: FlareFrame), -- breaks apart
		table.freeze({ start = 0.19, peak = 0.22, stop = 0.3 } :: FlareFrame), -- embers
	}),
	alpha = 0, -- full colour at each frame's peak (short is what keeps it subtle)
	brightness = 2.4, -- BillboardGui brightness: over the place's Bloom (2), so it glows
	-- Width in studs over the life (time 0..1, studs): a hard snap past its
	-- size, a bounce back, then it holds.
	-- (30% up after a side-by-side with the RIVALS reference: the flame only
	-- fills about a third of its frame's width, and it read too narrow.)
	size = { 0, 0.6, 0.05, 3.2, 0.14, 2.35, 0.24, 2.6, 1, 2.5 },
	stretch = 0.4, -- extra height (share) while the flame shoots up
	rise = 0.9, -- studs the flame travels up over its life (ease-out)
	flick = NumberRange.new(8, 16), -- degrees it turns over its life, random side
	drift = 0.25, -- studs sideways (the flick's side) over its life
	tilt = 9, -- degrees: a random lean per hit, either way
	sizeJitter = 0.14, -- +- share of size per hit
	mirror = true, -- flip half the hits left to right (the centre flame)
	-- The fan (owner, 2026-11-13: "We can try to fan it out", after a side by
	-- side with the RIVALS headshot): `count` flame copies, the centre one plus
	-- mirrored side copies at +-`angle` degrees (+-`angleJitter` per hit), each
	-- side one `sideScale` of the centre's size and starting `delay` seconds
	-- later; every copy pivots on the flame's base, so they splay from one
	-- point on the head.
	fan = table.freeze({ count = 3, angle = 30, angleJitter = 5, sideScale = 0.8, delay = 0.025 }),
	-- The frames' shared base sits `anchorY` of the way down each frame; it is
	-- put `baseHeight` studs above the head's centre (the top of the head).
	anchorY = 440 / 512,
	baseHeight = 0.3,
	-- The hit frame: a hard white pop and a shockwave ring (particles, additive).
	-- 2026-11-15 (owner, mid-pass: the headshot should look "similar or same
	-- as RIVALS"): RIVALS' hit frame is a small hot impact (3 particles, 1.3
	-- studs shrinking to nothing in 50 ms), not our big white bubble.
	pop = table.freeze({
		count = 3,
		lifetime = 0.06,
		size = { 0, 1.4, 1, 0 },
		zOffset = 1.2, -- drawn in front of the head (behind it, the head hid it)
		transparency = { 0, 0, 1, 0.2 },
		color = hex("FFC79A"),
	}),
	ring = table.freeze({
		enabled = false, -- RIVALS has no ring (2026-11-15)
		lifetime = 0.17,
		size = { 0, 0.7, 1, 3.8 },
		transparency = { 0, 0.05, 0.6, 0.4, 1, 1 },
		color = hex("FF6A2E"),
	}),
	-- 2026-11-15, RIVALS pass: the rest of the burst follows RIVALS' layer
	-- recipe (Misc.HeadshotParticles, vault/03 Research/Rivals Reference/Body,
	-- Viewmodel, Guns and VFX.md) with our own textures: the white pop on the
	-- hit frame, then `burstDelay` later the flame fan plus a big soft glow, a
	-- dark layer (negative LightEmission: it reads as contrast behind the
	-- glow, not a black blob), an upward streak and stretched shards that
	-- burst out and stop dead (high drag). Everything rides one colour ramp,
	-- white -> orange -> red. Sizes are studs in the world.
	burstDelay = 0.05,
	-- The crown (RIVALS' "big middle", owner 2026-11-15: "really see what
	-- rivals does"): their main layer is a 4x4 one-shot flipbook of sharp
	-- blades (a tall centre one, two at +-38 degrees, chips further out) from
	-- one base above the head, which shoot out, split and break up over half
	-- a second, pushed bright into the bloom. Ours is our own faceted drawing
	-- (TEXTURES.headCrown) on RIVALS' size and fade curves; its base sits
	-- `baseShare` of the size below the particle's centre. `flare` true
	-- brings back the ChatGPT flame fan as well.
	flare = false,
	crown = table.freeze({
		count = 2, -- stacked (RIVALS stacks 5) for a hot core
		lifetime = 0.5,
		size = { 0, 0, 0.1, 3.33, 0.2, 3.66, 0.3, 3.8, 0.5, 3.9, 1, 3.94 },
		transparency = {
			0,
			0,
			0.1,
			0,
			0.2,
			0.02,
			0.3,
			0.06,
			0.4,
			0.14,
			0.5,
			0.55,
			0.6,
			0.87,
			0.8,
			0.98,
			1,
			1,
		},
		baseShare = 0.12,
		brightness = 2.5, -- over the place's Bloom (2): it glows, like RIVALS' 4
		zOffset = 0.6, -- in front of the head
		scale = 0.85, -- our heads read a little smaller at our FOV
	}),
	ramp = table.freeze({ hex("FFFFFF"), hex("FF8146"), hex("FF1111") }), -- at 0, 0.25, 1
	glow = table.freeze({
		lifetime = 0.4,
		-- Half RIVALS' size and much fainter: on our bright range the full
		-- glow whited out the head (2026-11-15 capture).
		size = { 0, 0, 0.1, 1.6, 0.3, 2.2, 0.6, 2.5, 1, 2.6 },
		transparency = { 0, 0.55, 0.1, 0.62, 0.3, 0.78, 0.6, 0.92, 1, 1 },
		zOffset = 0.5,
	}),
	dark = table.freeze({
		enabled = true,
		lifetime = 0.35,
		size = { 0, 0, 0.1, 1.25, 0.3, 1.7, 1, 2 },
		transparency = { 0, 0.3, 0.1, 0.72, 0.3, 0.9, 1, 1 },
		lightEmission = -2,
	}),
	streak = table.freeze({
		lifetime = 0.45,
		speed = 28, -- studs/s up, stopped by `drag`
		drag = 15,
		size = { 0, 0, 0.1, 1.2, 1, 1.4 },
		squash = { 0, 4, 0.1, 1, 0.3, 0.25, 1, 0 }, -- tall at first, then round
		transparency = { 0, 0, 0.1, 0.76, 0.3, 0.94, 1, 1 },
		zOffset = 0.5,
	}),
	sparks = table.freeze({
		count = 9,
		size = 0.24, -- peak, at 10 % of the life, then thins to nothing
		squash = 2.3, -- stretched along their flight
		speed = NumberRange.new(17, 42),
		lifetime = NumberRange.new(0.15, 0.35),
		spread = 48,
		drag = 13, -- they burst out and stop (RIVALS 15)
		gravity = 12, -- studs/s² down
	}),
	embers = table.freeze({
		count = 0, -- RIVALS has no embers; the shards carry it (2026-11-15)
		size = { 0, 0.16, 1, 0 },
		speed = NumberRange.new(7, 15),
		lifetime = NumberRange.new(0.3, 0.5),
		spread = 120,
		drag = 2,
		gravity = 28,
		color = hex("FFB347"),
	}),
	away = 0.3, -- sparks fly along (shot direction * away + up)
	kill = 1.2,
	-- No size-by-distance (2026-11-16): every size here is studs in the world,
	-- like RIVALS' HeadshotParticles, so a far headshot is small on screen.
})

-- Ability hits ---------------------------------------------------------------------
-- Owner, 2026-11-15: damage from a Mod (Molly's fire, Updraft's slam, ...) still
-- gives the crosshair marker but NO floating damage numbers. The server names
-- the Mod in the hit confirm (HitConfirm.source, never client-sent); guns and
-- the knife carry none and keep the full feedback. `SOURCES[modId]` overrides
-- `SOURCE_DEFAULT` for one Mod.
--   marker   the crosshair hit marker (and the kill marker on a kill)
--   numbers  the floating damage number
--   worldFx  the effects drawn on the victim's body or at the hit point (the
--            body flash, the BLOCKED tag): "always", "visible" (only while the
--            attacker has a clear line to the point: a hit round a corner or
--            through a wall must not mark the hidden enemy) or "never"
export type SourceRule = {
	marker: boolean,
	numbers: boolean,
	worldFx: "always" | "visible" | "never",
}

HitFx.SOURCE_DEFAULT = table.freeze({
	marker = true,
	numbers = false,
	worldFx = "visible",
} :: SourceRule)
HitFx.SOURCES = table.freeze({} :: { [string]: SourceRule })
-- Line of sight: a ray from the camera to the hit point; things that stop it
-- closer than `slack` studs short of the point count as cover (the victim's own
-- body is not cover: nothing with a Humanoid in it blocks).
HitFx.SIGHT = table.freeze({ slack = 1.5 })

-- Bullet impacts on the world play their surface's sound (Util/ImpactFx;
-- the sounds are the audio lane's, Config/Sounds IMPACTS), 3D at the hit
-- point, at most one every `minGap` seconds so pellets don't stack.
HitFx.IMPACT_SOUND = table.freeze({ volume = 0.5, range = 60, minGap = 0.03 })

return table.freeze(HitFx)
