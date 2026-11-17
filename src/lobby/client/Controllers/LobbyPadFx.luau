--!strict
-- The Duels pads come alive (owner 2026-11-16: "how it looks when a player walks over a pad ... it highlights, it
-- looks really cool"; RIVALS' QueuePadVisuals: two rings float and turn over each team square, faint grey, and when a
-- team has players they take the team colour and a glow rises). Anchors tagged `LobbyPadSquare` (Build_V4 from
-- tools/blender/lobby_v4/v4_duels.pad): the anchor part is one team well under the pad's glass, with Pad, Team
-- (1 = A orange, 2 = B blue) and Mode. Per well this client builds two faceted rings (eight bars each: no curves)
-- that hover and turn in opposite directions, a glow curtain (four Beams up the well's edges) and a light; when any
-- player's character stands in the well the rings take the team colour and the glow and light fade in. Every client
-- sees every character, so everyone sees the same pads; nothing is sent to the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LobbyPadFx = {}

local TAG = "LobbyPadSquare"
local TEAM = { [1] = Color3.fromHex("FF6A3D"), [2] = Color3.fromHex("2A86FF") }
local IDLE = Color3.fromRGB(202, 203, 209)
local IDLE_T = 0.75 -- the rings when nobody is on the well
local ON_T = 0.05
local FADE = 0.25 -- seconds to light up or go out
local SPIN = 2 -- radians a second (outer ring one way, inner the other)
local LIFT = 0.45 -- the rings above the glass
local GLOW_H = 6.5 -- the glow curtain's height
local CHECK = 0.1 -- seconds between occupancy checks
local STAND_H = 7 -- studs above the glass a root part still counts as standing on it
local RANGE = 220 -- studs: further than this from the camera the rings hold still

type Well = {
	anchor: BasePart,
	team: number,
	centre: CFrame,
	half: Vector2,
	outer: Model,
	inner: Model,
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

-- A faceted ring of eight bars (inradius r to the bar's middle, band w), centred on the origin, flat.
local function ring(parent: Instance, r: number, w: number): Model
	local m = Instance.new("Model")
	m.Name = "Ring"
	local len = 2 * (r + w / 2) * math.tan(math.rad(22.5)) + w * 0.4
	for k = 0, 7 do
		local a = math.rad(45 * k)
		local p = Instance.new("Part")
		p.Name = "Bar"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = IDLE
		p.Transparency = IDLE_T
		p.Size = Vector3.new(w, 0.08, len)
		p.CFrame = CFrame.Angles(0, a, 0) * CFrame.new(r, 0, 0)
		p.Parent = m
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
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
	for _, m in { w.outer, w.inner } do
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				p.Color = c
				p.Transparency = t
			end
		end
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
	local team = inst:GetAttribute("Team")
	if typeof(team) ~= "number" then
		return
	end
	local top = inst.Position.Y + inst.Size.Y / 2
	local centre = CFrame.new(inst.Position.X, top, inst.Position.Z)
	local half = Vector2.new(inst.Size.X / 2, inst.Size.Z / 2)
	local holder = Instance.new("Folder")
	holder.Name = inst.Name
	holder.Parent = root()
	local s = math.min(half.X, half.Y) / 5.5 -- the rings follow the well's size (5.5 = an 11-stud well)
	local outer = ring(holder, 4.0 * s, 0.45 * s)
	local inner = ring(holder, 2.2 * s, 0.35 * s)
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
		outer = outer,
		inner = inner,
		beams = curtain(holder, centre, half, colour),
		light = light,
		holder = holder,
		on = false,
		mix = 0,
	}
	wells[inst] = w
	outer:PivotTo(centre + Vector3.new(0, LIFT, 0))
	inner:PivotTo(centre + Vector3.new(0, LIFT + 0.05, 0))
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
	local cam = workspace.CurrentCamera
	local t = os.clock()
	for _, w in wells do
		local goal = if w.on then 1 else 0
		if w.mix ~= goal then
			w.mix = if goal > w.mix
				then math.min(goal, w.mix + dt / FADE)
				else math.max(goal, w.mix - dt / FADE)
			paint(w)
		end
		if cam and (cam.CFrame.Position - w.centre.Position).Magnitude <= RANGE then
			local spin = if w.on then SPIN * 1.6 else SPIN
			w.outer:PivotTo(w.centre * CFrame.new(0, LIFT, 0) * CFrame.Angles(0, t * spin, 0))
			w.inner:PivotTo(
				w.centre * CFrame.new(0, LIFT + 0.05, 0) * CFrame.Angles(0, -t * spin, 0)
			)
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
