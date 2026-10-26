--!strict
-- World effects of Mods for everyone (ModFx events from ModService), coloured
-- per viewer (Util/TeamColor): cyan for you and your team, orange-red for
-- enemies. Cosmetic only: the server already decided every result. Shapes
-- come from Util/ModVfx (pooled, stylized textures: rings, scans, hexes,
-- chevrons, sparkles), held / thrown models from Util/ModProps.
--
--   PacketThrow  the grenade flying its server path (Blocks/Projectile replay),
--                fuse blink, and a danger ring where it will go off
--   PacketBoom   flash sphere + shockwave ring, camera shake nearby
--   Heal         a beam from the healer to the ally, +HP over the target
--   LagThrow / LagZone   the orb's flight, then the slowing dome
--   PingPulse    an expanding scan sphere (everyone sees it)
--   Overclock    the caster's gun glows (a screen-edge glow for the caster)
--   Placed / ObjectGone  a pop when a Mod object goes up / breaks or expires
-- Also: ModReveal (sent to your team only) outlines revealed enemies through
-- walls; Mod objects in workspace.ModObjects are coloured per viewer and
-- flash when hit; a Rollback ghost trail follows anyone whose Rollback is
-- ready; your own Rollback plays a "VHS rewind" wash; anyone a Lag Field is
-- slowing shows SLOWED.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)
local Tex = require(Shared.Config.VfxTextures)

local ModProps = require(script.Parent.Parent.Util.ModProps)
local ModVfx = require(script.Parent.Parent.Util.ModVfx)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local VfxPool = require(script.Parent.Parent.Util.VfxPool)
local CameraController = require(script.Parent.CameraController)

local ModFxController = {}

local player = Players.LocalPlayer

type Flight = {
	blink: boolean, -- Packet's fuse blink
	model: Model,
	glow: { BasePart },
	path: Projectile.Path,
	start: number,
	fuse: number,
	color: Color3,
	key: string,
}

type Beam = {
	part: Part,
	from: Model,
	to: Model,
	born: number,
	duration: number,
}

type Floater = { gui: BillboardGui, label: TextLabel, born: number }

local FLOATER_TIME = 1.1

local folder: Folder? = nil
local lastRollback = 0
local flights: { Flight } = {}
local beams: { Beam } = {}
local floaters: { Floater } = {}
local grenadeFree: { [string]: { Model } } = {}
-- Lag Field orbs spinning in the middle of their zone.
type Orb = { model: Model, key: string, at: Vector3, untilT: number }
local orbs: { Orb } = {}
local partPool: VfxPool.Pool<Part>? = nil
local floaterFree: { Floater } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ModFx"
	made.Parent = Workspace
	folder = made
	partPool = nil
	table.clear(grenadeFree)
	return made
end

local function parts(): VfxPool.Pool<Part>
	local pool = partPool
	if pool then
		return pool
	end
	local made = VfxPool.new(function(): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = fxFolder()
		return p
	end, fxFolder(), 8)
	partPool = made
	return made
end

local function takePart(shape: Enum.PartType, color: Color3): Part
	local p = parts():acquire()
	p.Shape = shape
	p.Color = color
	p.Material = Enum.Material.Neon -- pooled parts may come back as ForceField
	return p
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

-- A dashed, slowly turning ring on the ground where something will go off.
local function dangerRing(at: Vector3, radius: number, color: Color3, life: number)
	ModVfx.quad({
		texture = Tex.MOD_RING_DASHED,
		cframe = CFrame.new(at - Vector3.new(0, 0.35, 0)),
		from = radius * 2,
		color = color,
		life = life,
		alpha0 = 0.15,
		hold = true,
		spin = 0.8,
		pulse = 0.25,
	})
end

-- Packet ----------------------------------------------------------------------------

local function takeGrenade(id: string, color: Color3): (Model?, string)
	local key = id .. color:ToHex()
	local free = grenadeFree[key]
	local model = free and table.remove(free)
	if not model then
		local template = ModProps.get(id, color)
		if not template then
			return nil, key
		end
		model = template:Clone()
	end
	(model :: Model).Parent = fxFolder()
	return model, key
end

local function onPacketThrow(data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start, fuse, radius = data.start, data.fuse, data.radius
	if
		not path
		or typeof(start) ~= "number"
		or typeof(fuse) ~= "number"
		or typeof(radius) ~= "number"
	then
		return
	end
	local color = TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	if data.caster == player then
		color = TeamColor.ALLY
	end
	local model, key = takeGrenade("Packet", color)
	if not model then
		return
	end
	local glow = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(glow, d)
		end
	end
	-- Danger ring where it will go off.
	local left = math.max(fuse - (Workspace:GetServerTimeNow() - start), 0.1)
	dangerRing(Projectile.positionAt(path, fuse), radius, color, left)
	table.insert(flights, {
		blink = true,
		model = model,
		glow = glow,
		path = path,
		start = start,
		fuse = fuse,
		color = color,
		key = key,
	})
end

local function onPacketBoom(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local color = if data.caster == player
		then TeamColor.ALLY
		else TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	local d = radius * 2
	-- A hot core, a shockwave ring racing out along the ground, a glow and
	-- a spray of sparks.
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at),
		from = Vector3.one * 2,
		to = Vector3.one * d * 0.85,
		color = color,
		life = 0.28,
		alpha0 = 0.1,
		material = Enum.Material.Neon,
	})
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at),
		from = Vector3.one * d * 0.6,
		to = Vector3.one * d * 1.1,
		color = color,
		life = 0.4,
		alpha0 = 0.8,
	})
	local shock = ModVfx.mesh({
		name = "Shockwave",
		cframe = CFrame.new(at - Vector3.new(0, 0.35, 0)),
		from = Vector3.new(2, 0.3, 2),
		to = Vector3.new(d * 1.5, 0.3, d * 1.5),
		color = color,
		life = 0.45,
		alpha0 = 0.1,
	})
	ModVfx.quad({
		texture = Tex.MOD_RING,
		cframe = CFrame.new(at - Vector3.new(0, 0.35, 0)),
		from = 2,
		to = d * 1.6,
		color = color,
		life = 0.5,
		alpha0 = if shock then 0.4 else 0,
	})
	ModVfx.quad({
		texture = Tex.MOD_GLOW,
		cframe = CFrame.new(at - Vector3.new(0, 0.3, 0)),
		from = d * 0.8,
		to = d * 1.2,
		color = color,
		life = 0.4,
		alpha0 = 0.2,
	})
	ModVfx.burst(at, color, 28, "Sparkle")
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius * 4 then
			CameraController.shake(1.2 * (1 - away / (radius * 4)))
		end
	end
end

-- Patch Up --------------------------------------------------------------------------

local function floater(target: Model, text: string, color: Color3)
	local head = target:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local f = table.remove(floaterFree)
	if not f then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 40)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace =
			Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
		label.TextSize = 26
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		f = { gui = gui, label = label, born = 0 }
	end
	local fl = f :: Floater
	fl.label.Text = text
	fl.label.TextColor3 = color
	fl.gui.Adornee = head
	fl.gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	fl.gui.Parent = player:FindFirstChild("PlayerGui")
	fl.born = os.clock()
	table.insert(floaters, fl)
end

local function onHeal(data: { [string]: any })
	local target, caster = data.target, data.caster
	local duration, amount = data.duration, data.amount
	if typeof(duration) ~= "number" or typeof(amount) ~= "number" then
		return
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return -- streamed out: nothing to draw on
	end
	local targetModel = target :: Model
	local friendly = data.caster == player
		or TeamColor.isFriendly(if typeof(data.team) == "number" then data.team else nil)
	local color = if friendly then TeamColor.ALLY else TeamColor.ENEMY
	local casterModel = if typeof(caster) == "Instance" and (caster :: Instance):IsA("Player")
		then (caster :: Player).Character
		else nil
	local targetRoot = rootOf(targetModel)
	if targetRoot then
		ModVfx.burst(targetRoot.Position, color, 12, "Cross")
		ModVfx.quad({
			texture = Tex.MOD_RING,
			cframe = CFrame.new(targetRoot.Position - Vector3.new(0, 2.9, 0)),
			from = 2,
			to = 6,
			color = color,
			life = 0.6,
			alpha0 = 0.2,
		})
	end
	if casterModel and casterModel ~= targetModel then
		local beam = takePart(Enum.PartType.Block, color)
		table.insert(beams, {
			part = beam,
			from = casterModel,
			to = targetModel,
			born = os.clock(),
			duration = math.max(duration, 0.4),
		})
	end
	if friendly then
		floater(targetModel, "+" .. tostring(math.round(amount)), color)
	end
end

local function teamColor(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

-- Lag Field --------------------------------------------------------------------------

local function onLagThrow(data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start, land, radius = data.start, data.land, data.radius
	if
		not path
		or typeof(start) ~= "number"
		or typeof(land) ~= "number"
		or typeof(radius) ~= "number"
	then
		return
	end
	local color = teamColor(data)
	local model, key = takeGrenade("LagField", color)
	if not model then
		return
	end
	-- Where the zone will open.
	local left = math.max(land - (Workspace:GetServerTimeNow() - start), 0.1)
	dangerRing(Projectile.positionAt(path, land), radius, color, left)
	table.insert(flights, {
		blink = false,
		model = model,
		glow = {},
		path = path,
		start = start,
		fuse = land,
		color = color,
		key = key,
	})
end

local function onLagZone(data: { [string]: any })
	local at, radius, duration = data.at, data.radius, data.duration
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" or typeof(duration) ~= "number" then
		return
	end
	local color = teamColor(data)
	local d = radius * 2
	local ground = CFrame.new(at - Vector3.new(0, 0.4, 0))
	-- A dome, a hex floor, a turning dashed rim, the orb spinning in the
	-- middle, and an opening ring + sparks.
	local dome = ModVfx.mesh({
		name = "Dome",
		cframe = CFrame.new(at - Vector3.new(0, 0.4, 0)),
		from = Vector3.new(d * 0.3, radius * 0.3, d * 0.3),
		to = Vector3.new(d, radius, d),
		color = color,
		life = duration,
		alpha0 = 0.8,
		hold = true,
	})
	if not dome then
		ModVfx.shell({
			shape = Enum.PartType.Ball,
			cframe = CFrame.new(at),
			from = Vector3.one * d,
			color = color,
			life = duration,
			alpha0 = 0.82,
			hold = true,
		})
	end
	local orb, key = takeGrenade("LagField", color)
	if orb then
		table.insert(orbs, {
			model = orb,
			key = key,
			at = at + Vector3.new(0, 0.6, 0),
			untilT = os.clock() + duration,
		})
	end
	ModVfx.quad({
		texture = Tex.MOD_HEX,
		cframe = ground,
		from = d * 0.95,
		color = color,
		life = duration,
		alpha0 = 0.72,
		hold = true,
	})
	ModVfx.quad({
		texture = Tex.MOD_RING_DASHED,
		cframe = ground + Vector3.new(0, 0.02, 0),
		from = d,
		color = color,
		life = duration,
		alpha0 = 0.05,
		hold = true,
		spin = 0.5,
	})
	ModVfx.quad({
		texture = Tex.MOD_RING,
		cframe = ground + Vector3.new(0, 0.04, 0),
		from = 2,
		to = d * 1.1,
		color = color,
		life = 0.4,
	})
	ModVfx.burst(at, color, 18, "Sparkle")
end

-- Ping -------------------------------------------------------------------------------

local function onPingPulse(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local color = teamColor(data)
	local d = radius * 2
	-- A scan wave across the ground and a thin bubble sweeping out.
	ModVfx.quad({
		texture = Tex.MOD_SCAN,
		cframe = CFrame.new(at - Vector3.new(0, 2.8, 0)),
		from = 2,
		to = d,
		color = color,
		life = 0.7,
		alpha0 = 0,
	})
	local band = ModVfx.mesh({
		name = "ScanRing",
		cframe = CFrame.new(at - Vector3.new(0, 2.8, 0)),
		from = Vector3.new(2, 2.5, 2),
		to = Vector3.new(d, 1, d),
		color = color,
		life = 0.7,
		alpha0 = 0.2,
	})
	if not band then
		ModVfx.shell({
			shape = Enum.PartType.Ball,
			cframe = CFrame.new(at),
			from = Vector3.one * 2,
			to = Vector3.one * d,
			color = color,
			life = 0.7,
			alpha0 = 0.75,
		})
	end
end

-- Revealed enemies: an orange-red outline through walls (your team only).
type RevealMark = { highlight: Highlight, untilT: number }
local reveals: { [Model]: RevealMark } = {}

local function onReveal(targets: unknown, duration: unknown)
	if typeof(targets) ~= "table" or typeof(duration) ~= "number" then
		return
	end
	local untilT = os.clock() + math.clamp(duration :: number, 0, 10)
	-- pairs, not ipairs: a model that isn't streamed in arrives as a hole.
	for _, target in pairs(targets :: { [any]: any }) do
		if typeof(target) == "Instance" and (target :: Instance):IsA("Model") then
			local model = target :: Model
			local mark = reveals[model]
			if mark then
				mark.untilT = untilT
			else
				local h = Instance.new("Highlight")
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillColor = TeamColor.ENEMY
				h.OutlineColor = TeamColor.ENEMY
				h.FillTransparency = 0.55
				h.OutlineTransparency = 0
				h.Adornee = model
				h.Parent = fxFolder()
				reveals[model] = { highlight = h, untilT = untilT }
			end
		end
	end
end

-- Overclock --------------------------------------------------------------------------

type Glow = { highlight: Highlight, untilT: number }
local glows: { Glow } = {}
local edge: Frame? = nil
local edgeStroke: UIStroke? = nil
local edgeUntil = 0

local function screenEdge(): Frame
	local f = edge
	if f and f.Parent then
		return f
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ModScreenFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")
	-- A stroke draws outside its frame: inset the frame by the thickness so
	-- the glow sits on the screen's edge.
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -40, 1, -40)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = TeamColor.ALLY
	stroke.Thickness = 20
	stroke.Transparency = 0.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	edge = frame
	edgeStroke = stroke
	return frame
end

local function onOverclock(data: { [string]: any })
	local duration = data.duration
	if typeof(duration) ~= "number" then
		return
	end
	if data.caster == player then
		edgeUntil = os.clock() + duration
		screenEdge().Visible = true
		return
	end
	local caster = data.caster
	local character = if typeof(caster) == "Instance" and (caster :: Instance):IsA("Player")
		then (caster :: Player).Character
		else nil
	local gun = character and character:FindFirstChild("WorldWeapon")
	if gun then
		local color = teamColor(data)
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillColor = color
		h.OutlineColor = color
		h.FillTransparency = 0.3
		h.Adornee = gun
		h.Parent = fxFolder()
		table.insert(glows, { highlight = h, untilT = os.clock() + duration })
	end
end

-- Placed objects ---------------------------------------------------------------------

-- Mod objects are dressed per viewer: a Launch Pad is a charcoal plate with
-- team-coloured chevrons scrolling toward the launch, a Firewall a team-
-- coloured shimmer with hex panels on both faces. They flash white when hit.
local objectFlash: { [BasePart]: number } = {}
local skins: { [BasePart]: { Texture } } = {}
-- Placed objects wearing their finished model (ModProps.dress): the server
-- part is the hitbox, hidden on this client; the model is the look.
type Dressed = { model: Model, energy: { BasePart }, arrows: { BasePart } }
local dressed: { [BasePart]: Dressed } = {}
local SHELL = Color3.fromHex("2A2D33")
local CHEVRON_SPEED = 5 -- studs per second the pad's arrows scroll
local ARROW_CHASE = 1.6 -- cycles per second of a finished pad's arrow chase

local function objectColor(part: BasePart): Color3
	local team = part:GetAttribute("TeamId")
	return TeamColor.forTeam(if typeof(team) == "number" then team else nil)
end

-- The part's own colour at rest (the pad's plate is charcoal).
local function restColor(part: BasePart): Color3
	return if part:GetAttribute("Kind") == "LaunchPad" then SHELL else objectColor(part)
end

local function skin(
	part: BasePart,
	face: Enum.NormalId,
	texture: string,
	u: number,
	v: number,
	alpha: number
): Texture
	local t = Instance.new("Texture")
	t.Name = "ModSkin"
	t.Face = face
	t.Texture = texture
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	t.Color3 = objectColor(part)
	t.Transparency = alpha
	t.Parent = part
	return t
end

local function undress(part: BasePart)
	local d = dressed[part]
	if d then
		dressed[part] = nil
		d.model:Destroy()
	end
end

-- The finished model on a placed part, when it's installed. Returns true
-- when it dressed the part.
local function dress(part: BasePart): boolean
	local model = ModProps.dress(part, objectColor(part))
	if not model then
		return false
	end
	local energy, arrows = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Energy") == true then
			table.insert(energy, d)
			if string.match(d.Name, "^Arrow%d") then
				table.insert(arrows, d)
			end
		end
	end
	table.sort(arrows, function(a, b)
		return a.Name < b.Name
	end)
	model.Parent = fxFolder()
	part.LocalTransparencyModifier = 1
	dressed[part] = { model = model, energy = energy, arrows = arrows }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			undress(part)
		end
	end)
	return true
end

local function colourObject(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("Kind")
	if dress(part) then
		-- The finished model carries the look.
		kind = nil
	end
	if kind == "LaunchPad" then
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
		skins[part] =
			{ skin(part, Enum.NormalId.Top, Tex.MOD_CHEVRON, part.Size.X, part.Size.Z, 0) }
	elseif kind == "Firewall" then
		local u = 2.4
		skins[part] = {
			skin(part, Enum.NormalId.Front, Tex.MOD_HEX, u, u * 0.866, 0.35),
			skin(part, Enum.NormalId.Back, Tex.MOD_HEX, u, u * 0.866, 0.35),
		}
	end
	part.Color = restColor(part)
	part.Destroying:Connect(function()
		skins[part] = nil
	end)
	local lastHp = part:GetAttribute("Hp")
	part:GetAttributeChangedSignal("Hp"):Connect(function()
		local hp = part:GetAttribute("Hp")
		if typeof(hp) == "number" and typeof(lastHp) == "number" and hp < lastHp then
			objectFlash[part] = os.clock()
		end
		lastHp = hp
	end)
end

local function onPlaced(data: { [string]: any })
	local at = data.at
	if typeof(at) ~= "Vector3" then
		return
	end
	local color = teamColor(data)
	ModVfx.quad({
		texture = Tex.MOD_RING,
		cframe = CFrame.new(at),
		from = 1,
		to = 10,
		color = color,
		life = 0.35,
	})
	ModVfx.burst(at, color, 14, "Sparkle")
end

local function onObjectGone(data: { [string]: any })
	local at, size = data.at, data.size
	if typeof(at) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local color = TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	local broken = data.why == "Broken"
	ModVfx.shell({
		shape = Enum.PartType.Block,
		cframe = CFrame.new(at),
		from = size,
		to = size * (if broken then 1.4 else 1.05),
		color = color,
		life = if broken then 0.3 else 0.25,
		alpha0 = 0.3,
		material = Enum.Material.Neon,
	})
	ModVfx.burst(at, color, if broken then 30 else 10, "Sparkle")
end

-- Rollback ---------------------------------------------------------------------------

-- Your own rewind: a short "VHS" wash (desaturated, high contrast, tinted).
local vhs: ColorCorrectionEffect? = nil
local VHS_TIME = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function playVhs()
	local effect = vhs
	if not effect or not effect.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "ModRewind"
		made.Parent = Lighting
		vhs = made
		effect = made
	end
	local cc = effect :: ColorCorrectionEffect
	cc.Saturation = -0.85
	cc.Contrast = 0.35
	cc.TintColor = Color3.fromHex("C8F7FF")
	cc.Brightness = 0.05
	TweenService:Create(cc, VHS_TIME, {
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1),
		Brightness = 0,
	}):Play()
end

-- Ghost trails: for anyone whose Rollback is ready, where they were over the
-- last few seconds (where a rewind would take them), coloured by team. The
-- big dot is where they'd land.
type Trail = { times: { number }, points: { Vector3 }, dots: { Part } }
local trails: { [Player]: Trail } = {}
local TRAIL_STEP = 0.2
local TRAIL_SPAN = 3
local nextTrailSample = 0

local function rollbackReady(other: Player): boolean
	local character = other.Character
	for slot = 1, 3 do
		if other:GetAttribute("Mod" .. slot .. "Id") == "Rollback" then
			local charges = character and character:GetAttribute("Mod" .. slot .. "Charges")
			return typeof(charges) ~= "number" or charges >= 1
		end
	end
	return false
end

local function dropTrail(other: Player)
	local trail = trails[other]
	if trail then
		local pool = parts()
		for _, dot in trail.dots do
			pool:release(dot)
		end
		trails[other] = nil
	end
end

local function stepTrails(now: number)
	if now < nextTrailSample then
		return
	end
	nextTrailSample = now + TRAIL_STEP
	for other in trails do
		if other.Parent ~= Players then
			dropTrail(other)
		end
	end
	for _, other in Players:GetPlayers() do
		local root = rootOf(other.Character)
		if not root or not rollbackReady(other) then
			dropTrail(other)
			continue
		end
		local trail = trails[other]
		if not trail then
			trail = { times = {}, points = {}, dots = {} }
			trails[other] = trail
		end
		local t = trail :: Trail
		table.insert(t.times, now)
		table.insert(t.points, root.Position - Vector3.new(0, 2.5, 0))
		while #t.times > 0 and now - t.times[1] > TRAIL_SPAN do
			table.remove(t.times, 1)
			table.remove(t.points, 1)
		end
		local color = TeamColor.forOwner(other)
		for i, point in t.points do
			local dot = t.dots[i]
			if not dot then
				dot = takePart(Enum.PartType.Ball, color)
				t.dots[i] = dot
			end
			local age = (now - t.times[i]) / TRAIL_SPAN
			dot.Color = color
			dot.Size = Vector3.one * (if i == 1 then 0.9 else 0.35)
			dot.CFrame = CFrame.new(point)
			dot.Transparency = 0.35 + 0.5 * (1 - age)
		end
		for i = #t.dots, #t.points + 1, -1 do
			parts():release(t.dots[i])
			t.dots[i] = nil
		end
	end
end

-- Slowed: a SLOWED tag over anyone a Lag Field is slowing.
local slowTags: { [Model]: BillboardGui } = {}

local function tagSlowed(model: Model?, seen: { [Model]: boolean })
	if not model then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	seen[model] = true
	if slowTags[model] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.TextSize = 16
	label.TextColor3 = TeamColor.forOwner(Players:GetPlayerFromCharacter(model) or model)
	label.TextStrokeTransparency = 0.4
	label.Text = "SLOWED"
	label.Parent = gui
	gui.Parent = player:FindFirstChild("PlayerGui")
	slowTags[model] = gui
end

local function stepSlowed()
	local seen: { [Model]: boolean } = {}
	for _, other in Players:GetPlayers() do
		local mult = other:GetAttribute("ModSpeedMult")
		if other ~= player and typeof(mult) == "number" and mult < 1 then
			tagSlowed(other.Character, seen)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slowed") == true then
				tagSlowed(m, seen)
			end
		end
	end
	for model, gui in slowTags do
		if not seen[model] then
			gui:Destroy()
			slowTags[model] = nil
		end
	end
end

local function onFx(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local d = data :: { [string]: any }
	if kind == "PacketThrow" then
		onPacketThrow(d)
	elseif kind == "PacketBoom" then
		onPacketBoom(d)
	elseif kind == "Heal" then
		onHeal(d)
	elseif kind == "LagThrow" then
		onLagThrow(d)
	elseif kind == "LagZone" then
		onLagZone(d)
	elseif kind == "PingPulse" then
		onPingPulse(d)
	elseif kind == "Overclock" then
		onOverclock(d)
	elseif kind == "Placed" then
		onPlaced(d)
	elseif kind == "ObjectGone" then
		onObjectGone(d)
	end
end

-- Per frame ---------------------------------------------------------------------------

local function update(_dt: number)
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local pool = parts()

	for i = #flights, 1, -1 do
		local f = flights[i]
		local t = serverNow - f.start
		if t >= f.fuse then
			table.remove(flights, i)
			f.model.Parent = nil
			local free = grenadeFree[f.key]
			if not free then
				free = {}
				grenadeFree[f.key] = free
			end
			table.insert(free, f.model)
			continue
		end
		local pos = Projectile.positionAt(f.path, math.max(t, 0))
		f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 5, 0))
		-- Fuse blink, faster as it runs out.
		local rate = 4 + 14 * (t / f.fuse)
		local on = not f.blink or math.sin(now * rate * math.pi * 2) > 0
		for _, g in f.glow do
			g.Transparency = if on then 0 else 0.6
		end
	end
	ModVfx.step()
	for i = #orbs, 1, -1 do
		local o = orbs[i]
		if now >= o.untilT then
			table.remove(orbs, i)
			o.model.Parent = nil
			local free = grenadeFree[o.key]
			if not free then
				free = {}
				grenadeFree[o.key] = free
			end
			table.insert(free, o.model)
		else
			o.model:PivotTo(
				CFrame.new(o.at + Vector3.new(0, 0.15 * math.sin(now * 3), 0))
					* CFrame.Angles(0, now * 4, 0)
			)
		end
	end

	for i = #beams, 1, -1 do
		local b = beams[i]
		local a, z = rootOf(b.from), rootOf(b.to)
		local k = (now - b.born) / b.duration
		if k >= 1 or not a or not z then
			table.remove(beams, i)
			pool:release(b.part)
			continue
		end
		local from = a.Position + Vector3.new(0, 0.6, 0)
		local to = z.Position + Vector3.new(0, 0.6, 0)
		local length = (to - from).Magnitude
		b.part.Size = Vector3.new(0.12, 0.12, length)
		b.part.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		b.part.Transparency = 0.3 + 0.5 * k
	end

	for model, mark in reveals do
		if now >= mark.untilT or not model.Parent then
			mark.highlight:Destroy()
			reveals[model] = nil
		end
	end
	for i = #glows, 1, -1 do
		local g = glows[i]
		local adornee = g.highlight.Adornee
		if now >= g.untilT or not adornee or not adornee.Parent then
			g.highlight:Destroy()
			table.remove(glows, i)
		end
	end
	local frame, stroke = edge, edgeStroke
	if frame and stroke and frame.Visible then
		local left = edgeUntil - now
		frame.Visible = left > 0
		local tail = if left < 0.5 then 0.4 * (1 - left / 0.5) else 0
		stroke.Transparency = math.min(0.62 + 0.12 * math.sin(now * 9) + tail, 1)
	end
	for part, at in objectFlash do
		local done = now - at >= 0.12 or not part.Parent
		if done then
			objectFlash[part] = nil
		end
		part.Color = if done then restColor(part) else Color3.new(1, 1, 1)
		for _, t in skins[part] or {} do
			t.Color3 = if done then objectColor(part) else Color3.new(1, 1, 1)
		end
		local d = dressed[part]
		if d then
			ModProps.tint(d.model, if done then objectColor(part) else Color3.new(1, 1, 1))
		end
	end
	-- Launch Pad arrows chase toward the launch, back to front.
	for _, d in dressed do
		local n = #d.arrows
		for i, arrow in d.arrows do
			local phase = (now * ARROW_CHASE - (i - 1) / n) % 1
			arrow.Transparency = 0.65 * phase
		end
	end
	for part, list in skins do
		if not part.Parent then
			skins[part] = nil
		elseif part:GetAttribute("Kind") == "LaunchPad" then
			local t = list[1]
			t.OffsetStudsV = (now * CHEVRON_SPEED) % t.StudsPerTileV
		end
	end
	stepTrails(now)

	-- Your own Rollback.
	local character = player.Character
	local rollbackAt = character and character:GetAttribute("RollbackAt")
	if typeof(rollbackAt) == "number" and rollbackAt > lastRollback then
		lastRollback = rollbackAt
		playVhs()
	end

	for i = #floaters, 1, -1 do
		local f = floaters[i]
		local k = (now - f.born) / FLOATER_TIME
		if k >= 1 then
			table.remove(floaters, i)
			f.gui.Parent = nil
			f.gui.Adornee = nil
			table.insert(floaterFree, f)
			continue
		end
		f.gui.StudsOffsetWorldSpace = Vector3.new(0, 2 + 1.5 * k, 0)
		f.label.TextTransparency = k * k
		f.label.TextStrokeTransparency = 0.4 + 0.6 * k
	end
end

function ModFxController.start()
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	Net.event("ModReveal").OnClientEvent:Connect(onReveal)
	RunService.RenderStepped:Connect(update)
	-- Mod objects: coloured for this viewer as they stream in.
	task.spawn(function()
		local objects = Workspace:WaitForChild("ModObjects")
		objects.ChildAdded:Connect(function(child)
			task.defer(colourObject, child)
		end)
		for _, child in objects:GetChildren() do
			colourObject(child)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			stepSlowed()
		end
	end)
	player.CharacterAdded:Connect(function()
		lastRollback = 0
	end)
end

return ModFxController
