--!strict
-- The Duels pads come alive. v2 (owner 2026-11-20: "the circular thing that spins around ... I don't really like.
-- Let's improve on that"; RIVALS studied: a bold flat emblem in each well, lit in the team colour when occupied).
-- Each well (a BasePart tagged `LobbyPadSquare`, its top is the well floor, state value Team 1 = A gold, 2 = B cyan)
-- gets a flat RETICLE floating just above the floor: four thick corner brackets with bevelled tips and a hollow
-- diamond in the middle, made of flat plates (no curves). Idle it sits still, light grey and faint. When any player's
-- character stands in the well it LOCKS ON: the brackets snap inward, the diamond turns square, everything takes the
-- team colour, and a glow curtain (four Beams up the well's edges) and a light fade in. No spinning. Every client
-- sees every character, so everyone sees the same pads; nothing is sent to the server.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local LobbyPadFx = {}

local TAG = "LobbyPadSquare"
local TEAM = { [1] = Color3.fromHex("FFB627"), [2] = Color3.fromHex("2EC8FF") } -- gold / cyan (owner 2026-11-20: away from orange / blue)
local IDLE = Color3.fromRGB(206, 206, 202)
local IDLE_T = 0.45 -- the reticle when nobody is on the well
local ON_T = 0.0
local FADE = 0.22 -- seconds to lock on or let go
local LIFT = 0.1 -- the reticle above the well floor
local THICK = 0.05 -- the plates' thickness
local GLOW_H = 6.5 -- the glow curtain's height
local CHECK = 0.1 -- seconds between occupancy checks
local STAND_H = 7 -- studs above the glass a root part still counts as standing on it

type Well = {
	anchor: BasePart,
	team: number,
	centre: CFrame,
	half: Vector2,
	corners: { Model }, -- four corner brackets
	diamond: Model,
	size: number, -- the reticle's half-size (bracket corner distance from the centre)
	plates: { BasePart },
	beams: { Beam },
	light: PointLight,
	holder: Folder,
	on: boolean,
	mix: number, -- 0 idle .. 1 lit
}

local wells: { [BasePart]: Well } = {}
local folder: Folder? = nil

local function root(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "LobbyPadFx"
	f.Parent = workspace
	folder = f
	return f
end

local function plate(parent: Instance, size: Vector3, cf: CFrame, cls: string?): BasePart
	local p = Instance.new((cls or "Part") :: any) :: BasePart
	p.Name = "Plate"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = IDLE
	p.Transparency = IDLE_T
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- A flat right triangle (a WedgePart lying flat): right angle at p, legs u (length a) and v (length b), in the
-- model's local frame; thickness THICK along Y.
local function flatTri(
	parent: Instance,
	p: Vector3,
	u: Vector3,
	a: number,
	v: Vector3,
	b: number
): BasePart
	local X, Y = Vector3.yAxis, u.Unit
	if X:Cross(Y):Dot(-v.Unit) < 0 then
		X = -X
	end
	local c = p + u.Unit * a / 2 + v.Unit * b / 2
	return plate(parent, Vector3.new(THICK, a, b), CFrame.fromMatrix(c, X, Y), "WedgePart")
end

-- One corner bracket in local space: the corner at the origin, arms running +X and +Z (inward), each arm ending in
-- a 45-degree bevelled tip. len = arm length, w = arm width.
local function bracket(parent: Instance, len: number, w: number): Model
	local m = Instance.new("Model")
	m.Name = "Bracket"
	plate(m, Vector3.new(len - w, THICK, w), CFrame.new((len - w) / 2, 0, w / 2))
	flatTri(m, Vector3.new(len - w, 0, 0), Vector3.xAxis, w, Vector3.zAxis, w)
	plate(m, Vector3.new(w, THICK, len - 2 * w), CFrame.new(w / 2, 0, w + (len - 2 * w) / 2))
	flatTri(m, Vector3.new(0, 0, len - w), Vector3.zAxis, w, Vector3.xAxis, w)
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

-- The hollow diamond: a square ring of side d and bar width b, plus a small centre stud; turned 45 degrees idle.
local function diamond(parent: Instance, d: number, b: number): Model
	local m = Instance.new("Model")
	m.Name = "Diamond"
	plate(m, Vector3.new(d, THICK, b), CFrame.new(0, 0, (d - b) / 2))
	plate(m, Vector3.new(d, THICK, b), CFrame.new(0, 0, -(d - b) / 2))
	plate(m, Vector3.new(b, THICK, d - 2 * b), CFrame.new((d - b) / 2, 0, 0))
	plate(m, Vector3.new(b, THICK, d - 2 * b), CFrame.new(-(d - b) / 2, 0, 0))
	plate(m, Vector3.new(b * 1.1, THICK, b * 1.1), CFrame.Angles(0, math.rad(45), 0))
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

-- each corner's turn so its arms point inward: { sx, sz, turn }
local CORNERS = {
	{ -1, -1, 0 },
	{ -1, 1, math.rad(90) },
	{ 1, -1, math.rad(-90) },
	{ 1, 1, math.rad(180) },
}

local function ease(k: number): number
	return 1 - (1 - k) ^ 5 -- Quint out: a quick snap, a soft landing
end

-- Places the reticle for the well's lock-on amount (mix 0 idle .. 1 locked).
local function pose(w: Well)
	local k = ease(w.mix)
	local r = w.size * (1.1 - 0.24 * k)
	local base = w.centre * CFrame.new(0, LIFT, 0)
	for i, c in CORNERS do
		w.corners[i]:PivotTo(base * CFrame.new(c[1] * r, 0, c[2] * r) * CFrame.Angles(0, c[3], 0))
	end
	w.diamond:PivotTo(base * CFrame.new(0, 0.01, 0) * CFrame.Angles(0, math.rad(45) * (1 - k), 0))
end

local function curtain(holder: Instance, centre: CFrame, half: Vector2, colour: Color3): { Beam }
	local base = Instance.new("Part")
	base.Name = "GlowBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(0.2, 0.2, 0.2)
	base.CFrame = centre
	base.Parent = holder
	local beams = {}
	-- each edge: midpoint, the edge's direction (the beam's width runs along its attachments' Y)
	local edges = {
		{ Vector3.new(half.X, 0, 0), Vector3.zAxis, half.Y * 2 },
		{ Vector3.new(-half.X, 0, 0), Vector3.zAxis, half.Y * 2 },
		{ Vector3.new(0, 0, half.Y), Vector3.xAxis, half.X * 2 },
		{ Vector3.new(0, 0, -half.Y), Vector3.xAxis, half.X * 2 },
	}
	for _, e in edges do
		local mid, along, width = e[1], e[2], e[3]
		local a0 = Instance.new("Attachment")
		a0.CFrame = CFrame.fromMatrix(mid, Vector3.yAxis, along)
		a0.Parent = base
		local a1 = Instance.new("Attachment")
		a1.CFrame = CFrame.fromMatrix(mid + Vector3.new(0, GLOW_H, 0), Vector3.yAxis, along)
		a1.Parent = base
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = width, width
		b.FaceCamera = false
		b.Segments = 1
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(colour)
		b.Transparency = NumberSequence.new(1)
		b.Enabled = false
		b.Parent = base
		table.insert(beams, b)
	end
	return beams
end

local function paint(w: Well)
	local colour = TEAM[w.team] or IDLE
	local k = w.mix
	local c = IDLE:Lerp(colour, k)
	local t = IDLE_T + (ON_T - IDLE_T) * k
	for _, p in w.plates do
		p.Color = c
		p.Transparency = t
	end
	for _, b in w.beams do
		b.Enabled = k > 0.01
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - 0.55 * k),
			NumberSequenceKeypoint.new(0.6, 1 - 0.18 * k),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	w.light.Brightness = 2.5 * k
	w.light.Enabled = k > 0.01
end

local function track(inst: Instance)
	if not inst:IsA("BasePart") or wells[inst] then
		return
	end
	local team = StateValues.get(inst, "Team")
	if typeof(team) ~= "number" then
		return
	end
	local top = inst.Position.Y + inst.Size.Y / 2
	local centre = CFrame.new(inst.Position.X, top, inst.Position.Z)
	local half = Vector2.new(inst.Size.X / 2, inst.Size.Z / 2)
	local holder = Instance.new("Folder")
	holder.Name = inst.Name
	holder.Parent = root()
	-- the reticle follows the well's short side
	local size = math.min(half.X, half.Y) * 0.72
	local corners = {}
	for _ = 1, 4 do
		table.insert(corners, bracket(holder, size * 0.62, size * 0.2))
	end
	local dia = diamond(holder, size * 0.56, size * 0.12)
	local plates = {}
	for _, m in { dia, corners[1], corners[2], corners[3], corners[4] } do
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(plates, p)
			end
		end
	end
	local colour = TEAM[team] or IDLE
	local lightPart = Instance.new("Part")
	lightPart.Name = "GlowLight"
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.CanQuery = false
	lightPart.CanTouch = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lightPart.CFrame = centre + Vector3.new(0, 2.5, 0)
	lightPart.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 14
	light.Brightness = 0
	light.Enabled = false
	light.Parent = lightPart
	local w: Well = {
		anchor = inst,
		team = team,
		centre = centre,
		half = half,
		corners = corners,
		diamond = dia,
		size = size,
		plates = plates,
		beams = curtain(holder, centre, half, colour),
		light = light,
		holder = holder,
		on = false,
		mix = 0,
	}
	wells[inst] = w
	pose(w)
	paint(w)
end

local function untrack(inst: Instance)
	local w = inst:IsA("BasePart") and wells[inst :: BasePart]
	if w then
		w.holder:Destroy()
		wells[inst :: BasePart] = nil
	end
end

-- Who stands where: any player's root part over a well, low enough to be standing on it.
local function check()
	if PlayZone.get(Players.LocalPlayer) ~= "Lobby" then
		return
	end
	local roots = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			table.insert(roots, r.Position)
		end
	end
	for _, w in wells do
		local on = false
		for _, pos in roots do
			local rel = w.centre:PointToObjectSpace(pos)
			if
				math.abs(rel.X) <= w.half.X
				and math.abs(rel.Z) <= w.half.Y
				and rel.Y > -1
				and rel.Y < STAND_H
			then
				on = true
				break
			end
		end
		w.on = on
	end
end

local function step(dt: number)
	if PlayZone.get(Players.LocalPlayer) ~= "Lobby" then
		return
	end
	for _, w in wells do
		local goal = if w.on then 1 else 0
		if w.mix ~= goal then
			w.mix = if goal > w.mix
				then math.min(goal, w.mix + dt / FADE)
				else math.max(goal, w.mix - dt / FADE)
			paint(w)
			pose(w)
		end
	end
end

function LobbyPadFx.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	for _, a in CollectionService:GetTagged(TAG) do
		track(a)
	end
	task.spawn(function()
		while true do
			check()
			task.wait(CHECK)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return LobbyPadFx
