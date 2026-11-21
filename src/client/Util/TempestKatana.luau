--!strict
-- Tempest-Strike Katana (knife slot, first person). Replaced the Kunai-Katana
-- on 2026-11-22 (owner: "it should look like a lightsaber with the blade over
-- the whole thing ... more like a katana"; vault 02 Art/Skins/TempestStrike/
-- Kunai-Katana Concept.md). Built our way, the Vandal's water language:
--   - the cutting edge (the export's water parts) burns as bright water the
--     whole length, with a shimmering skin and a soft halo, brightest at the tip;
--   - two laminar water ribbons run guard to tip along the flats, hair-thin
--     lightning crackles along the spine;
--   - two lights down the blade, so it lights the hands and the world;
--   - every cut leaves a full-blade crescent of water with a static edge; the
--     Tempest Cleave (heavy) flares the blade white while it coils, then throws
--     a wide crescent of water and arcs;
--   - draw: the ring pommel spins once into the palm and a surge runs guard to
--     tip; inspect: a water-and-lightning wave runs down the level blade;
--   - the shuriken charm swings from the ring.
-- Moves are Config/Viewmodel's Katana* tracks (ViewmodelController picks them).
-- Points are Blender units of the export (X along the blade, origin at the hand);
-- the blade's outline is SkinPreview.TEMPEST.KATANA.BLADE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local StateValues = require(Shared.StateValues)
local Tempest = require(Shared.Config.SkinPreview).TEMPEST
local Style = Tempest.KATANA
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local TempestAudio = require(Shared.Config.TempestAudio)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

type Spring = { x: number, v: number }
export type State = {
	body: BasePart,
	toBody: CFrame,
	scale: number,
	edges: { BasePart },
	shells: { BasePart },
	ring: Motor6D?,
	charm: Motor6D?,
	charmS: Spring,
	halo: { Beam },
	ribbons: { Beam },
	bolts: { Beam },
	boltPoints: { Attachment },
	trails: { wave: Trail, static: Trail },
	band: { at: Attachment, rings: ParticleEmitter },
	burst: ParticleEmitter,
	burstAt: Attachment,
	cleave: { flash: ParticleEmitter, arcs: ParticleEmitter, at: Attachment },
	tipArcs: ParticleEmitter,
	lights: { PointLight },
	clock: number,
	nextArc: number,
	arcUntil: number,
	inspectPrev: number?,
	drawPrev: number?,
	swingPrev: number?,
	surge: number, -- 0..1: the Cleave's coil, the draw's surge
	visible: boolean,
}

local TempestKatana = {}

local function bl(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function spring(s: Spring, goal: number, freq: number, damp: number, dt: number)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	local w = 2 * math.pi * freq
	for _ = 1, steps do
		s.v += (w * w * (goal - s.x) - 2 * damp * w * s.v) * h
		s.x += s.v * h
	end
end

-- The blade's outline at t (0 guard .. 1 tip, even along its length): x, the
-- water band's middle z, spine z.
local function blade(t: number): (number, number, number)
	local st = Style.BLADE
	local x = st[1][1] + (st[#st][1] - st[1][1]) * math.clamp(t, 0, 1)
	for i = 2, #st do
		local a, b = st[i - 1], st[i]
		if x <= b[1] or i == #st then
			local k = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			local edge = a[2] + (b[2] - a[2]) * k
			local lift = Style.EDGE_LIFT * (1 - math.clamp((t - 0.9) / 0.1, 0, 1))
			return x, edge + lift, a[3] + (b[3] - a[3]) * k
		end
	end
	local last = st[#st]
	return last[1], last[2], last[3]
end

local function cue(state: State, name: string)
	if state.visible then
		AudioController.playSound(TempestAudio.cues[name], "Foley")
	end
end

-- An attachment on the Root-motor part at a Blender point of the blade's rest pose.
local function anchor(state: State, name: string, p: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = state.toBody:PointToWorldSpace(p * state.scale)
	a.Parent = state.body
	return a
end

local function emitter(parent: Instance, name: string, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
	e.LightEmission = 0.9
	e.LightInfluence = 0
	e.Brightness = 1.6
	e.Rate = 0
	e.Speed = NumberRange.new(0)
	e.LockedToPart = true
	e.Enabled = false
	e.Parent = parent
	return e
end

-- A chain of beams through `points` (one per gap), shaped by `make(i, t0, t1)`.
local function chain(points: { Attachment }, make: (number, number, number) -> Beam): { Beam }
	local out: { Beam } = {}
	for i = 1, #points - 1 do
		local b = make(i, (i - 1) / (#points - 1), i / (#points - 1))
		b.Attachment0, b.Attachment1 = points[i], points[i + 1]
		b.Parent = points[i]
		table.insert(out, b)
	end
	return out
end

-- The export's water and inlay parts: matte water cyan (TS Water) or Neon (TS Neon).
local function isWater(p: MeshPart): boolean
	if p.Material == Enum.Material.Neon then
		return true
	end
	local c = p.Color
	local w = Style.EXPORT_WATER
	return math.abs(c.R - w.R) + math.abs(c.G - w.G) + math.abs(c.B - w.B) < 0.12
end

function TempestKatana.new(model: Model, scale: number): State?
	if
		StateValues.get(model, "SkinLine") ~= Tempest.LINE
		or StateValues.get(model, "WeaponId") ~= "Knife"
	then
		return nil
	end
	local handle = model.PrimaryPart
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local root = motors and motors:FindFirstChild("Root")
	local body = if root and root:IsA("Motor6D") then root.Part1 else nil
	if not handle or not body then
		return nil
	end
	local function motor(name: string): Motor6D?
		local m = motors and motors:FindFirstChild(name)
		return if m and m:IsA("Motor6D") then m else nil
	end
	local state: State = {
		body = body,
		toBody = body.CFrame:ToObjectSpace(handle.CFrame),
		scale = scale,
		edges = {},
		shells = {},
		ring = motor("TS_Ring"),
		charm = motor("TS_Charm"),
		charmS = { x = 0, v = 0 },
		halo = {},
		ribbons = {},
		bolts = {},
		boltPoints = {},
		trails = nil :: any,
		band = nil :: any,
		burst = nil :: any,
		burstAt = nil :: any,
		cleave = nil :: any,
		tipArcs = nil :: any,
		lights = {},
		clock = 0,
		nextArc = 0,
		arcUntil = 0,
		inspectPrev = nil,
		drawPrev = nil,
		swingPrev = nil,
		surge = 0,
		visible = true,
	}
	-- the edge: bright water with a shimmering skin (copies welded on before
	-- ViewmodelRig, like Util/TempestCoat)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and isWater(d) then
			d.Material = Enum.Material.Neon
			d.Color = Style.EDGE_COLOR
			table.insert(state.edges, d)
			local shell = d:Clone()
			shell:ClearAllChildren()
			shell.Name = "TempestKatanaSkin"
			shell.Material = Enum.Material.ForceField
			shell.Color = Tempest.WATER
			shell.Transparency = 1 - Style.SKIN_OPACITY
			shell.CastShadow = false
			shell.CanCollide = false
			shell.CanQuery = false
			shell.CanTouch = false
			shell.Massless = true
			shell.Size = d.Size + Vector3.one * (Style.SKIN_PAD * scale)
			shell.CFrame = d.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = d
			weld.Part1 = shell
			weld.Parent = shell
			shell.Parent = d.Parent
			table.insert(state.shells, shell)
		end
	end
	local N = Style.SEGMENTS
	-- the halo: a glowing sheath laid over the edge, guard to tip, widest at the tip
	local edgePts: { Attachment } = {}
	for i = 0, N do
		local x, ez = blade(i / N)
		table.insert(edgePts, anchor(state, "TempestKatanaEdge" .. i, bl(x, 0, ez)))
	end
	state.halo = chain(edgePts, function(_i, t0, t1)
		local b = Instance.new("Beam")
		b.Name = "TempestKatanaHalo"
		-- the laminar band texture tiled slowly: a continuous glowing sheath (a
		-- round glow stretched per segment would bead along the blade)
		b.Texture = VFX.TEMPEST_WATER_RIBBON
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = Tempest.RIBBON_TILE * 2 * scale
		b.TextureSpeed = Style.HALO_SPEED
		b.Color = ColorSequence.new(Tempest.WATER)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = Style.HALO_BRIGHTNESS
		b.Transparency = NumberSequence.new(Style.HALO_TRANSPARENCY)
		b.FaceCamera = true
		local w0 = Style.HALO_WIDTH[1] + (Style.HALO_WIDTH[2] - Style.HALO_WIDTH[1]) * t0
		local w1 = Style.HALO_WIDTH[1] + (Style.HALO_WIDTH[2] - Style.HALO_WIDTH[1]) * t1
		b.Width0, b.Width1 = w0 * scale, w1 * scale
		b.Segments = 2
		b.Enabled = false
		return b
	end)
	-- the ribbons: two laminar streams down the flats, guard to tip
	for _, side in { 1, -1 } do
		local pts: { Attachment } = {}
		for i = 0, N do
			local t = i / N
			local x, ez, sz = blade(t)
			local y = side * Style.RIBBON_OFFSET * (1 - 0.6 * t)
			table.insert(
				pts,
				anchor(state, "TempestKatanaRibbon" .. i, bl(x, y, ez + (sz - ez) * 0.45))
			)
		end
		for _, b in
			chain(pts, function(_i, t0, t1)
				local beam = Instance.new("Beam")
				beam.Name = "TempestKatanaWater"
				beam.Texture = VFX.TEMPEST_WATER_RIBBON
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = Tempest.RIBBON_TILE * scale
				beam.TextureSpeed = Tempest.RIBBON_SPEED * 1.4
				beam.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
				beam.LightEmission = 0.9
				beam.LightInfluence = 0
				beam.Brightness = Tempest.RIBBON_BRIGHTNESS
				beam.FaceCamera = true
				local taper = function(t: number): number
					return math.clamp(math.min(t, 1 - t) / 0.15, 0.25, 1)
				end
				beam.Width0 = Style.RIBBON_WIDTH * scale * taper(t0)
				beam.Width1 = Style.RIBBON_WIDTH * scale * taper(t1)
				beam.Segments = 3
				beam.Enabled = false
				return beam
			end)
		do
			table.insert(state.ribbons, b)
		end
	end
	-- spine lightning: a chain of points the bolts jump between
	for i = 0, Style.BOLT_POINTS - 1 do
		local x, _, sz = blade(0.08 + 0.88 * i / (Style.BOLT_POINTS - 1))
		table.insert(
			state.boltPoints,
			anchor(state, "TempestKatanaArc" .. i, bl(x, 0, sz + Style.BOLT_LIFT))
		)
	end
	state.bolts = chain(state.boltPoints, function()
		local b = Instance.new("Beam")
		b.Name = "TempestKatanaBolt"
		b.Texture = VFX.STIM_BOLT
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = 5
		b.Color = ColorSequence.new(Tempest.ARC_CORE, Tempest.WATER_EDGE)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.2
		b.FaceCamera = true
		b.Width0, b.Width1 = Style.BOLT_WIDTH * scale, Style.BOLT_WIDTH * scale
		b.Segments = 5
		b.Enabled = false
		return b
	end)
	-- trails: the crescent the whole blade cuts, and a static line off the edge
	local function trail(name: string, p0: Vector3, p1: Vector3, texture: string): Trail
		local a0 = anchor(state, name .. "0", p0)
		local a1 = anchor(state, name .. "1", p1)
		local tr = Instance.new("Trail")
		tr.Name = name
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Texture = texture
		tr.TextureMode = Enum.TextureMode.Stretch
		tr.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Brightness = 2
		tr.Lifetime = Style.TRAIL_LIFE
		tr.MinLength = 0.01
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		tr.Enabled = false
		tr.Parent = a0
		return tr
	end
	local gx, gez = blade(0)
	local tx, tez = blade(1)
	local mx, mez = blade(0.55)
	state.trails = {
		wave = trail("TempestKatanaWave", bl(gx, 0, gez), bl(tx, 0, tez), VFX.TEMPEST_WATER_RIBBON),
		static = trail("TempestKatanaStatic", bl(mx, 0, mez), bl(tx, 0, tez), VFX.TEMPEST_ARC_2x2),
	}
	state.trails.static.Color = ColorSequence.new(Tempest.ARC_CORE, Tempest.WATER_EDGE)
	state.trails.static.Lifetime = Style.TRAIL_LIFE * 0.6
	-- the band: water rings running along the blade (draw surge, inspect wave)
	local bandAt = anchor(state, "TempestKatanaBand", bl(gx, 0, gez))
	local rings = emitter(bandAt, "TempestKatanaBandRings", VFX.MOD_RING)
	rings.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
	rings.Brightness = 1.6
	rings.Lifetime = NumberRange.new(0.12)
	rings.Speed = NumberRange.new(0.02)
	rings.EmissionDirection = Enum.NormalId.Front
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16 * scale),
		NumberSequenceKeypoint.new(1, 0.28 * scale),
	})
	rings.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	state.band = { at = bandAt, rings = rings }
	-- droplets: the draw, the inspect's end, the ring spin
	local burstAt = anchor(state, "TempestKatanaBurst", bl(mx, 0, mez))
	local burst = emitter(burstAt, "TempestKatanaDrops", VFX.TEMPEST_DROPLETS_2x2)
	burst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	burst.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	burst.Lifetime = NumberRange.new(0.3, 0.5)
	burst.Speed = NumberRange.new(0.8 * scale, 2 * scale)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -9 * scale, 0)
	burst.Drag = 3
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1 * scale),
		NumberSequenceKeypoint.new(1, 0.04 * scale),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	state.burst, state.burstAt = burst, burstAt
	-- the Cleave's crescent: a wide flash and arcs thrown from the blade
	local cx, cez = blade(0.6)
	local cat = anchor(state, "TempestCleave", bl(cx, 0, cez))
	local flash = emitter(cat, "TempestCleaveFlash", VFX.TEMPEST_SPLASH_2x2)
	flash.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	flash.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	flash.Lifetime = NumberRange.new(0.18)
	flash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * scale),
		NumberSequenceKeypoint.new(1, Style.CLEAVE_SIZE * scale),
	})
	flash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	flash.LockedToPart = false
	local arcs = emitter(cat, "TempestCleaveArcs", VFX.TEMPEST_ARC_2x2)
	arcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	arcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
	arcs.Color = ColorSequence.new(Tempest.ARC_CORE, Tempest.WATER_EDGE)
	arcs.Brightness = 2
	arcs.Lifetime = NumberRange.new(0.08, 0.14)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.Size = NumberSequence.new(0.7 * scale)
	arcs.LockedToPart = false
	state.cleave = { flash = flash, arcs = arcs, at = cat }
	-- a crackle off the tip on every cut
	local tipAt = anchor(state, "TempestKatanaTip", bl(tx, 0, tez))
	local tipArcs = emitter(tipAt, "TempestKatanaTipArcs", VFX.TEMPEST_ARC_2x2)
	tipArcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	tipArcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
	tipArcs.Color = ColorSequence.new(Tempest.ARC_CORE, Tempest.WATER_EDGE)
	tipArcs.Brightness = 2
	tipArcs.Lifetime = NumberRange.new(0.06, 0.1)
	tipArcs.Rotation = NumberRange.new(0, 360)
	tipArcs.Size = NumberSequence.new(0.35 * scale)
	tipArcs.LockedToPart = false
	state.tipArcs = tipArcs
	-- the blade's light, at the middle and near the tip
	for i, t in Style.LIGHT_AT do
		local x, ez, sz = blade(t)
		local la = anchor(state, "TempestKatanaLight" .. i, bl(x, 0, (ez + sz) / 2))
		local light = Instance.new("PointLight")
		light.Color = Tempest.WATER
		light.Brightness = 0
		light.Range = Style.LIGHT_RANGE * scale
		light.Shadows = false
		light.Parent = la
		table.insert(state.lights, light)
	end
	return state
end

-- Runs the band of rings to blade station t (0 guard .. 1 tip).
local function placeBand(state: State, t: number)
	local x, ez, sz = blade(t)
	local x2 = blade(math.min(t + 0.02, 1))
	local p = state.toBody:PointToWorldSpace(bl(x, 0, (ez + sz) / 2) * state.scale)
	local d = state.toBody:VectorToWorldSpace(bl(math.max(x2 - x, 1e-3), 0, 0))
	state.band.at.CFrame = CFrame.lookAt(p, p + d)
end

-- Every frame. swingP: progress of the current melee move (nil when none);
-- heavy: it is the Cleave; hit: its contact frame (0..1).
function TempestKatana.step(
	state: State,
	dt: number,
	visible: boolean,
	drawP: number?,
	inspectP: number?,
	swingP: number?,
	heavy: boolean,
	hit: number?
)
	local s = math.min(dt, 0.1)
	local reduced = UiMotion.reduced()
	state.visible = visible
	state.clock += s
	local surgeGoal = 0
	local band: number? = nil
	local charmKick = 0
	-- draw: the ring spins once into the palm, then a surge runs guard to tip
	local ring = 0
	if drawP then
		if state.drawPrev == nil then
			cue(state, "draw")
			charmKick += 1
		end
		ring = 360 * Style.RING_TURNS * smooth(0, Style.RING_SPIN_END, drawP)
		local d0, d1 = Style.DRAW_SURGE[1], Style.DRAW_SURGE[2]
		if drawP > d0 and drawP < d1 then
			band = smooth(d0, d1, drawP)
		end
		surgeGoal =
			math.max(surgeGoal, smooth(d0, d0 + 0.05, drawP) * (1 - smooth(d1, d1 + 0.15, drawP)))
		local prev = state.drawPrev or 0
		if prev < d1 and drawP >= d1 then
			cue(state, "drawLock")
			state.burstAt.Position =
				state.toBody:PointToWorldSpace(bl(blade(1), 0, 0) * state.scale)
			state.burst:Emit(if reduced then 3 else 8)
		end
	end
	state.drawPrev = drawP
	if state.ring then
		state.ring.Transform = CFrame.fromAxisAngle(Style.RING_AXIS, math.rad(ring))
	end
	-- inspect: the ring spin (the track's toss), then the wave down the level blade
	local prev = state.inspectPrev or 0
	if inspectP then
		if inspectP < prev then
			prev = 0
		end
		if prev < 0.02 and inspectP >= 0.02 then
			cue(state, "inspect")
		end
		if prev < Style.INSPECT_SPIN and inspectP >= Style.INSPECT_SPIN then
			cue(state, "inspectRoll")
			charmKick += 1.4
		end
		local w0, w1 = Style.INSPECT_WAVE[1], Style.INSPECT_WAVE[2]
		if inspectP > w0 and inspectP < w1 then
			band = smooth(w0, w1, inspectP)
			surgeGoal = math.max(surgeGoal, 0.45)
		end
		if prev < w1 and inspectP >= w1 then
			cue(state, "inspectCatch")
			state.burstAt.Position =
				state.toBody:PointToWorldSpace(bl(blade(1), 0, 0) * state.scale)
			state.burst:Emit(if reduced then 4 else 12)
		end
	end
	state.inspectPrev = inspectP
	-- cuts: the Cleave coils white, then its crescent; every cut crackles off the tip
	local sp = state.swingPrev or 0
	if swingP then
		local h = hit or 0.4
		if sp == 0 or swingP < sp then
			charmKick += 0.8
		end
		if heavy then
			surgeGoal =
				math.max(surgeGoal, smooth(0, h * 0.85, swingP) * (1 - smooth(h, h + 0.12, swingP)))
		end
		if sp < h and swingP >= h then
			if not reduced then
				state.tipArcs:Emit(if heavy then 4 else 2)
			end
			if heavy then
				state.cleave.flash:Emit(1)
				if not reduced then
					state.cleave.arcs:Emit(5)
				end
				cue(state, "cleave")
			end
		end
	end
	state.swingPrev = swingP
	state.surge += (surgeGoal - state.surge) * (1 - math.exp(-12 * s))
	-- the charm swings from the ring (kicked by every move, settles)
	if charmKick > 0 then
		state.charmS.v += Style.CHARM_KICK * charmKick * (if math.random() < 0.5 then -1 else 1)
	end
	spring(state.charmS, 0, Style.CHARM_FREQ, Style.CHARM_DAMP, s)
	if state.charm then
		-- it hangs from the ring, so it rides the ring's spin (about the ring centre)
		local sway = math.rad(state.charmS.x + Style.CHARM_IDLE * math.sin(state.clock * 1.7))
		local up = Vector3.new(0, 0, Style.CHARM_HANG * state.scale)
		state.charm.Transform = CFrame.new(up)
			* CFrame.fromAxisAngle(Style.RING_AXIS, math.rad(ring))
			* CFrame.new(-up)
			* CFrame.fromAxisAngle(Style.CHARM_AXIS, sway)
	end
	-- trails while a move cuts
	local cutting = swingP ~= nil and swingP > 0.06 and swingP < 0.75 and visible
	if state.trails.wave.Enabled ~= cutting then
		state.trails.wave.Enabled = cutting
	end
	local staticOn = cutting and not reduced
	if state.trails.static.Enabled ~= staticOn then
		state.trails.static.Enabled = staticOn
	end
	-- the band
	local bandOn = band ~= nil and visible and not reduced
	if bandOn and band then
		placeBand(state, band)
	end
	state.band.rings.Rate = if bandOn then 110 else 0
	if state.band.rings.Enabled ~= bandOn then
		state.band.rings.Enabled = bandOn
	end
	-- edge, halo, ribbons and light; all brighter in a surge
	local pulse = 0.92 + 0.08 * math.sin(state.clock * 4.2)
	local hot = state.surge
	local edgeColor = Style.EDGE_COLOR:Lerp(Tempest.ARC_CORE, hot)
	for _, p in state.edges do
		if p.Color ~= edgeColor then
			p.Color = edgeColor
		end
	end
	for _, sh in state.shells do
		sh.Transparency = if visible then 1 - Style.SKIN_OPACITY * (1 + 0.4 * hot) else 1
	end
	for _, b in state.halo do
		b.Enabled = visible
		if visible then
			b.Brightness = Style.HALO_BRIGHTNESS * pulse * (1 + Style.SURGE_GAIN * hot)
		end
	end
	for _, b in state.ribbons do
		b.Enabled = visible
		if visible then
			b.Brightness = Tempest.RIBBON_BRIGHTNESS * (1 + Style.SURGE_GAIN * hot)
			b.TextureSpeed = if reduced then 0 else Tempest.RIBBON_SPEED * 1.4 * (1 + 2 * hot)
		end
	end
	for _, l in state.lights do
		l.Enabled = visible
		l.Brightness = Style.LIGHT * pulse + Style.LIGHT_SURGE * hot
	end
	-- lightning: random flickers along the spine (constant in a surge or a wave)
	local boltOn = false
	if visible and not reduced then
		if state.clock >= state.nextArc or hot > 0.4 then
			state.arcUntil = state.clock + 0.05 + 0.04 * math.random()
			state.nextArc = state.clock
				+ Style.ARC_GAP[1]
				+ math.random() * (Style.ARC_GAP[2] - Style.ARC_GAP[1])
			local j = Style.ARC_JITTER * state.scale
			for i, a in state.boltPoints do
				local x, _, sz = blade(0.08 + 0.88 * (i - 1) / (#state.boltPoints - 1))
				a.Position = state.toBody:PointToWorldSpace(
					bl(x, 0, sz + Style.BOLT_LIFT) * state.scale
				) + Vector3.new(
					(math.random() - 0.5) * j,
					(math.random() - 0.5) * j,
					(math.random() - 0.5) * j
				)
			end
		end
		boltOn = state.clock < state.arcUntil
	end
	for _, b in state.bolts do
		if b.Enabled ~= boltOn then
			b.Enabled = boltOn
		end
	end
end

return TempestKatana
