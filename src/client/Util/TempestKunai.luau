--!strict
-- Tempest-Strike Kunai-Katana (knife slot, first person). The owner's concept
-- (vault 02 Art/Skins/TempestStrike/Kunai-Katana Concept.md), built our way:
--   - the water katana (SK_TS_Katana_*, on the TS_Katana joint) is translucent
--     water with a shimmering ForceField skin, so the black kunai shows through;
--   - two forms: the compact kunai (default) and the extended water katana.
--     Inspect toggles: the blade slides out of the kunai with a band of water
--     running to the tip and a lightning flash, or bursts back into droplets;
--   - water ribbons wrap the katana and hair-thin arcs flicker along it (or
--     along the kunai's etched crack in the compact form);
--   - swings leave a water trail (kunai or katana length), the heavy draws a
--     white-lightning surge then throws a wide crescent of water and static;
--   - the draw twirls the pommel ring (TS_Ring) with water spinning off it.
-- Points are Blender units of the export (X along the blade, origin at the hand).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local StateValues = require(Shared.StateValues)
local Tempest = require(Shared.Config.SkinPreview).TEMPEST
local Style = Tempest.KUNAI
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local TempestAudio = require(Shared.Config.TempestAudio)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

type Spring = { x: number, v: number }
export type State = {
	body: BasePart,
	toBody: CFrame,
	scale: number,
	blade: { BasePart },
	bladeRest: { [BasePart]: number },
	shells: { BasePart },
	katana: Motor6D?,
	ring: Motor6D?,
	ribbons: { Beam },
	arcs: { Beam },
	arcPoints: { Attachment },
	crack: ParticleEmitter,
	trails: { kunai: Trail, katana: Trail },
	sweep: { at: Attachment, rings: ParticleEmitter },
	burst: ParticleEmitter,
	burstAt: Attachment,
	cleave: { flash: ParticleEmitter, arcs: ParticleEmitter, at: Attachment },
	light: PointLight,
	extended: boolean, -- the form the player picked
	ext: Spring, -- 0 kunai .. 1 katana, sprung (snaps out, settles)
	clock: number,
	nextArc: number,
	arcUntil: number,
	inspectPrev: number?,
	drawPrev: number?,
	swingPrev: number?,
	surge: number, -- heavy wind-up glow
	visible: boolean,
}

local TempestKunai = {}

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

local function cue(state: State, name: string)
	if state.visible then
		AudioController.playSound(TempestAudio.cues[name], "Foley")
	end
end

-- An attachment on the Root-motor part at a Blender point of the knife's rest pose.
local function anchor(state: State, name: string, x: number, y: number, z: number): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = state.toBody:PointToWorldSpace(bl(x, y, z) * state.scale)
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

function TempestKunai.new(model: Model, scale: number): State?
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
		blade = {},
		bladeRest = {},
		shells = {},
		katana = motor("TS_Katana"),
		ring = motor("TS_Ring"),
		ribbons = {},
		arcs = {},
		arcPoints = {},
		crack = nil :: any,
		trails = nil :: any,
		sweep = nil :: any,
		burst = nil :: any,
		burstAt = nil :: any,
		cleave = nil :: any,
		light = nil :: any,
		extended = false,
		ext = { x = 0, v = 0 },
		clock = 0,
		nextArc = 0,
		arcUntil = 0,
		inspectPrev = nil,
		drawPrev = nil,
		swingPrev = nil,
		surge = 0,
		visible = true,
	}
	-- the water blade: translucent water with a shimmering skin (copies welded on
	-- before ViewmodelRig, like Util/TempestCoat)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and string.match(d.Name, "^SK_TS_Katana") then
			d.Material = Enum.Material.Glass
			d.Color = Style.WATER_BODY
			d.Reflectance = 0.15
			table.insert(state.blade, d)
			state.bladeRest[d] = Style.BLADE_TRANSPARENCY
			local shell = d:Clone()
			shell:ClearAllChildren()
			shell.Name = "TempestKatanaSkin"
			shell.Material = Enum.Material.ForceField
			shell.Color = Tempest.WATER
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
	-- ribbons: two helices round the katana, guard side to tip
	local w = Style.RIBBON_WIDTH * scale
	local N = 12
	for _, start in { 0, math.pi } do
		local points: { Attachment } = {}
		for i = 0, N do
			local t = i / N
			local angle = start + t * 2 * math.pi * Style.HELIX_TURNS
			local x = Style.KATANA_ROOT + (Style.KATANA_TIP - 0.08 - Style.KATANA_ROOT) * t
			local ry = 0.03 + (0.014 - 0.03) * t
			local rz = 0.085 + (0.03 - 0.085) * t
			table.insert(
				points,
				anchor(
					state,
					"TempestKatanaHelix" .. i,
					x,
					ry * math.cos(angle),
					rz * math.sin(angle)
				)
			)
		end
		for i = 1, N do
			local b = Instance.new("Beam")
			b.Name = "TempestKatanaWater"
			b.Attachment0, b.Attachment1 = points[i], points[i + 1]
			b.Texture = VFX.TEMPEST_WATER_RIBBON
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = Tempest.RIBBON_TILE * scale
			b.TextureSpeed = Tempest.RIBBON_SPEED * 1.4
			b.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
			b.LightEmission = 0.9
			b.LightInfluence = 0
			b.Brightness = Tempest.RIBBON_BRIGHTNESS
			b.FaceCamera = true
			local taper = math.clamp(math.min((i - 1) / N, 1 - i / N) / 0.2, 0.3, 1)
			b.Width0, b.Width1 = w * taper, w * taper
			b.Segments = 3
			b.Enabled = false
			b.Parent = points[i]
			table.insert(state.ribbons, b)
		end
	end
	-- lightning along the blade: a chain of points the bolts jump between
	for i, x in Style.ARC_STATIONS do
		table.insert(state.arcPoints, anchor(state, "TempestKatanaArc" .. i, x, 0, 0.02))
	end
	for i = 1, #state.arcPoints - 1 do
		local b = Instance.new("Beam")
		b.Name = "TempestKatanaBolt"
		b.Attachment0, b.Attachment1 = state.arcPoints[i], state.arcPoints[i + 1]
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
		b.Parent = state.arcPoints[i]
		table.insert(state.arcs, b)
	end
	-- the etched crack flickers in the compact form
	local crackAt = anchor(state, "TempestKunaiCrack", Style.CRACK_X, 0, 0.03)
	local crack = emitter(crackAt, "TempestKunaiCrackArc", VFX.TEMPEST_ARC_2x2)
	crack.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	crack.FlipbookMode = Enum.ParticleFlipbookMode.Random
	crack.Color = ColorSequence.new(Tempest.ARC_CORE, Tempest.WATER)
	crack.Lifetime = NumberRange.new(0.05, 0.09)
	crack.Rotation = NumberRange.new(-20, 20)
	crack.Size = NumberSequence.new(0.09 * scale)
	crack.Rate = Style.CRACK_RATE
	state.crack = crack
	-- swing trails: the kunai edge always, the katana when it is out
	local function trail(name: string, x0: number, x1: number, width: number): Trail
		local a0 = anchor(state, name .. "0", x0, 0, 0)
		local a1 = anchor(state, name .. "1", x1, 0, 0)
		local tr = Instance.new("Trail")
		tr.Name = name
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Texture = VFX.TEMPEST_WATER_RIBBON
		tr.TextureMode = Enum.TextureMode.Stretch
		tr.Color = ColorSequence.new(Tempest.WATER_EDGE, Tempest.WATER)
		tr.LightEmission = 0.85
		tr.LightInfluence = 0
		tr.Brightness = 1.6
		tr.Lifetime = Style.TRAIL_LIFE
		tr.MinLength = 0.01
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		tr.WidthScale = NumberSequence.new(width)
		tr.Enabled = false
		tr.Parent = a0
		return tr
	end
	state.trails = {
		kunai = trail("TempestKunaiTrail", 0.42, Style.KUNAI_TIP, 1),
		katana = trail("TempestKatanaTrail", Style.KUNAI_TIP - 0.1, Style.KATANA_TIP, 1),
	}
	-- the extension sweep: water rings running out along the blade
	local sat = anchor(state, "TempestKatanaSweep", Style.KATANA_ROOT, 0, 0)
	local dir = state.toBody:VectorToWorldSpace(bl(1, 0, 0))
	sat.CFrame = CFrame.lookAt(sat.Position, sat.Position + dir)
	local rings = emitter(sat, "TempestKatanaSweepRings", VFX.MOD_RING)
	rings.Color = ColorSequence.new(Tempest.WATER)
	rings.LightEmission = 0.7
	rings.Brightness = 1.2
	rings.Lifetime = NumberRange.new(0.14)
	rings.Speed = NumberRange.new(0.02)
	rings.EmissionDirection = Enum.NormalId.Front
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.Size = NumberSequence.new(0.2 * scale)
	rings.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	state.sweep = { at = sat, rings = rings }
	-- droplets: the retract shatter, the ring twirl, the catch
	local burstAt = anchor(state, "TempestKatanaBurst", 1.4, 0, 0)
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
	-- the heavy's crescent: a wide flash and arcs thrown from the blade
	local cat = anchor(state, "TempestCleave", 1.3, 0, 0)
	local flash = emitter(cat, "TempestCleaveFlash", VFX.TEMPEST_SPLASH_2x2)
	flash.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	flash.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	flash.Lifetime = NumberRange.new(0.18)
	flash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8 * scale),
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
	arcs.Size = NumberSequence.new(0.6 * scale)
	arcs.LockedToPart = false
	state.cleave = { flash = flash, arcs = arcs, at = cat }
	-- the blade's own light
	local la = anchor(state, "TempestKatanaLight", 1.3, 0, 0.05)
	local light = Instance.new("PointLight")
	light.Color = Tempest.WATER
	light.Brightness = 0
	light.Range = 2.2 * scale
	light.Shadows = false
	light.Parent = la
	state.light = light
	TempestKunai.apply(state, 0)
	return state
end

-- Show the blade at extension `e` (0 kunai .. 1 katana): slid back into the
-- kunai and faded out, or out and clear.
function TempestKunai.apply(state: State, e: number)
	local k = math.clamp(e, 0, 1)
	for _, p in state.blade do
		p.Transparency = 1 - (1 - state.bladeRest[p]) * k
	end
	for _, sh in state.shells do
		sh.Transparency = 1 - Style.SKIN_OPACITY * k
	end
	if state.katana then
		state.katana.Transform = CFrame.new(-Style.RETRACT * (1 - k), 0, 0)
	end
end

-- Every frame. swingP: progress of the current melee move (nil when none);
-- heavy: it is the heavy; hit: its contact frame (0..1).
function TempestKunai.step(
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
	-- inspect toggles the form, mid-move
	local prev = state.inspectPrev or 0
	if inspectP then
		if inspectP < prev then
			prev = 0
		end
		if prev < Style.TOGGLE_AT and inspectP >= Style.TOGGLE_AT then
			state.extended = not state.extended
			if state.extended then
				cue(state, "katanaOut")
			else
				state.burstAt.Position = state.toBody:PointToWorldSpace(bl(1.4, 0, 0) * state.scale)
				state.burst:Emit(if reduced then 8 else 22)
				cue(state, "katanaIn")
			end
		end
	end
	state.inspectPrev = inspectP
	-- the draw: the ring twirls, water spins off it; the katana (if out) runs out after
	local twirl = 0
	if drawP then
		if state.drawPrev == nil then
			state.burstAt.Position = state.toBody:PointToWorldSpace(bl(-0.39, 0, 0) * state.scale)
			state.burst:Emit(if reduced then 4 else 10)
			cue(state, "draw")
		end
		twirl = Style.RING_TURNS * 360 * smooth(0, 0.55, drawP)
	end
	state.drawPrev = drawP
	if state.ring then
		state.ring.Transform = CFrame.Angles(math.rad(twirl), 0, 0)
	end
	local goal = if state.extended then 1 else 0
	if drawP then
		goal *= smooth(0.35, 0.7, drawP)
	end
	local was = state.ext.x
	spring(state.ext, goal, Style.EXT_FREQ, Style.EXT_DAMP, s)
	local e = math.clamp(state.ext.x, 0, 1)
	TempestKunai.apply(state, if visible then e else 0)
	-- the sweep runs out to the tip as the blade extends
	local growing = state.ext.x > was + 1e-3 and e < 0.97 and visible and not reduced
	if growing then
		local x = Style.KATANA_ROOT + (Style.KATANA_TIP - Style.KATANA_ROOT) * e
		local p = state.toBody:PointToWorldSpace(bl(x, 0, 0) * state.scale)
		local d = state.toBody:VectorToWorldSpace(bl(1, 0, 0))
		state.sweep.at.CFrame = CFrame.lookAt(p, p + d)
	end
	state.sweep.rings.Rate = if growing then 90 else 0
	if state.sweep.rings.Enabled ~= growing then
		state.sweep.rings.Enabled = growing
	end
	-- heavy: the blade surges white while it winds up, then the crescent
	local surgeGoal = 0
	local sp = state.swingPrev or 0
	if swingP and heavy then
		local h = hit or 0.45
		surgeGoal = smooth(0, h * 0.8, swingP) * (1 - smooth(h, h + 0.15, swingP))
		if sp < h and swingP >= h then
			state.cleave.flash:Emit(1)
			if not reduced then
				state.cleave.arcs:Emit(4)
			end
			cue(state, "cleave")
		end
	end
	state.swingPrev = swingP
	state.surge += (surgeGoal - state.surge) * (1 - math.exp(-12 * s))
	-- trails while a move cuts
	local cutting = swingP ~= nil and swingP > 0.08 and swingP < 0.8 and visible
	if state.trails.kunai.Enabled ~= cutting then
		state.trails.kunai.Enabled = cutting
	end
	local katanaCut = cutting and e > 0.5
	if state.trails.katana.Enabled ~= katanaCut then
		state.trails.katana.Enabled = katanaCut
	end
	-- ribbons and light with the blade; brighter in the heavy's surge
	local ribbonOn = visible and e > 0.25
	for _, b in state.ribbons do
		b.Enabled = ribbonOn
		if ribbonOn then
			b.Brightness = Tempest.RIBBON_BRIGHTNESS * e * (1 + Style.SURGE_GAIN * state.surge)
			b.TextureSpeed = if reduced
				then 0
				else Tempest.RIBBON_SPEED * 1.4 * (1 + 2 * state.surge)
		end
	end
	state.light.Enabled = visible and e > 0.05
	state.light.Brightness = Style.LIGHT * e * (0.9 + 0.1 * math.sin(state.clock * 3))
		+ 1.2 * state.surge
	-- lightning: random flickers along the katana (constant in the heavy's surge);
	-- the compact kunai crackles at its crack instead
	local crackOn = visible and not reduced and e < 0.3
	if state.crack.Enabled ~= crackOn then
		state.crack.Enabled = crackOn
	end
	local boltOn = false
	if visible and not reduced and e > 0.5 then
		if state.clock >= state.nextArc or state.surge > 0.4 then
			state.arcUntil = state.clock + 0.05 + 0.04 * math.random()
			state.nextArc = state.clock
				+ Style.ARC_GAP[1]
				+ math.random() * (Style.ARC_GAP[2] - Style.ARC_GAP[1])
			for i, a in state.arcPoints do
				local x = Style.ARC_STATIONS[i]
				local j = Style.ARC_JITTER * state.scale
				a.Position = state.toBody:PointToWorldSpace(bl(x, 0, 0.02) * state.scale)
					+ Vector3.new(
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j
					)
			end
		end
		boltOn = state.clock < state.arcUntil
	end
	for _, b in state.arcs do
		if b.Enabled ~= boltOn then
			b.Enabled = boltOn
		end
	end
end

return TempestKunai
