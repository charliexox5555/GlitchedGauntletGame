--!strict
-- Launch thumbnail staging in a local copy of the merged Lobby place.
-- Returns a function that clones an installed map and adds an editable camera
-- and actor marks. Every call keeps the session's earlier stages intact.

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

type Mark = { name: string, position: Vector3, facing: number, color: Color3 }
type Shot = {
	map: string,
	eye: Vector3,
	focus: Vector3,
	horizontalFov: number,
	roll: number,
	actors: { Mark },
}

local V = Vector3.new
local BLUE = Color3.fromHex("408DFA")
local ORANGE = Color3.fromHex("FF762B")
local GOLD = Color3.fromHex("FFD23F")

local shots: { [string]: Shot } = {
	["01-lock-in"] = {
		map = "Rooftops4",
		eye = V(0.1, -1.2, 13.4),
		focus = V(0.4, 1, -2),
		horizontalFov = 72,
		roll = -4,
		actors = {
			{ name = "Blue Updraft", position = V(4.1, -2.84, 0.9), facing = 155, color = BLUE },
			{ name = "Orange opponent", position = V(8.8, -6, -8), facing = -155, color = ORANGE },
		},
	},
	["02-foundry-duel"] = {
		map = "Foundry4",
		eye = V(3.5, 4.1, 12.9),
		focus = V(1.05, 4.6, -14),
		horizontalFov = 79,
		roll = -5,
		actors = {
			{ name = "Gold challenger", position = V(0.5, 0.25, -3.5), facing = 160, color = GOLD },
		},
	},
	["03-blue-v-orange"] = {
		map = "Foundry4",
		eye = V(0, 3.95, 7.7),
		focus = V(0, 3.55, -5),
		horizontalFov = 56,
		roll = 0,
		actors = {
			{ name = "Blue team", position = V(-3.12, 0, -2.4), facing = -140, color = BLUE },
			{ name = "Orange team", position = V(3.27, 0, -2.13), facing = 142, color = ORANGE },
		},
	},
	["04-rooftop-slide"] = {
		map = "Rooftops4",
		eye = V(-0.4, -3.5, 10.3),
		focus = V(0.3, -2.4, -3.5),
		horizontalFov = 72,
		roll = 6,
		actors = {
			{ name = "Blue slide", position = V(-2.41, -6, 2), facing = -152, color = BLUE },
			{
				name = "Orange lane",
				position = V(6.25, -5.95, -10.3),
				facing = 154,
				color = ORANGE,
			},
		},
	},
	["05-tempest-inspect"] = {
		map = "Rooftops4",
		eye = V(-0.2, 0.1, 14.2),
		focus = V(-0.5, 2.3, -7),
		horizontalFov = 60,
		roll = -5,
		actors = {},
	},
}

return function(shotId: string, placement: CFrame?): Model
	assert(not RunService:IsRunning(), "Open an unpublished local copy in Studio Edit mode")
	local shot = assert(shots[shotId], "Unknown launch shot: " .. shotId)
	local maps =
		assert(ServerStorage:FindFirstChild("Maps"), "Missing ServerStorage.Maps in this copy")
	local source = assert(maps:FindFirstChild(shot.map), "Missing map in this copy: " .. shot.map)
	assert(source:IsA("Model"), "The map must be a Model")
	local origin = placement or CFrame.new(0, 7000, 0)
	local frame = if shot.map == "Foundry4"
		then origin * CFrame.new(-21.6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		else origin
	local stage = Instance.new("Model")
	stage.Name = "Draft Duels Photo Stage - " .. shotId
	stage:SetAttribute("AspectRatio", "16:9")
	stage:SetAttribute("SourceMap", shot.map)
	local map = source:Clone()
	for _, obj in map:GetDescendants() do
		if obj:IsA("BaseScript") then
			obj.Enabled = false
		end
	end
	map:PivotTo(origin)
	map.Parent = stage

	local cam = Instance.new("Camera")
	cam.Name = "Thumbnail Camera"
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = frame
		* CFrame.lookAt(shot.eye, shot.focus)
		* CFrame.Angles(0, 0, math.rad(shot.roll))
	cam.Focus = CFrame.new(frame:PointToWorldSpace(shot.focus))
	cam.FieldOfView = math.deg(2 * math.atan(math.tan(math.rad(shot.horizontalFov) / 2) * 9 / 16))
	cam.Parent = stage

	local marks = Instance.new("Folder")
	marks.Name = "Actors"
	marks.Parent = stage
	for _, actor in shot.actors do
		local marker = Instance.new("Part")
		marker.Name = actor.name
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Size = V(2, 0.08, 1.2)
		marker.Color = actor.color
		marker.Material = Enum.Material.Neon
		marker.CFrame = frame
			* CFrame.new(actor.position)
			* CFrame.Angles(0, math.rad(actor.facing), 0)
		marker.Parent = marks
	end
	stage.Parent = workspace
	local current = workspace.CurrentCamera
	if current then
		current.CameraType = Enum.CameraType.Scriptable
		current.CFrame = cam.CFrame
		current.Focus = cam.Focus
		current.FieldOfView = cam.FieldOfView
	end
	Selection:Set({ stage })
	return stage
end
