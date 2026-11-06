--!nocheck
-- Runs a match-map bundle in Lune against a mock place, without Studio, and dumps what it built.
--
--   lune run tools/studio/maps/mock_place.luau <bundle.luau> <Map> <Group> [<Group> ...] -o <dump.json>
--
-- <bundle.luau> is `python tools/studio/maps/bundle.py <Map> Greybox Art Lighting -o ...`. The kit is
-- mocked from art-source/maps/<Map>/Exports/<Group>.json (one box per part, at the same pivots
-- kit_bundle.py gives the real MeshParts), so put() places pieces exactly as in Studio. The dump has
-- every placed kit piece (name, map-space CFrame) and every visible non-kit part (greybox, barriers:
-- class, CFrame, size), for tools/blender/check_map_zfight.py. Lune 0.11 (rokit tool storage:
-- %USERPROFILE%/.rokit/tool-storage/lune-org/lune/0.11.0/lune.exe). Not a Roblox script: --!nocheck.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local args = process.args
local bundlePath, mapName = args[1], args[2]
local groups, out = {}, nil
local i = 3
while i <= #args do
	if args[i] == "-o" then
		out = args[i + 1]
		i += 2
	else
		table.insert(groups, args[i])
		i += 1
	end
end
assert(
	bundlePath and mapName and #groups > 0 and out,
	"usage: mock_place.luau <bundle> <Map> <Group...> -o <dump.json>"
)

roblox.implementMethod("Model", "PivotTo", function(m, target)
	local delta = target * m.WorldPivot:Inverse()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	m.WorldPivot = target
end)
roblox.implementMethod("Model", "GetPivot", function(m)
	return m.WorldPivot
end)

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local tags = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		tags[inst] = tags[inst] or {}
		table.insert(tags[inst], tag)
	end,
	HasTag = function(_, inst, tag)
		return table.find(tags[inst] or {}, tag) ~= nil
	end,
}
local gameProxy = setmetatable({ PlaceId = 133387545285290 }, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, name)
				if name == "CollectionService" then
					return CollectionService
				end
				return game:GetService(name)
			end
		end
		return game[k]
	end,
})

local V3 = roblox.Vector3
local NORMALS = {
	Right = V3.new(1, 0, 0),
	Left = V3.new(-1, 0, 0),
	Top = V3.new(0, 1, 0),
	Bottom = V3.new(0, -1, 0),
	Back = V3.new(0, 0, 1),
	Front = V3.new(0, 0, -1),
}
local Vector3 = setmetatable({
	FromNormalId = function(n)
		return NORMALS[n.Name]
	end,
	xAxis = V3.new(1, 0, 0),
	yAxis = V3.new(0, 1, 0),
	zAxis = V3.new(0, 0, 1),
	zero = V3.new(0, 0, 0),
	one = V3.new(1, 1, 1),
	new = V3.new,
}, { __index = V3 })

local env = setmetatable({
	game = gameProxy,
	workspace = workspace,
	Instance = roblox.Instance,
	CFrame = roblox.CFrame,
	Vector3 = Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Vector2 = roblox.Vector2,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	NumberRange = roblox.NumberRange,
}, { __index = _G })

-- Mock kit: ServerStorage.MapKit.<Map>.<Piece> with one Part per exported part (kit_bundle.py's pivots).
local ss = game:GetService("ServerStorage")
local kitRoot = roblox.Instance.new("Folder")
kitRoot.Name = "MapKit"
kitRoot.Parent = ss
local lib = roblox.Instance.new("Folder")
lib.Name = mapName
lib.Parent = kitRoot
for _, group in groups do
	local data = serde.decode(
		"json",
		fs.readFile("art-source/maps/" .. mapName .. "/Exports/" .. group .. ".json")
	)
	local models = {}
	for _, p in data.parts do
		local m = models[p.piece]
		if not m then
			m = roblox.Instance.new("Model")
			m.Name = p.piece
			m.WorldPivot = roblox.CFrame.new()
			m:SetAttribute("KitGroup", group)
			m.Parent = lib
			models[p.piece] = m
		end
		local part = roblox.Instance.new("Part")
		part.Name = p.name
		part.Anchored = true
		part.Size =
			V3.new(math.max(p.size[1], 0.05), math.max(p.size[3], 0.05), math.max(p.size[2], 0.05))
		part.CFrame = roblox.CFrame.new(p.center[1], p.center[3], -p.center[2])
			* roblox.CFrame.Angles(0, math.pi, 0)
		part.Parent = m
	end
end

local fn = luau.load(fs.readFile(bundlePath), { debugName = "bundle", environment = env })
local ok, res = pcall(fn)
print(if ok then res else ("BUNDLE FAILED: " .. tostring(res)))
if not ok then
	process.exit(1)
end

local map = workspace:FindFirstChild(mapName)
assert(map, "the bundle built no Workspace." .. mapName)
local origin = map.WorldPivot

local function cf(c)
	local m = origin:ToObjectSpace(c)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = m:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local dump = { map = mapName, pieces = {}, parts = {} }
local art = map:FindFirstChild("Art")
for _, d in map:GetDescendants() do
	if d:IsA("Model") and d:IsDescendantOf(art) and lib:FindFirstChild(d.Name) then
		table.insert(dump.pieces, { piece = d.Name, path = d:GetFullName(), cf = cf(d.WorldPivot) })
	elseif d:IsA("BasePart") and not d:IsDescendantOf(art) then
		if d.Transparency < 0.99 and not d:IsA("SpawnLocation") then
			table.insert(dump.parts, {
				name = d.Name,
				path = d:GetFullName(),
				class = d.ClassName,
				cf = cf(d.CFrame),
				size = { d.Size.X, d.Size.Y, d.Size.Z },
			})
		end
	end
end
fs.writeFile(out, serde.encode("json", dump, true))
print(
	string.format(
		"dump: %d kit pieces, %d visible other parts -> %s",
		#dump.pieces,
		#dump.parts,
		out
	)
)
