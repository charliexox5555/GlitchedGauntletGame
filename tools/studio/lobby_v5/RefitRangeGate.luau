--!nocheck
-- Refits the hub's range gate (Shell.Hub.RangeBay.Gate, built by BuildRangeGateV6) into the rock opening
-- (owner 2026-11-26: "there's some overlapping parts on the front end, and overall just I think it needs to look
-- better"). Edit mode; run once after BuildRangeGateV6 (it moves parts by their current place, so a second run is a
-- no-op only for the parts it resizes; rebuild the gate first if in doubt).
--   * The opening is x -13.5..13.5 between the Wall_S rocks, under the chamber Lintel (y 30). The pylons sat at
--     x ±14.2 and cut 1.9 studs into the rock and the chamber Returns; their caps cut the Lintel. Now: pylons flush
--     to the rock faces, no caps, the header, sill, field and trigger between the pylons, the corner chamfers and
--     edge lights moved with them and stopped where they meet.
--   * The Lintel turns into the gate's dark metal fascia (one frame, not stone behind steel); the Returns stop at the
--     rock face; the sign moves forward to sit flush on the fascia instead of 0.8 studs inside it.
--   * The hologram: bigger pixel density for the narrower field, a dark shade behind the title so it reads over the
--     giant target, and the duplicate "EVERY GUN" line (the sign says it) dropped.
--   * The hub floor line Line_S stops at the apron instead of running under it.

local hub = workspace.LobbyV5.Shell.Hub
local bay = hub.RangeBay
local gate = bay.Gate
local chamber = bay.Chamber
local OPEN = 13.5 -- half width of the rock opening
local PYLON_W = 2.4
local INNER = OPEN - PYLON_W -- 11.1: the pylons' inner faces
local METAL = Color3.fromHex("34363a")
local report = {}

local function side(p: BasePart): number
	return if p.Position.X < gate:GetPivot().Position.X then -1 else 1
end
local function setX(p: BasePart, x: number)
	p.CFrame = CFrame.new(x, p.Position.Y, p.Position.Z) * p.CFrame.Rotation
end
local function setW(p: BasePart, w: number)
	p.Size = Vector3.new(w, p.Size.Y, p.Size.Z)
end

for _, p in gate:GetChildren() do
	if not p:IsA("BasePart") then
		continue
	end
	local s = side(p)
	if p.Name == "Pylon" then
		setX(p, s * (OPEN - PYLON_W / 2))
	elseif p.Name == "PylonCap" then
		p:Destroy()
	elseif p.Name == "PylonFoot" then
		p.Size = Vector3.new(2.8, p.Size.Y, p.Size.Z)
		setX(p, s * (OPEN - 1.4))
	elseif p.Name == "EdgeLight" then
		-- on the pylon's inner face, from the foot to the chamfer
		local bottom, top = 1.2, 28 - 2.6
		p.Size = Vector3.new(p.Size.X, top - bottom, p.Size.Z)
		p.CFrame = CFrame.new(s * (INNER - p.Size.X / 2 + 0.04), (bottom + top) / 2, p.Position.Z)
	elseif p.Name == "Chamfer" then
		setX(p, s * (INNER - 1.3))
	elseif p.Name == "Header" then
		setW(p, INNER * 2)
	elseif p.Name == "HeaderLight" then
		setW(p, (INNER - 2.6) * 2)
	elseif p.Name == "Sill" then
		setW(p, (OPEN - 2.8) * 2)
	elseif p.Name == "SillGlow" then
		setW(p, (OPEN - 2.8) * 2 - 1.6)
	elseif p.Name == "Field" or p.Name == "Projection" then
		setW(p, INNER * 2)
	elseif p.Name == "RangeEntry" then
		setW(p, INNER * 2 - 1)
	elseif p.Name == "Apron" then
		setW(p, 26) -- clear of the hub Steel column bases at x ±13.2
	end
end

-- the chamber's frame: Returns stop at the rock face, the Lintel becomes the gate's fascia
for _, p in chamber:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Return" then
		local s = if p.Position.X < 0 then -1 else 1
		local outer = math.abs(p.Position.X) + p.Size.X / 2
		setW(p, outer - OPEN)
		setX(p, s * (OPEN + p.Size.X / 2))
		p.Material = Enum.Material.Metal
		p.MaterialVariant = ""
		p.Color = Color3.fromHex("2a2c30")
	end
end
local lintel = chamber:FindFirstChild("Lintel")
if lintel then
	lintel.Material = Enum.Material.Metal
	lintel.MaterialVariant = ""
	lintel.Color = METAL
	setW(lintel, OPEN * 2)
end

-- the sign: flush on the fascia's face
local sign = gate:FindFirstChild("Sign")
if sign and lintel then
	local face = lintel.Position.Z - lintel.Size.Z / 2
	local cf, size = sign:GetBoundingBox()
	local back = cf.Position.Z + size.Z / 2
	-- (-0.4 more: the rim's faceted pieces reach past the box's back)
	sign:PivotTo(sign:GetPivot() + Vector3.new(0, 0, face - back - 0.4))
	table.insert(report, ("sign moved %.2f"):format(face - back))
end

-- the hologram
local projection = gate:FindFirstChild("Projection")
local gui = projection and projection:FindFirstChildOfClass("SurfaceGui")
if gui then
	gui.PixelsPerStud = 24
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	for _, l in gui:GetChildren() do
		if l:IsA("TextLabel") and string.find(l.Text, "EVERY GUN", 1, true) then
			l:Destroy()
		end
	end
	local old = gui:FindFirstChild("Shade")
	if old then
		old:Destroy()
	end
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.fromHex("06130f")
	shade.Size = UDim2.fromScale(1, 0.62)
	shade.ZIndex = 2
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.6, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = shade
	shade.Parent = gui
	for _, c in gui:GetChildren() do
		if c:IsA("TextLabel") then
			c.ZIndex = 3
		end
	end
end

-- the floor line stops at the apron
local apron = gate:FindFirstChild("Apron")
local line = hub.Dressing.FloorMarks:FindFirstChild("Line_S")
if apron and line then
	local stop = apron.Position.Z - apron.Size.Z / 2
	local far = line.Position.Z - line.Size.Z / 2
	if line.Position.Z + line.Size.Z / 2 > stop then
		line.Size = Vector3.new(line.Size.X, line.Size.Y, stop - far)
		line.CFrame = CFrame.new(line.Position.X, line.Position.Y, (stop + far) / 2)
	end
end

-- what still overlaps the gate from outside
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = { gate }
for _, p in gate:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		for _, h in workspace:GetPartsInPart(p, op) do
			table.insert(report, p.Name .. " x " .. h:GetFullName())
		end
	end
end
return table.concat(report, "\n")
