--!strict
-- Collector Blind Box in-world opening (Strike Box & Overdrive Box).
-- Supports OPEN 1 and OPEN 3, syncing multiple boxes to the highest rolled tier.
-- Clones ReplicatedStorage.Crates.CharmBox, recolors roles from Config/Crates,
-- flips the hinged lid back, and reveals the actual 3D Charm gently swinging.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CharmsConfig = require(ReplicatedStorage.Shared.Config.Charms)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)

export type Result = {
	gun: string,
	line: string,
	tier: string,
	name: string,
	power: string?,
	charm: string?,
	copies: number?,
}

export type Handle = {
	reveal: (self: Handle, results: { Result }, onDone: (() -> ())?) -> boolean,
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}

type Timing = { shakes: number, hold: number }

local BlindBoxOpening = {}

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local TEXT_COLOR = Color3.fromHex("F4F6F9")
local CHARM_DISPLAY_SCALE = 5.2
local LID_PIVOT_DEFAULT = Vector3.new(0, 0.345, 0.59)

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function backOut(x: number, k: number?): number
	local c1 = k or 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function quintOut(x: number): number
	return 1 - (1 - x) ^ 5
end

local function timeScale(): number
	local v = StateValues.get(workspace, "CaseTimeScale")
	return if typeof(v) == "number" and v > 0 and v == v then math.clamp(v, 0.05, 10) else 1
end

local function rootOf(p: Player): BasePart?
	local ch = p.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function pause(dt: number, stopped: () -> boolean)
	local left = dt
	while left > 0 and not stopped() do
		left -= RunService.RenderStepped:Wait() * timeScale()
	end
end

local function playSound(spec: any, parent: Instance, gain: number): Sound?
	if not spec or gain <= 0 then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = spec.id
	s.Volume = spec.volume * gain
	s.PlaybackSpeed = spec.pitch or 1
	if spec.start then
		s.TimePosition = spec.start
	end
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, if spec.cut then spec.cut + 0.35 else 5)
	if spec.cut then
		task.delay(spec.cut, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(0.25), { Volume = 0 }):Play()
			end
		end)
	end
	return s
end

local audioWarmed = false
local function warmAudio()
	if audioWarmed then
		return
	end
	audioWarmed = true
	local list = {}
	for _, spec in Cfg.SOUNDS :: any do
		local s = Instance.new("Sound")
		s.SoundId = spec.id
		table.insert(list, s)
	end
	for _, spec in Cfg.REVEAL :: any do
		local s = Instance.new("Sound")
		s.SoundId = spec.id
		table.insert(list, s)
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, s in list do
			s:Destroy()
		end
	end)
end

local function cameraKick(strength: number, fovPunch: number)
	local cam = workspace.CurrentCamera
	if not cam or strength <= 0 then
		return
	end
	local baseFov = cam.FieldOfView
	local t0 = os.clock()
	local name = "CharmBoxKick_" .. tostring(t0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 5, function()
		local t = os.clock() - t0
		local env = math.max(0, 1 - t / 0.32)
		if env <= 0 then
			RunService:UnbindFromRenderStep(name)
			cam.FieldOfView = baseFov
			return
		end
		local s = strength * env
		cam.CFrame = cam.CFrame
			* CFrame.new(math.sin(t * 58) * s * 0.55, math.sin(t * 45 + 1) * s * 0.4, 0)
		cam.FieldOfView = baseFov - fovPunch * math.sin(math.min(t / 0.32, 1) * math.pi) * env
	end)
end

local function landingSpot(
	origin: Vector3,
	look: Vector3,
	params: RaycastParams,
	angleDeg: number,
	dist: number
): CFrame
	local dir = CFrame.Angles(0, math.rad(angleDeg), 0):VectorToWorldSpace(look)
	local target = origin + dir * dist
	local hit = workspace:Raycast(origin, target - origin, params)
	if hit then
		target = origin + dir * math.max(2.5, (hit.Position - origin).Magnitude - 1.2)
	end
	local down = workspace:Raycast(target + Vector3.yAxis * 4, -Vector3.yAxis * 14, params)
	local pos = if down and down.Normal.Y >= 0.7
		then down.Position + Vector3.yAxis * (0.82 * 1.25)
		else Vector3.new(target.X, origin.Y + 0.5, target.Z)
	return CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z))
end

local function sparkEmitter(parent: Instance, color: Color3, scale: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Vfx.SPARK
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.35, 0.72)
	e.Speed = NumberRange.new(4.5 * scale, 10.5 * scale)
	e.SpreadAngle = Vector2.new(55, 55)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -11 * scale, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Parent = parent
	return e
end

local function makeCardGui(
	anchor: BasePart,
	result: Result,
	tierColor: Color3,
	openerName: string?
): (BillboardGui, UIScale)
	local g = Instance.new("BillboardGui")
	g.Name = "CharmBoxNameplate"
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Size = UDim2.fromScale(5.6, 1.9)
	g.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	g.MaxDistance = 120
	g.AlwaysOnTop = false
	g.Adornee = anchor
	g.Parent = anchor

	local holder = Instance.new("Frame")
	holder.BackgroundColor3 = Color3.fromHex("121318")
	holder.BackgroundTransparency = 0.12
	holder.Size = UDim2.fromScale(1, 1)
	holder.BorderSizePixel = 0
	holder.Parent = g

	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.14, 0)
	corner.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = tierColor
	stroke.Thickness = 2.5
	stroke.Parent = holder

	local tierDef = (Skins.TIERS :: any)[result.tier] or Skins.TIERS.Common
	local copies = result.copies or 1
	local subText = if copies > 1
		then string.format("%s CHARM  ·  ×%d", tierDef.name, copies)
		else string.format("%s CHARM", tierDef.name)
	if openerName then
		subText = string.format("%s  ·  %s", string.upper(openerName), subText)
	end

	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Position = UDim2.fromScale(0.05, 0.12)
	kicker.Size = UDim2.fromScale(0.90, 0.28)
	kicker.FontFace = BOLD
	kicker.Text = subText
	kicker.TextScaled = true
	kicker.TextColor3 = tierColor
	kicker.Parent = holder

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.42)
	title.Size = UDim2.fromScale(0.90, 0.48)
	title.FontFace = HEAVY
	title.Text = result.name
	title.TextScaled = true
	title.TextColor3 = TEXT_COLOR
	title.Parent = holder

	return g, pop
end

type BoxSlot = {
	toss: (delayTime: number) -> (),
	sway: (t: number) -> (),
	open: (res: Result, timing: Timing, lead: boolean, flyDelay: number) -> (),
	fade: () -> (),
	cleanup: () -> (),
}

function BlindBoxOpening.start(
	owner: Player,
	crateTier: number,
	isLocal: boolean,
	count: number
): Handle?
	local ownerRoot = rootOf(owner)
	if not ownerRoot then
		return nil
	end
	local cratesFolder = ReplicatedStorage:FindFirstChild(Crates.FOLDER)
	local template = cratesFolder and cratesFolder:FindFirstChild("CharmBox")
	if not (template and template:IsA("Model")) then
		return nil
	end
	warmAudio()

	local tierDef = Crates.TIERS[crateTier] or Crates.TIERS[8]
	local scale = tierDef.scale or 1.25
	local gain = if isLocal then 1 else 0.42
	local reduced = UiMotion.reduced()
	local nCount = math.clamp(count, 1, Cfg.MAX_CRATES)
	local angles = if nCount == 1 then { 0 } elseif nCount == 2 then { -24, 24 } else { 0, 36, -36 }
	local dist = if nCount == 1 then 6.8 else 9.4

	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	local origin = ownerRoot.Position
	local flat = ownerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	local look = if flat.Magnitude >= 0.1 then flat.Unit else -Vector3.zAxis

	local container = Instance.new("Folder")
	container.Name = "CharmBoxOpening"
	container.Parent = workspace

	local stopping = false
	local dead = false
	local queued: { Result }? = nil
	local finished: (() -> ())? = nil
	local function isStopped()
		return stopping
	end

	local function createSlot(slotAngle: number): BoxSlot
		local landCf = landingSpot(origin, look, params, slotAngle, dist)
		local startPos = origin + look * 1.4 + Vector3.yAxis * 0.4
		local box = template:Clone()
		box.Name = "CharmBoxSlot"
		box:PivotTo(CFrame.new())
		box:ScaleTo(scale)

		local root = box.PrimaryPart :: BasePart
		local rootRestInv = root.CFrame:Inverse()
		local lidPivotVec = box:GetAttribute("LidPivot")
		local lidPivotLocal = (
			if typeof(lidPivotVec) == "Vector3" then lidPivotVec else LID_PIVOT_DEFAULT
		) * scale
		local lidPivotCf = CFrame.new(lidPivotLocal)
		local lidPivotInv = lidPivotCf:Inverse()

		local bodyParts: { { part: BasePart, rel: CFrame } } = {}
		local lidParts: { { part: BasePart, relFromPivot: CFrame } } = {}
		local glowParts: { BasePart } = {}

		local roles = tierDef.roles
		local boxTitle = if crateTier == 9 then "OVERDRIVE" else "STRIKE"

		for _, d in box:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = true
				if d ~= root then
					local name = d.Name
					if name == "Body_Box" or name == "Lid_Box" then
						d.Color = roles.Body.color
						d.Material = roles.Body.material
					elseif name == "Body_Trim" or name == "Lid_Trim" then
						d.Color = roles.Frame.color
						d.Material = roles.Frame.material
					elseif name == "Body_Glow" then
						d.Color = roles.Light.color
						d.Material = roles.Light.material
						table.insert(glowParts, d)
					elseif name == "Body_Interior" then
						d.Color = roles.Interior.color
						d.Material = roles.Interior.material
					elseif name == "Body_Label" then
						local artGui = d:FindFirstChild("Art")
						local back = artGui and artGui:FindFirstChild("Back")
						if back then
							local stroke = back:FindFirstChild("AccentBorder")
							if stroke and stroke:IsA("UIStroke") then
								stroke.Color = tierDef.accent
							end
							for _, child in back:GetChildren() do
								if
									child.Name == "Stripe1"
									or child.Name == "Stripe2"
									or child.Name == "Diamond"
								then
									if child:IsA("Frame") then
										child.BackgroundColor3 = tierDef.accent
									end
								end
							end
							local core = back:FindFirstChild("DiamondCore", true)
							if core and core:IsA("Frame") then
								core.BackgroundColor3 = tierDef.accent
							end
							local tl = back:FindFirstChild("TitleLabel")
							if tl and tl:IsA("TextLabel") then
								tl.Text = boxTitle
								tl.TextSize = if crateTier == 9 then 46 else 54
							end
							local sl = back:FindFirstChild("SubLabel")
							if sl and sl:IsA("TextLabel") then
								sl.TextColor3 = tierDef.accent
							end
						end
					end

					if string.sub(name, 1, 4) == "Lid_" then
						table.insert(lidParts, {
							part = d,
							relFromPivot = lidPivotInv * (rootRestInv * d.CFrame),
						})
					else
						table.insert(bodyParts, {
							part = d,
							rel = rootRestInv * d.CFrame,
						})
					end
				end
			end
		end

		box.Parent = container

		local fxPart = Instance.new("Part")
		fxPart.Name = "BoxFx"
		fxPart.Anchored = true
		fxPart.CanCollide, fxPart.CanQuery, fxPart.CanTouch = false, false, false
		fxPart.CastShadow = false
		fxPart.Transparency = 1
		fxPart.Size = Vector3.new(0.2, 0.2, 0.2)
		fxPart.CFrame = landCf
		fxPart.Parent = container

		local light = Instance.new("PointLight")
		light.Color = tierDef.accent
		light.Range = 9
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = fxPart

		local sparks = sparkEmitter(fxPart, tierDef.accent, scale)
		local landed = false
		local shownCharm: Model? = nil
		local charmParts: { { part: BasePart, rel: CFrame } } = {}
		local cardAnchor: BasePart? = nil

		local function placeBox(boxCf: CFrame, lidDeg: number, scaleMult: number?)
			local s = scaleMult or 1
			root.CFrame = boxCf
			for _, bp in bodyParts do
				bp.part.CFrame = boxCf * CFrame.new(bp.rel.Position * s) * bp.rel.Rotation
			end
			local hingeCf = boxCf
				* CFrame.new(lidPivotLocal * s)
				* CFrame.Angles(math.rad(lidDeg), 0, 0)
			for _, lp in lidParts do
				lp.part.CFrame = hingeCf
					* CFrame.new(lp.relFromPivot.Position * s)
					* lp.relFromPivot.Rotation
			end
		end

		placeBox(CFrame.new(startPos), 0)

		local function toss(delayTime: number)
			if delayTime > 0 then
				pause(delayTime, isStopped)
			end
			if isStopped() then
				return
			end
			playSound(Cfg.SOUNDS.Toss, fxPart, gain)
			local t0 = os.clock()
			local dur = 0.62
			while not isStopped() do
				local u = clamp01((os.clock() - t0) * timeScale() / dur)
				local pos = startPos:Lerp(landCf.Position, u)
					+ Vector3.yAxis
						* (math.sin(u * math.pi) * 2.4 + math.abs(math.sin(u * math.pi * 2)) * 0.25 * (1 - u))
				local yawTurn = CFrame.Angles(0, math.rad((1 - u) * 75), 0)
				local cf = CFrame.new(pos) * landCf.Rotation * yawTurn
				placeBox(cf, 0)
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if not isStopped() then
				placeBox(landCf, 0)
				playSound(Cfg.SOUNDS.Land, fxPart, gain)
				landed = true
			end
		end

		local function sway(t: number)
			if not landed or isStopped() then
				return
			end
			local rock = math.sin(t * 4.5 + slotAngle) * 2.5
			placeBox(landCf * CFrame.Angles(0, 0, math.rad(rock)), 0)
		end

		local function openBox(res: Result, timing: Timing, lead: boolean, flyDelay: number)
			local tier = (Skins.TIERS :: any)[res.tier] or Skins.TIERS.Common
			local tierColor = tier.color
			local fx = (Cfg.TIER_FX :: any)[res.tier] or Cfg.TIER_FX.Common

			-- Phase 1: playful hops + alternating tilt, teasing rolled rarity on final 2 hops
			local hops = timing.shakes
			for h = 1, hops do
				if isStopped() then
					return
				end
				local dir = if h % 2 == 1 then 1 else -1
				local tiltDeg = 8 + h * 1.8
				local hopH = 0.26 + h * 0.05
				if h >= hops - 1 then
					for _, gp in glowParts do
						gp.Color = tierColor
					end
					light.Color = tierColor
					light.Brightness = 1.4
					sparks.Color = ColorSequence.new(tierColor:Lerp(Color3.new(1, 1, 1), 0.3))
					sparks:Emit(6)
					if lead then
						playSound(Cfg.SOUNDS.Tease, fxPart, gain)
					end
				end
				if lead then
					playSound(Cfg.SOUNDS.Knock, fxPart, gain)
					playSound(Cfg.SOUNDS.Rattle, fxPart, gain * 0.7)
				end

				local t0 = os.clock()
				local hopDur = 0.34
				while not isStopped() do
					local u = clamp01((os.clock() - t0) * timeScale() / hopDur)
					local arc = math.sin(u * math.pi)
					local tilt = dir * tiltDeg * arc
					placeBox(
						landCf * CFrame.new(0, hopH * arc, 0) * CFrame.Angles(0, 0, math.rad(tilt)),
						0
					)
					if u >= 1 then
						break
					end
					RunService.RenderStepped:Wait()
				end
				pause(0.10, isStopped)
			end

			if isStopped() then
				return
			end

			-- Phase 2: squat anticipation & lid flip burst
			local holdTime = 0.26 + timing.hold * 0.6
			if lead then
				playSound(Cfg.SOUNDS.Strain, fxPart, gain)
			end
			local squatStart = os.clock()
			while not isStopped() do
				local u = clamp01((os.clock() - squatStart) * timeScale() / holdTime)
				local vib = math.sin(u * 48) * 1.6 * u
				placeBox(
					landCf * CFrame.new(0, -0.10 * u, 0) * CFrame.Angles(0, math.rad(vib), 0),
					6 * u
				)
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if isStopped() then
				return
			end

			-- Lid pops open + 3D charm emerges
			fxPart.CFrame = landCf * CFrame.new(0, 0.55 * scale, 0)
			sparks.Color = ColorSequence.new(tierColor:Lerp(Color3.new(1, 1, 1), 0.35))
			sparks:Emit(math.max(24, fx.sparks))
			light.Color = tierColor
			light.Brightness = 2.6

			if lead then
				playSound(Cfg.SOUNDS.Lid, fxPart, gain)
				playSound(Cfg.SOUNDS.Burst, fxPart, gain)
				playSound((Cfg.REVEAL :: any)[res.tier] or Cfg.REVEAL.Common, fxPart, gain)
				if isLocal and not reduced then
					cameraKick(Cfg.CAMERA_KICK * fx.kick * 0.75, Cfg.FOV_PUNCH * fx.kick * 0.7)
				end
			end

			-- Spawn scaled 3D charm inside the box cavity
			local charmTemplate = if res.charm then CharmsConfig.model(res.charm) else nil
			local charmPivotCfRest = landCf * CFrame.new(0, -0.15 * scale, 0)
			local charmRiseTop = landCf * CFrame.new(0, 2.35 * scale, 0)
			if charmTemplate then
				local mc = charmTemplate:Clone()
				mc.Name = "RevealedCharm"
				mc:PivotTo(CFrame.new())
				mc:ScaleTo(CHARM_DISPLAY_SCALE)
				local p0 = mc.PrimaryPart
				if p0 then
					local p0Inv = p0.CFrame:Inverse()
					for _, d in mc:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
							d.CanQuery = false
							d.CanTouch = false
							d.CastShadow = false
							if d ~= p0 then
								table.insert(charmParts, { part = d, rel = p0Inv * d.CFrame })
							end
						end
					end
					table.insert(charmParts, 1, { part = p0, rel = CFrame.new() })
				end
				mc.Parent = container
				shownCharm = mc
			end

			cardAnchor = Instance.new("Part")
			local anchor = cardAnchor :: BasePart
			anchor.Name = "NameAnchor"
			anchor.Anchored = true
			anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.CFrame = charmRiseTop
			anchor.Parent = container

			local openerName = if isLocal then nil else owner.DisplayName
			local cardGui, cardPop = makeCardGui(anchor, res, tierColor, openerName)
			TweenService:Create(
				cardPop,
				TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()

			local function placeCharm(cf: CFrame)
				if not shownCharm or #charmParts == 0 then
					return
				end
				charmParts[1].part.CFrame = cf
				for i = 2, #charmParts do
					charmParts[i].part.CFrame = cf * charmParts[i].rel
				end
			end

			-- Animate lid flip + charm rise + swinging hold
			local lidDur = 0.24
			local riseDur = 0.72
			local holdDur = 2.75
			local totalShow = riseDur + holdDur
			local revealStart = os.clock()
			while not isStopped() do
				local elapsed = (os.clock() - revealStart) * timeScale()
				local lidU = clamp01(elapsed / lidDur)
				local lidAngle = 118 * backOut(lidU, 1.35)
				local boxBounceY = math.sin(clamp01(elapsed / 0.28) * math.pi) * 0.18
				placeBox(landCf * CFrame.new(0, boxBounceY, 0), lidAngle)

				local riseU = quintOut(clamp01(elapsed / riseDur))
				local pos = charmPivotCfRest.Position:Lerp(charmRiseTop.Position, riseU)
				local swingPitch = math.sin(elapsed * 4.4) * math.rad(14)
				local swingRoll = math.cos(elapsed * 3.1) * math.rad(9)
				local rotY = math.rad(elapsed * 72)
				local bob = math.sin(elapsed * 2.5) * 0.11 * riseU
				local charmCf = CFrame.new(pos + Vector3.new(0, bob, 0))
					* landCf.Rotation
					* CFrame.Angles(0, rotY, 0)
					* CFrame.Angles(swingPitch, 0, swingRoll)
				placeCharm(charmCf)
				anchor.CFrame = CFrame.new(pos + Vector3.new(0, bob + 0.15, 0))

				if elapsed >= totalShow then
					break
				end
				RunService.RenderStepped:Wait()
			end

			if isStopped() then
				return
			end

			if flyDelay > 0 then
				pause(flyDelay, isStopped)
			end

			-- Hide card and fly charm smoothly into opener while shrinking box away
			TweenService:Create(
				cardPop,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Scale = 0 }
			):Play()
			playSound(Cfg.SOUNDS.Fly, fxPart, gain)

			local flyFromPos = if #charmParts > 0
				then charmParts[1].part.Position
				else charmRiseTop.Position
			local flyDur = 0.65
			local flyStart = os.clock()
			while not isStopped() do
				local u = clamp01((os.clock() - flyStart) * timeScale() / flyDur)
				local sinkScale = math.max(0.02, 1 - u * 0.98)
				placeBox(landCf * CFrame.new(0, -1.6 * u, 0), 118, sinkScale)
				for _, bp in bodyParts do
					bp.part.Transparency = math.max(bp.part.Transparency, u)
				end
				for _, lp in lidParts do
					lp.part.Transparency = math.max(lp.part.Transparency, u)
				end

				local targetPos = (ownerRoot and ownerRoot.Position or origin) + Vector3.yAxis * 0.8
				local pos = flyFromPos:Lerp(targetPos, u * u)
					+ Vector3.yAxis * (math.sin(u * math.pi) * 2.2)
				local flyCf = CFrame.new(pos) * CFrame.Angles(0, u * math.pi * 4, 0)
				placeCharm(flyCf)
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end

			if cardGui.Parent then
				cardGui:Destroy()
			end
			if lead and not isStopped() then
				playSound(Cfg.SOUNDS.Collect, ownerRoot or fxPart, gain)
			end
		end

		local function fade()
			box:Destroy()
			if shownCharm then
				shownCharm:Destroy()
			end
			if cardAnchor then
				cardAnchor:Destroy()
			end
			fxPart:Destroy()
		end

		local function cleanup()
			fade()
		end

		return {
			toss = toss,
			sway = sway,
			open = openBox,
			fade = fade,
			cleanup = cleanup,
		}
	end

	local slots: { BoxSlot } = {}
	for _, a in angles do
		table.insert(slots, createSlot(a))
	end

	local function cleanupAll()
		if dead then
			return
		end
		dead = true
		for _, s in slots do
			s.cleanup()
		end
		container:Destroy()
	end

	-- Toss center-first, then wait for server answer and open synchronized to highest rarity.
	local order: { number } = {}
	for i = 1, #slots do
		table.insert(order, i)
	end
	table.sort(order, function(a, b)
		local mid = (#slots + 1) / 2
		return math.abs(a - mid) < math.abs(b - mid)
	end)

	task.spawn(function()
		for k, idx in order do
			task.spawn(function()
				slots[idx].toss((k - 1) * 0.12)
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
			if t > 0.65 + 0.12 * (#slots - 1) then
				for _, s in slots do
					s.sway(t)
				end
			end
			RunService.RenderStepped:Wait()
		end

		local list = queued
		if not list or stopping then
			cleanupAll()
			return
		end

		pause(math.max(0, 0.72 + 0.12 * (#slots - 1) - (os.clock() - t0)), isStopped)

		local timing: Timing = { shakes = Cfg.SHAKES, hold = 0 }
		local lead, best = 1, 0
		local shown = math.min(#slots, #list)
		for i = 1, shown do
			local id = list[i].tier
			local tdef = (Skins.TIERS :: any)[id] or Skins.TIERS.Common
			local fx = (Cfg.TIER_FX :: any)[id] or Cfg.TIER_FX.Common
			timing.shakes = math.max(timing.shakes, (Cfg.TIER_SHAKES :: any)[id] or Cfg.SHAKES)
			timing.hold = math.max(timing.hold, fx.hold)
			if tdef.order > best then
				lead, best = i, tdef.order
			end
		end
		for i = shown + 1, #slots do
			slots[i].fade()
		end

		local remaining = shown
		for i = 1, shown do
			task.spawn(function()
				local ok, err = pcall(slots[i].open, list[i], timing, i == lead, (i - 1) * 0.08)
				if not ok then
					warn(`[BlindBoxOpening] box {i} failed: {err}`)
				end
				remaining -= 1
			end)
		end
		while remaining > 0 and not stopping do
			RunService.RenderStepped:Wait()
		end
		cleanupAll()
		local done = finished
		finished = nil
		if done then
			done()
		end
	end)

	local handle: Handle = {
		reveal = function(_self: Handle, results: { Result }, onDone: (() -> ())?): boolean
			if stopping or dead or queued or #results == 0 then
				return false
			end
			finished = onDone
			queued = results
			return true
		end,
		abort = function(_self: Handle)
			if stopping or dead then
				return
			end
			stopping = true
			cleanupAll()
		end,
		isDead = function(_self: Handle): boolean
			return dead
		end,
	}
	return handle
end

return BlindBoxOpening
