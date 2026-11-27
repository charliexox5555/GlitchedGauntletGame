--!strict
-- The SURGE power pack opening (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26:
-- "instead of a case we will do like a card pack, and it rips open the card pack and looks cool"). Numbers in
-- Shared/Config/CaseOpening PACK. Client-side and cosmetic: the server has already rolled the powers
-- (Services/ShopService); this only shows them. Util/CaseOpening.start hands a pack tier (Config/Crates `pack`) here,
-- so it has the same API:
--
--   local h = PackOpening.start(owner, crateTier, isLocal, count) -- tossed out in front of the opener, floating
--   h:reveal(results, onDone)                                     -- shakes, rips, the cards
--   h:abort()                                                     -- refused: they fade away
--
-- In the world at the opener, like the crates (owner 2026-11-27: "I thought like we would see the pack open in the
-- world space like the crate"); nearby players see it through CaseShow, quieter, with the opener's name on the plate.
-- OPEN 3 tosses three packs out in a row facing the opener, like the crate batch (owner 2026-11-27: "options for
-- opening 3, similar to case openings layout"); they shake and rip on the same beat, built up to the best tier
-- among them, and the best one leads (its stinger, flash and kick).
-- Beats per pack: tossed out from the opener's chest, it floats and sways → shakes (the tier glow from the
-- second-to-last) → strains for TIER_FX.hold with the riser → coils back, then the top strip (Top_Seal) tears off
-- from its notch, hinging on its far end (the model's TopPivot attribute), sparks along the tear, and flies away →
-- the power card slides up out of the pack with its back to the opener, the empty pack sinks and fades, the card
-- rises and flips to its face with an overshoot pop in its tier glow: the stinger, sparks, a shine across its face,
-- a small name plate over it → twinkles while it holds → it arcs into the opener. No rings or halos behind the card
-- (owner 2026-11-27: "I dont really like the effects behind the card ... the circle thing we dont need that").
-- The pack is ReplicatedStorage.Crates.PowerPack (tools/studio/BuildPack.luau): anchored parts placed every frame.
-- Poses are in pack units (the template's studs); WORLD_SCALE turns them into world studs.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local PowerCardFace = require(script.Parent.PowerCardFace)

export type Result = { gun: string, line: string, tier: string, name: string, power: string? }
export type Handle = {
	reveal: (self: Handle, results: { Result }, onDone: (() -> ())?) -> boolean,
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}
-- the beat every pack of one opening follows, so they rip and flip together
type Timing = { shakes: number, hold: number }

local P = Cfg.PACK
local S = P.WORLD_SCALE
local PackOpening = {}

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local NOTCH_X, STRIP_Y = 0.85, 0.93 -- the tear runs from the notch (+X, the opener's left) to the hinge (TopPivot)
local CARD_HALF = 1.325 -- half the card's height at scale 1 (2.65 studs)
local TEXT = Color3.fromHex("F4F6F9")
local WARM = Color3.fromHex("FFF4E2")

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function quintOut(x: number): number
	local t = 1 - clamp01(x)
	return 1 - t * t * t * t * t
end
local function quadIn(x: number): number
	local t = clamp01(x)
	return t * t
end
local function backOut(x: number, k: number): number
	local t = clamp01(x) - 1
	return 1 + (k + 1) * t * t * t + k * t * t
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
-- a pose in pack units to world studs (its rotation stays)
local function scaled(cf: CFrame): CFrame
	return CFrame.new(cf.Position * S) * cf.Rotation
end

local function rootOf(p: Player): BasePart?
	local ch = p.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local warmed = false
local function warm()
	if warmed then
		return
	end
	warmed = true
	task.spawn(function()
		local list: { Instance } = {}
		local function add(spec: any)
			if typeof(spec) == "table" and typeof(spec.id) == "string" then
				local snd = Instance.new("Sound")
				snd.SoundId = spec.id
				table.insert(list, snd)
			end
		end
		add(P.Rip)
		add(Cfg.RISER)
		for _, key in { "Tease", "LidBoom", "Fly", "Toss", "Collect", "CollectSpark", "Swell" } do
			add((Cfg.SOUNDS :: any)[key])
		end
		for _, spec in Cfg.REVEAL do
			add(spec)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, inst in list do
			inst:Destroy()
		end
	end)
end

-- a short camera kick and FOV punch (the opener's own view only; as Util/CaseOpening)
local function kick(strength: number, fovPunch: number)
	local cam = workspace.CurrentCamera
	if not cam or strength <= 0 then
		return
	end
	local t0 = os.clock()
	local baseFov = cam.FieldOfView
	local name = "PackKick" .. tostring(t0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - t0
		local env = math.max(0, 1 - t / 0.35)
		if env <= 0 then
			RunService:UnbindFromRenderStep(name)
			cam.FieldOfView = baseFov
			return
		end
		local s = strength * env
		cam.CFrame = cam.CFrame
			* CFrame.new(math.sin(t * 61) * s * 0.6, math.sin(t * 47 + 1) * s * 0.4, 0)
			* CFrame.Angles(0, 0, math.rad(math.sin(t * 53) * 1.2 * env))
		cam.FieldOfView = baseFov - fovPunch * math.sin(math.min(t / 0.35, 1) * math.pi) * env
	end)
end

-- a quick full-screen flash in the tier colour (the opener's own view only)
local function flash(color: Color3, strength: number)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg or strength <= 0 then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "PackFlash"
	g:SetAttribute("LobbyGui", true) -- the match client never clears it (src/client init: armed-zone cleanup)
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None
	g.DisplayOrder = 5
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
	f.BorderSizePixel = 0
	f.Parent = g
	g.Parent = pg
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(g, 0.6)
end

local function part(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = parent
	return p
end

local function sparkEmitter(
	parent: Instance,
	color: Color3,
	speed: number,
	spread: number
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Vfx.SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09 * S),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.3, 0.65)
	e.Speed = NumberRange.new(speed * 0.5 * S, speed * S)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -7 * S, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Parent = parent
	return e
end

-- four-point stars twinkling around the shown card
local function twinkles(parent: Instance, color: Color3, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Vfx.MOD_SPARKLE
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.22 * S),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(0.15 * S, 0.5 * S)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 45)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = parent
	return e
end

-- a camera-facing image on `anchor` (the tier glow)
local function billboard(anchor: BasePart, image: string, size: number): (BillboardGui, ImageLabel)
	local g = Instance.new("BillboardGui")
	g.LightInfluence = 0
	g.Brightness = 2.4
	g.Size = UDim2.fromScale(size * S, size * S)
	g.MaxDistance = 120
	g.Adornee = anchor
	g.Parent = anchor
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageTransparency = 1
	img.Parent = g
	return g, img
end

-- the small name plate over the card (a billboard, so everyone nearby reads it): the tier word in its colour (the
-- opener's name first for everyone else) and the power's name, on a band that fades out to the sides (no box)
local function plate(
	anchor: BasePart,
	who: string?,
	name: string,
	tierName: string,
	color: Color3,
	k: number
)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PackPlate"
	bb.Size = UDim2.fromScale(P.PLATE_SIZE.X * S * k, P.PLATE_SIZE.Y * S * k)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = anchor
	bb.Parent = anchor
	local group = Instance.new("CanvasGroup")
	group.Name = "Plate"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = Color3.fromHex("06080C")
	group.BackgroundTransparency = 0.3
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Parent = bb
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = group
	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = group
	local function label(text: string, font: Font, c: Color3, y: number, h: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.86, h)
		l.FontFace = font
		l.TextScaled = true
		l.TextColor3 = c
		l.Text = text
		l.Parent = group
	end
	local top = string.upper(tierName) .. " POWER"
	if who then
		top = string.upper(who) .. "  ·  " .. top
	end
	label(top, BOLD, color, 0.1, 0.3)
	label(string.upper(name), HEAVY, TEXT, 0.42, 0.48)
	local info = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, info, { Scale = 1 }):Play()
end

local function walls(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

-- Where each pack floats: in front of the opener at chest-to-head height, facing them; several in a row across
-- their view (OPEN 3), farther out. Each is pulled in when a wall is in the way.
local function spots(root: BasePart, count: number): { CFrame }
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local look = if flat.Magnitude >= 0.1 then flat.Unit else -Vector3.zAxis
	local right = look:Cross(Vector3.yAxis).Unit
	local origin = root.Position + Vector3.yAxis * P.HOVER
	local distance = if count > 1 then P.BATCH_DISTANCE else P.DISTANCE
	local params = walls()
	local out: { CFrame } = {}
	for i = 1, count do
		local side = (i - (count + 1) / 2) * P.BATCH_SPREAD
		local want = origin + look * distance + right * side
		local dir = want - origin
		local reach = dir.Magnitude
		local hit = workspace:Raycast(origin, dir.Unit * (reach + 1.2 * S), params)
		local at = if hit
			then origin + dir.Unit * math.max(P.MIN_DISTANCE, hit.Distance - 1.2 * S)
			else want
		table.insert(out, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
	end
	return out
end

type Slot = {
	toss: (delay: number) -> boolean,
	sway: (t: number) -> (),
	open: (r: Result, timing: Timing, lead: boolean, flyDelay: number) -> boolean,
	fade: () -> (),
	step: () -> (),
	destroy: () -> (),
}

function PackOpening.start(
	owner: Player,
	crateTier: number,
	isLocal: boolean,
	count: number
): Handle?
	local ownerRoot = rootOf(owner)
	local template = CrateLook.template(crateTier)
	if not (ownerRoot and template and template:FindFirstChild("Top_Seal")) then
		return nil
	end
	warm()
	local tpl: Model = template
	local pivotAttr = tpl:GetAttribute("TopPivot")
	local hinge: Vector3 = if typeof(pivotAttr) == "Vector3"
		then pivotAttr
		else Vector3.new(-0.86, 0.93, 0)
	local gain = if isLocal then Cfg.LOCAL_VOLUME else Cfg.OTHERS_VOLUME
	local who = if isLocal then nil else owner.DisplayName
	count = math.clamp(count, 1, Cfg.MAX_CRATES)
	local batch = count > 1
	local cardK = if batch then P.BATCH_CARD else 1 -- the shown card's size against a lone pack's

	local folder = Instance.new("Folder")
	folder.Name = "PackOpening"
	folder.Parent = workspace

	local stopping = false
	local dead = false

	-- runs `step` with 0..1 every frame for `duration`; false when stopped
	local function run(duration: number, step: (a: number) -> ()): boolean
		local t0 = os.clock()
		while true do
			if stopping then
				return false
			end
			local a = if duration > 0 then (os.clock() - t0) / duration else 1
			step(math.min(a, 1))
			if a >= 1 then
				return true
			end
			RunService.RenderStepped:Wait()
		end
	end
	local function pause(seconds: number): boolean
		return run(seconds, function() end)
	end

	-- the opener's chest, in pack units in `stage` space (they may have moved)
	local function chest(stage: CFrame): Vector3
		local r = rootOf(owner)
		local at = if r then r.Position + Vector3.yAxis * 0.6 else stage.Position
		return stage:PointToObjectSpace(at) / S
	end

	local function makeSlot(stageCF: CFrame): Slot
		local box = Instance.new("Folder")
		box.Name = "Pack"
		box.Parent = folder
		local lightPart = part("PackLight", box)
		lightPart.CFrame = stageCF * CFrame.new(0.4 * S, 0.9 * S, -0.9 * S)
		local light = Instance.new("PointLight")
		light.Range = P.LIGHT_RANGE * S
		light.Brightness = 0.5
		light.Color = WARM
		light.Shadows = false
		light.Parent = lightPart
		local auraPart = part("PackAura", box)
		local auraGui, aura = billboard(auraPart, Vfx.GLOW, 2)
		local tearPart = part("PackTear", box)
		local burstPart = part("PackBurst", box)
		local platePart = part("PackPlate", box)

		-- sounds come from the pack (3D, like the crates'); `quiet` for the packs that don't lead
		local function sound(spec: any, volume: number?, pitchMult: number?)
			if typeof(spec) ~= "table" or typeof(spec.id) ~= "string" then
				return
			end
			local snd = Instance.new("Sound")
			snd.SoundId = spec.id
			snd.Volume = spec.volume * gain * (volume or 1)
			snd.PlaybackSpeed = spec.pitch * (pitchMult or 1)
			snd.RollOffMode = Enum.RollOffMode.InverseTapered
			snd.RollOffMinDistance = Cfg.ROLLOFF.X
			snd.RollOffMaxDistance = Cfg.ROLLOFF.Y
			if typeof(spec.start) == "number" and spec.start > 0 then
				snd.TimePosition = spec.start
			end
			snd.Parent = auraPart
			snd:Play()
			local cut = spec.cut
			if typeof(cut) == "number" then
				task.delay(cut, function()
					if snd.Parent then
						TweenService:Create(snd, TweenInfo.new(0.08), { Volume = 0 }):Play()
					end
				end)
			end
			Debris:AddItem(snd, 8)
		end

		-- poses, in pack units in stage space (the stage faces the opener: +X is their left, -Z toward them)
		local auraOffset = CFrame.new(0, 0, 0.6)
		local packPose = CFrame.new(0, -40, 0)
		local stripPose = CFrame.identity
		local cardPose: CFrame? = nil
		local tearAt = Vector3.zero

		local base: { [BasePart]: CFrame } = {}
		local strip: { BasePart } = {}
		local card: Model? = nil
		local labelGui: SurfaceGui? = nil
		local pack: Model? = tpl:Clone()
		do
			local m = pack :: Model
			m:ScaleTo(S)
			local root = m.PrimaryPart
			local origin = if root then root.CFrame else CFrame.identity
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					d.CastShadow = false
					base[d] = origin:ToObjectSpace(d.CFrame)
					if d.Name == "Top_Seal" then
						table.insert(strip, d)
					end
				elseif d:IsA("SurfaceGui") then
					labelGui = d
				end
			end
			m.Parent = box
		end

		local function setAura(color: Color3, size: number, transparency: number, time: number)
			aura.ImageColor3 = color
			local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			TweenService:Create(auraGui, info, { Size = UDim2.fromScale(size * S, size * S) })
				:Play()
			TweenService:Create(aura, info, { ImageTransparency = transparency }):Play()
		end

		-- the empty pack's parts fade (and its label goes) as it sinks
		local function fadePack(a: number)
			for p in base do
				if p.Name ~= "Root" then
					p.Transparency = a
				end
			end
			local g = labelGui
			if g then
				g.Enabled = a < 0.5
			end
		end

		local function step()
			auraPart.CFrame = stageCF * scaled(auraOffset)
			tearPart.CFrame = stageCF * scaled(packPose * CFrame.new(tearAt))
			local m = pack
			if m then
				local body = stageCF * scaled(packPose)
				local hingeCF = CFrame.new(hinge * S)
				local top = body * hingeCF * scaled(stripPose) * hingeCF:Inverse()
				for p, off in base do
					p.CFrame = (if p.Name == "Top_Seal" then top else body) * off
				end
			end
			local c = card
			local pose = cardPose
			if c and pose then
				local at = stageCF * scaled(pose)
				c:PivotTo(at)
				burstPart.CFrame = at
			end
		end

		local function toss(delay: number): boolean
			if delay > 0 and not pause(delay) then
				return false
			end
			sound(Cfg.SOUNDS.Toss, if batch then 0.6 else 1, 1.1)
			local from = chest(stageCF)
			local spin = math.rad(P.IN_SPIN)
			return run(P.IN_TIME, function(a)
				local e = quintOut(a)
				local pos = from:Lerp(Vector3.zero, e)
					+ Vector3.yAxis * math.sin(a * math.pi) * P.TOSS_ARC
				packPose = CFrame.new(pos) * CFrame.Angles(0, spin * (1 - e), 0)
			end)
		end

		local phase = math.random() * 6
		local function sway(t: number)
			local s = math.rad(P.SWAY)
			local u = t + phase
			packPose = CFrame.new(0, math.sin(u * 1.7) * 0.05, 0)
				* CFrame.Angles(
					math.sin(u * 1.1) * s * 0.4,
					math.sin(u * 1.4) * s,
					math.sin(u * 0.9) * s * 0.3
				)
		end

		local function open(r: Result, timing: Timing, lead: boolean, flyDelay: number): boolean
			local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
			local color = tier.color
			local fx = (Cfg.TIER_FX :: any)[r.tier] or Cfg.TIER_FX.Common
			local quiet = if lead then 1 else P.FOLLOW_VOLUME
			local power = r.power
			if power and Theme.CARD_ART[power] then
				task.spawn(function()
					local img = Instance.new("ImageLabel")
					img.Image = Theme.CARD_ART[power]
					pcall(ContentProvider.PreloadAsync, ContentProvider, { img })
					img:Destroy()
				end)
			end

			-- shakes: rolls that grow; the tier glow from the second-to-last
			for i = 1, timing.shakes do
				if i == math.max(1, timing.shakes - 1) then
					sound(Cfg.SOUNDS.Tease, quiet)
					setAura(color, P.AURA_TEASE, 0.3, 0.5)
				end
				sound(P.Crinkle, quiet, 0.92 + 0.07 * i)
				local amp = math.rad(P.SHAKE_ANGLES[math.min(i, #P.SHAKE_ANGLES)])
				if
					not run(P.SHAKE_EVERY, function(a)
						local env = (1 - a) * (1 - a)
						packPose = CFrame.new(
							0,
							math.sin(a * math.pi) * 0.08,
							-math.sin(a * math.pi) * 0.14
						) * CFrame.Angles(
							0,
							amp * 0.35 * math.sin(a * math.pi * 3) * env,
							amp * math.sin(a * math.pi * 5) * env
						)
					end)
				then
					return false
				end
			end
			-- the strain: trembling while the glow swells (the riser from the lead)
			if timing.hold > 0 then
				if lead then
					sound(Cfg.RISER)
				end
				setAura(color, P.AURA_HOLD, 0.12, timing.hold)
				light.Color = color
				local rng = Random.new()
				if
					not run(timing.hold, function(a)
						local s = math.rad(1.2 + 2.6 * a)
						packPose = CFrame.new(0, 0, -0.1 * a)
							* CFrame.Angles(0, rng:NextNumber(-s, s) * 0.4, rng:NextNumber(-s, s))
					end)
				then
					return false
				end
			end
			-- the coil: it pulls back and down before the rip snaps
			local coilFrom = packPose
			if
				not run(P.COIL, function(a)
					local e = quintOut(a)
					packPose = coilFrom
						* CFrame.new(0, -0.14 * e, 0.22 * e)
						* CFrame.Angles(math.rad(8) * e, 0, 0)
				end)
			then
				return false
			end

			-- the rip: the strip hinges up from the notch, sparks run along the tear
			sound(P.Rip, quiet)
			if isLocal and lead then
				kick(Cfg.CAMERA_KICK * fx.kick * 0.45, 0)
			end
			local tearSparks = sparkEmitter(tearPart, color, 5, 40)
			tearSparks.Rate = 60 + fx.sparks
			local lift = math.rad(P.RIP_LIFT)
			local coiled = packPose
			local ok = run(P.RIP_TIME, function(a)
				local e = a ^ 0.8
				packPose = coiled:Lerp(
					CFrame.new(0, -0.04, -0.06) * CFrame.Angles(0, 0, math.rad(-3)),
					quintOut(a)
				)
				stripPose = CFrame.Angles(math.rad(-14) * e, 0, lift * e)
				tearAt = Vector3.new(lerp(NOTCH_X, hinge.X, e), STRIP_Y, -0.05)
			end)
			tearSparks.Rate = 0
			if not ok then
				return false
			end
			tearSparks:Emit(math.floor(fx.sparks * 0.4))
			setAura(color, P.AURA_HOLD + 0.8, 0.05, 0.3)
			if
				not run(P.STRIP_FLY, function(a)
					local e = quintOut(a)
					stripPose = CFrame.new(-2.6 * e, 2.2 * e, -0.8 * e)
						* CFrame.Angles(math.rad(-14) - 2.2 * e, 0, lift + 3.4 * e)
					for _, p in strip do
						p.Transparency = clamp01((a - 0.6) / 0.4)
					end
				end)
			then
				return false
			end

			-- the card slides up out of the pack, its back to the opener
			local c = PowerCardFace.clone()
			local sweep: UIGradient? = nil
			if c then
				if power then
					PowerCardFace.fill(c, power, "NEW")
				end
				local _, sw = PowerCardFace.front(c)
				sweep = sw
				if sw then
					sw.Offset = Vector2.new(-1.3, 0)
				end
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
						d.CastShadow = false
					end
				end
				c:ScaleTo(P.CARD_SCALE * S)
				c.Parent = box
				card = c
			end
			local scale = P.CARD_SCALE
			local function setScale(want: number)
				if c and math.abs(want - scale) > 0.002 then
					scale = want
					c:ScaleTo(want * S)
				end
			end
			local back = CFrame.Angles(0, math.pi, 0)
			local from = packPose
			cardPose = from * CFrame.new(0, -0.05, 0.01) * back
			sound(Cfg.SOUNDS.Fly, quiet, 1.25)
			if
				not run(P.SLIDE_TIME, function(a)
					cardPose = from
						* CFrame.new(0, lerp(-0.05, P.SLIDE_UP, quintOut(a)), 0.01)
						* back
				end)
			then
				return false
			end

			-- the empty pack sinks and fades; the card rises, grows with an overshoot and flips to its face
			local slid = cardPose or CFrame.identity
			local burst = false
			local span = math.max(P.DROP_TIME, P.FLIP_TIME)
			local sparksOut = sparkEmitter(burstPart, color, 9, 180)
			sparksOut.Acceleration = Vector3.new(0, -4 * S, 0)
			local grow = P.CARD_GROW * cardK
			local target = Vector3.new(0, P.CARD_LIFT * cardK, -0.35)
			if
				not run(span, function(a)
					local t = a * span
					local d = quadIn(t / P.DROP_TIME)
					packPose = from
						* CFrame.new(0, -P.PACK_SINK * d, 0.3 * d)
						* CFrame.Angles(math.rad(-25) * d, 0, 0)
					fadePack(d)
					local f = clamp01(t / P.FLIP_TIME)
					local e = quintOut(f)
					local yaw = math.pi * backOut(f, 1.3)
					local pos = slid.Position:Lerp(target, e)
					cardPose = CFrame.new(pos) * CFrame.Angles(0, math.pi + yaw, 0)
					setScale(lerp(P.CARD_SCALE, grow, backOut(f, P.POP)))
					if not burst and f >= 0.45 then
						burst = true
						if lead then
							sound((Cfg.REVEAL :: any)[r.tier] or Cfg.REVEAL.Common)
							sound(Cfg.SOUNDS.LidBoom, 0.8)
							for _, spec in fx.extra do
								sound(spec)
							end
							if isLocal then
								flash(color, fx.flash)
								kick(Cfg.CAMERA_KICK * fx.kick, Cfg.FOV_PUNCH * fx.kick)
							end
						else
							sound(Cfg.SOUNDS.Swell, 0.8)
						end
						sparksOut:Emit(fx.sparks)
						light.Color = color
						light.Brightness = 0.9
						auraOffset = CFrame.new(0, target.Y, 0.7)
						setAura(color, (P.AURA_BURST + 0.6 * tier.order) * cardK, 0, 0.4)
						-- one shine across the card's face
						local sw = sweep
						if sw then
							task.delay(0.12, function()
								TweenService:Create(
									sw,
									TweenInfo.new(
										0.7,
										Enum.EasingStyle.Quad,
										Enum.EasingDirection.InOut
									),
									{ Offset = Vector2.new(1.3, 0) }
								):Play()
							end)
						end
						platePart.CFrame = stageCF
							* scaled(
								CFrame.new(
									0,
									target.Y + CARD_HALF * grow + P.PLATE_UP * cardK,
									-0.4
								)
							)
						plate(platePart, who, r.name, tier.name, color, cardK)
					end
				end)
			then
				return false
			end
			local m = pack
			if m then
				m:Destroy()
				pack = nil
			end

			-- the hold: a slow sway in the glow, stars twinkling round it
			local rest = cardPose or CFrame.identity
			local twinkle = twinkles(burstPart, color, P.TWINKLES + 3 * tier.order)
			burstPart.Size = Vector3.new(2.2, 2.7, 0.3) * S * grow
			local hold = P.HOLD + flyDelay
			if
				not run(hold, function(a)
					local t = a * hold
					cardPose = rest
						* CFrame.new(0, math.sin(t * 1.6) * 0.035, 0)
						* CFrame.Angles(math.sin(t * 1.2) * 0.03, math.sin(t * 0.9) * 0.12, 0)
				end)
			then
				return false
			end
			twinkle.Rate = 0

			-- it arcs into the opener, spinning and shrinking
			local held = cardPose or CFrame.identity
			local plateGui = platePart:FindFirstChild("PackPlate")
			local group = plateGui and plateGui:FindFirstChild("Plate")
			if group and group:IsA("CanvasGroup") then
				TweenService:Create(
					group,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						GroupTransparency = 1,
					}
				):Play()
			end
			-- the plate goes with the card (it must not hang in the air while the card flies off)
			if plateGui then
				Debris:AddItem(plateGui, 0.2)
			end
			local outInfo =
				TweenInfo.new(P.OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(aura, outInfo, { ImageTransparency = 1 }):Play()
			sound(Cfg.SOUNDS.Fly, quiet)
			local spin = math.rad(Cfg.FLY_SPIN)
			local ok2 = run(P.OUT_TIME, function(a)
				local e = quadIn(a)
				local pos = held.Position:Lerp(chest(stageCF), e)
					+ Vector3.yAxis * math.sin(a * math.pi) * P.FLY_ARC
				cardPose = CFrame.new(pos) * held.Rotation * CFrame.Angles(0, spin * e, 0)
				setScale(lerp(grow, grow * 0.2, e))
			end)
			if ok2 then
				sound(Cfg.SOUNDS.Collect, 0.8 * quiet)
				sound(Cfg.SOUNDS.CollectSpark, quiet)
			end
			if c then
				c:Destroy()
			end
			card, cardPose = nil, nil
			if plateGui then
				plateGui:Destroy()
			end
			light.Enabled = false
			return ok2
		end

		-- refused, or no power for it: it sinks and fades
		local function fade()
			local from = packPose
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.4 and not dead do
					local a = (os.clock() - t0) / 0.4
					packPose = from * CFrame.new(0, -P.PACK_SINK * quadIn(a), 0)
					fadePack(a)
					RunService.RenderStepped:Wait()
				end
			end)
		end

		local function destroy()
			box:Destroy()
		end

		return { toss = toss, sway = sway, open = open, fade = fade, step = step, destroy = destroy }
	end

	local slots: { Slot } = {}
	for _, cf in spots(ownerRoot, count) do
		table.insert(slots, makeSlot(cf))
	end

	local renderName = "PackOpening" .. tostring(os.clock()) .. owner.Name
	RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
		for _, slot in slots do
			slot.step()
		end
	end)

	local queued: { Result }? = nil
	local finished: (() -> ())? = nil

	local function cleanup()
		if dead then
			return
		end
		dead = true
		RunService:UnbindFromRenderStep(renderName)
		folder:Destroy()
	end

	-- toss them out one after another, centre first
	local order: { number } = {}
	for i = 1, #slots do
		table.insert(order, i)
	end
	table.sort(order, function(a, b)
		local mid = (#slots + 1) / 2
		return math.abs(a - mid) < math.abs(b - mid)
	end)

	task.spawn(function()
		for k, i in order do
			task.spawn(function()
				slots[i].toss((k - 1) * P.TOSS_STAGGER)
			end)
		end
		local t0 = os.clock()
		while not queued do
			if stopping then
				return
			end
			local t = os.clock() - t0
			if t > Cfg.WAIT_LIMIT then
				stopping = true
				break
			end
			if t > P.IN_TIME + P.TOSS_STAGGER * (#slots - 1) then
				for _, slot in slots do
					slot.sway(t)
				end
			end
			RunService.RenderStepped:Wait()
		end
		local list = queued
		if not list or stopping then
			if not dead then
				cleanup()
			end
			return
		end
		-- let the last toss land, then every pack follows the best tier's build-up
		pause(math.max(0, P.IN_TIME + P.TOSS_STAGGER * (#slots - 1) - (os.clock() - t0)))
		local timing: Timing = { shakes = Cfg.SHAKES, hold = 0 }
		local lead, best = 1, 0
		local shown = math.min(#slots, #list)
		for i = 1, shown do
			local id = list[i].tier
			local tier = Skins.TIERS[id :: any] or Skins.TIERS.Common
			local fx = (Cfg.TIER_FX :: any)[id] or Cfg.TIER_FX.Common
			timing.shakes = math.max(timing.shakes, (Cfg.TIER_SHAKES :: any)[id] or Cfg.SHAKES)
			timing.hold = math.max(timing.hold, fx.hold)
			if tier.order > best then
				lead, best = i, tier.order
			end
		end
		for i = shown + 1, #slots do
			slots[i].fade()
		end
		local remaining = shown
		for i = 1, shown do
			task.spawn(function()
				-- protected: one card that errors must not leave the opening waiting forever
				local ok, err =
					pcall(slots[i].open, list[i], timing, i == lead, (i - 1) * P.FLY_STAGGER)
				if not ok then
					warn(`[PackOpening] card {i} failed: {err}`)
				end
				remaining -= 1
			end)
		end
		while remaining > 0 and not stopping do
			RunService.RenderStepped:Wait()
		end
		if stopping then
			cleanup()
			return
		end
		cleanup()
		local done = finished
		finished = nil
		if done then
			done()
		end
	end)

	local function abort()
		if stopping or dead then
			return
		end
		stopping = true
		for _, slot in slots do
			slot.fade()
		end
		task.delay(0.45, cleanup)
	end

	local handle = {}
	function handle.reveal(_self: Handle, results: { Result }, onDone: (() -> ())?): boolean
		if stopping or dead or queued or #results == 0 then
			return false
		end
		finished = onDone
		queued = results
		return true
	end
	function handle.abort(_self: Handle)
		abort()
	end
	function handle.isDead(_self: Handle): boolean
		return dead
	end
	return handle :: any
end

return PackOpening
