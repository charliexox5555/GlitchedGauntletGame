--!strict
-- World effects of Mods for everyone (ModFx events from ModService), coloured
-- per viewer (Util/TeamColor): cyan for you and your team, orange-red for
-- enemies. Cosmetic only: the server already decided every result. Stage 1
-- placeholders (pooled parts and billboards); the VFX pass replaces them.
--
--   PacketThrow  the grenade flying its server path (Blocks/Projectile replay),
--                fuse blink, and a danger ring where it will go off
--   PacketBoom   flash sphere + shockwave ring, camera shake nearby
--   Heal         a beam from the healer to the ally, +HP over the target

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)

local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local VfxPool = require(script.Parent.Parent.Util.VfxPool)
local CameraController = require(script.Parent.CameraController)

local ModFxController = {}

local player = Players.LocalPlayer

type Flight = {
	model: Model,
	glow: { BasePart },
	ring: Part,
	path: Projectile.Path,
	start: number,
	fuse: number,
	color: Color3,
	key: string,
}

type Boom = { sphere: Part, ring: Part, at: Vector3, radius: number, born: number }

type Beam = {
	part: Part,
	from: Model,
	to: Model,
	born: number,
	duration: number,
}

type Floater = { gui: BillboardGui, label: TextLabel, born: number }

local BOOM_TIME = 0.35
local FLOATER_TIME = 1.1

local folder: Folder? = nil
local flights: { Flight } = {}
local booms: { Boom } = {}
local beams: { Beam } = {}
local floaters: { Floater } = {}
local grenadeFree: { [string]: { Model } } = {}
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
	return p
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

-- Packet ----------------------------------------------------------------------------

local function takeGrenade(color: Color3): (Model?, string)
	local key = color:ToHex()
	local free = grenadeFree[key]
	local model = free and table.remove(free)
	if not model then
		local template = ModProps.get("Packet", color)
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
	local model, key = takeGrenade(color)
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
	local ring = takePart(Enum.PartType.Cylinder, color)
	ring.Size = Vector3.new(0.08, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(Projectile.positionAt(path, fuse)) * CFrame.Angles(0, 0, math.pi / 2)
	table.insert(flights, {
		model = model,
		glow = glow,
		ring = ring,
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
	local sphere = takePart(Enum.PartType.Ball, color)
	local ring = takePart(Enum.PartType.Cylinder, color)
	table.insert(
		booms,
		{ sphere = sphere, ring = ring, at = at, radius = radius, born = os.clock() }
	)
	local cam = Workspace.CurrentCamera
	if cam then
		local d = (cam.CFrame.Position - at).Magnitude
		if d < radius * 4 then
			CameraController.shake(1.2 * (1 - d / (radius * 4)))
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
			pool:release(f.ring)
			continue
		end
		local pos = Projectile.positionAt(f.path, math.max(t, 0))
		f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 5, 0))
		-- Fuse blink, faster as it runs out.
		local rate = 4 + 14 * (t / f.fuse)
		local on = math.sin(now * rate * math.pi * 2) > 0
		for _, g in f.glow do
			g.Transparency = if on then 0 else 0.6
		end
		f.ring.Transparency = 0.8 - 0.25 * (t / f.fuse) + (if on then 0 else 0.08)
	end

	for i = #booms, 1, -1 do
		local b = booms[i]
		local k = (now - b.born) / BOOM_TIME
		if k >= 1 then
			table.remove(booms, i)
			pool:release(b.sphere)
			pool:release(b.ring)
			continue
		end
		local e = 1 - (1 - k) * (1 - k)
		local d = b.radius * 2 * (0.25 + 0.75 * e)
		b.sphere.Size = Vector3.one * d
		b.sphere.CFrame = CFrame.new(b.at)
		b.sphere.Transparency = 0.25 + 0.75 * k
		local r = b.radius * 2 * (0.4 + 0.8 * e)
		b.ring.Size = Vector3.new(0.12, r, r)
		b.ring.CFrame = CFrame.new(b.at) * CFrame.Angles(0, 0, math.pi / 2)
		b.ring.Transparency = 0.4 + 0.6 * k
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
	RunService.RenderStepped:Connect(update)
end

return ModFxController
