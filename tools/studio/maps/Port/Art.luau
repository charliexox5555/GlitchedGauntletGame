--!strict
-- Pier + Dockyard art pass (map redesign batch 2, 2026-11-16): puts the port kit (ServerStorage.MapKit.Port,
-- installed by `python tools/studio/maps/kit_bundle.py Port Kit`) on the greybox. Match place, edit mode,
-- after Greybox.luau. The greybox parts it replaces stay as invisible collision (hidden, never deleted).
--   containers: the matching length (15/20/25/30), red for the spawn / cross / yard / right-short containers,
--   door ends alternating; the gantry over its legs and beam; the warehouse roof and the roof stairs
--   (Dockyard); bollards along the long deck edges where nothing stands within 3 studs (decor).

assert(game.PlaceId == 133387545285290, "Port art: not the match place")
local lib = game:GetService("ServerStorage"):WaitForChild("MapKit"):WaitForChild("Port")

local RED: { [string]: boolean } =
	{ ["Spawn container"] = true, ["Cross container"] = true, ["Yard container"] = true, ["Right short"] = true }

local function hide(p: BasePart)
	p.Transparency = 1
	p.CastShadow = false
	for _, t in p:GetChildren() do
		if t:IsA("Texture") then
			t:Destroy()
		end
	end
end

local function put(parent: Instance, piece: string, cf: CFrame, name: string?): Model
	local src = lib:FindFirstChild(piece)
	assert(src and src:IsA("Model"), "missing kit piece " .. piece)
	local m = src:Clone()
	m.Name = name or piece
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local report = {}
for _, map in { workspace:FindFirstChild("Pier"), workspace:FindFirstChild("Dockyard") } do
	if not (map and map:IsA("Model")) then
		continue
	end
	local o = map.WorldPivot
	local greybox = map:WaitForChild("Greybox")
	local old = map:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	local art = Instance.new("Folder")
	art.Name = "Art"
	art.Parent = map
	local cont = Instance.new("Folder")
	cont.Name = "Containers"
	cont.Parent = art
	local n, flip = 0, false
	for _, p in greybox:WaitForChild("Containers"):GetChildren() do
		if
			p:IsA("BasePart")
			and math.abs(p.Size.Y - 10) < 0.01
			and (math.abs(p.Size.X - 10) < 0.01 or math.abs(p.Size.Z - 10) < 0.01)
			and p.Size.X * p.Size.Z > 100
		then
			local alongX = p.Size.X > p.Size.Z
			local len = math.floor(math.max(p.Size.X, p.Size.Z) + 0.5)
			local base = string.gsub(p.Name, "'", "")
			local colour = if RED[base] and (len == 20 or len == 30) then "Red" else "Grey"
			local yaw = if alongX then 0 else math.pi / 2
			flip = not flip
			if flip then
				yaw += math.pi
			end
			local floor = p.Position - Vector3.new(0, p.Size.Y / 2, 0)
			put(cont, "Container" .. colour .. len, CFrame.new(floor) * CFrame.Angles(0, yaw, 0), p.Name)
			hide(p)
			n += 1
		end
	end
	for _, p in greybox:WaitForChild("Gantry"):GetChildren() do
		if p:IsA("BasePart") then
			hide(p)
		end
	end
	put(art, if map.Name == "Pier" then "GantryPier" else "GantryDock", o, "Gantry")
	local wh = greybox:FindFirstChild("Warehouse")
	if wh then
		for _, p in wh:GetChildren() do
			if not p:IsA("BasePart") then
				continue
			end
			if string.find(p.Name, "Warehouse roof") then
				put(art, "WarehouseRoof", CFrame.new(p.Position.X, o.Y, p.Position.Z), p.Name)
				hide(p)
			elseif p:IsA("WedgePart") then
				local dir = -p.CFrame.LookVector
				put(art, "RoofStair", CFrame.new(p.Position.X, o.Y, p.Position.Z) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0), p.Name)
				hide(p)
			end
		end
	end
	local deck = greybox:WaitForChild("Floor"):WaitForChild("Deck") :: BasePart
	local hx, hz = deck.Size.X / 2, deck.Size.Z / 2
	local bol = Instance.new("Folder")
	bol.Name = "Bollards"
	bol.Parent = art
	local solids: { BasePart } = {}
	for _, p in greybox:GetDescendants() do
		if p:IsA("BasePart") and p ~= deck and p.Parent and p.Parent.Name ~= "Bounds" and p.Parent.Name ~= "Water" then
			table.insert(solids, p)
		end
	end
	local function clear(pos: Vector3): boolean
		for _, s in solids do
			local lp = s.CFrame:PointToObjectSpace(pos)
			if math.abs(lp.X) < s.Size.X / 2 + 3 and math.abs(lp.Z) < s.Size.Z / 2 + 3 then
				return false
			end
		end
		return true
	end
	local b = 0
	for zz = -hz + 7.5, hz - 7.5, 15 do
		for _, x in { hx - 1.3, -hx + 1.3 } do
			local w = o * CFrame.new(x, 0, zz)
			if clear(w.Position) then
				put(bol, "Bollard", w, "Bollard")
				b += 1
			end
		end
	end
	table.insert(report, string.format("%s: %d containers, gantry, %d bollards", map.Name, n, b))
end
return table.concat(report, " | ")
