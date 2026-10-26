--!strict
-- Launch Pad (Mobility, Placeable): held, LMB places a pad where you look
-- (Blocks/Placeable, the same check on both sides). The server owns the pad
-- (ModEntities: 50 HP, 15 s, workspace.ModObjects); the launch itself is
-- predicted: Simulation/Abilities checks your feet against your team's pads
-- every step and throws you up and forward (launch()).
--
-- Pad attributes: Kind "LaunchPad", TeamId, LaunchUp, LaunchForward (+ the
-- ModEntities ones). Its LookVector is the launch direction.

local Placeable = require(script.Parent.Blocks.Placeable)
local Types = require(script.Parent.Types)

local LaunchPad = {}

local THICKNESS = 0.4
local LAUNCH_GAP = 0.5 -- seconds before the same character can launch again
local FEET_ABOVE = 4.5 -- root this high above the pad still counts as on it
local RISE_TIME = 0.2 -- seconds the launch's vertical speed is held (see launch)

function LaunchPad.size(stats: Types.Stats): Vector3
	return Vector3.new(stats.size, THICKNESS, stats.size)
end

function LaunchPad.find(
	head: Vector3,
	aim: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Placeable.Spot
	return Placeable.find(
		head,
		aim,
		stats.placeRange,
		LaunchPad.size(stats),
		params,
		Placeable.overlap(false)
	)
end

-- The pads in workspace.ModObjects, kept up to date (the simulation scans
-- them every step: no table built per step). Events can't be connected
-- inside a simulation callback, so AbilitiesSim.initialize calls watch().
local pads: { BasePart } = {}
local watching = false

local function addPad(child: Instance)
	if child:IsA("BasePart") and child.Name == "LaunchPad" and not table.find(pads, child) then
		table.insert(pads, child)
	end
end

local function removePad(child: Instance)
	local i = table.find(pads, child :: any)
	if i then
		table.remove(pads, i)
	end
end

local function watchFolder(folder: Instance)
	folder.ChildAdded:Connect(addPad)
	folder.ChildRemoved:Connect(removePad)
	for _, child in folder:GetChildren() do
		addPad(child)
	end
end

-- Call once per side, outside the simulation.
function LaunchPad.watch()
	if watching then
		return
	end
	watching = true
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ModObjects" then
			watchFolder(child)
		end
	end)
	local folder = workspace:FindFirstChild("ModObjects")
	if folder then
		watchFolder(folder)
	end
end

local function number(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- Simulation: launches `root` off a pad of team `team` it's standing on,
-- then holds the launch's horizontal velocity until you land (a predictable
-- arc: the counter-play is shooting people in the air). Returns the forward
-- speed to carry through the air on the launch step (nil otherwise).
-- Character attributes: LaunchAt, LaunchVelocity (flat), LaunchUp, Launching.
function LaunchPad.launch(
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	team: number?,
	now: number
): number?
	if character:GetAttribute("Launching") == true then
		local since = now - number(character, "LaunchAt", 0)
		local v = character:GetAttribute("LaunchVelocity")
		local flat = if typeof(v) == "Vector3" then v else Vector3.zero
		local vel = root.AssemblyLinearVelocity
		if since < RISE_TIME then
			-- The Humanoid's ground state brakes a vertical kick for a few
			-- steps (measured: 99 → 55 studs/s in one): hold the launch's own
			-- arc until it's clear of the pad.
			local up = number(character, "LaunchUp", 0) - workspace.Gravity * since
			root.AssemblyLinearVelocity = Vector3.new(flat.X, math.max(vel.Y, up), flat.Z)
		elseif humanoid.FloorMaterial ~= Enum.Material.Air then
			character:SetAttribute("Launching", false) -- landed
		else
			root.AssemblyLinearVelocity = Vector3.new(flat.X, vel.Y, flat.Z)
		end
	end
	if team == nil or #pads == 0 then
		return nil
	end
	if now - number(character, "LaunchAt", -math.huge) < LAUNCH_GAP then
		return nil
	end
	for _, pad in pads do
		if pad:GetAttribute("Kind") == "LaunchPad" and pad:GetAttribute("TeamId") == team then
			local rel = pad.CFrame:PointToObjectSpace(root.Position)
			local half = pad.Size / 2
			if
				math.abs(rel.X) <= half.X + 0.5
				and math.abs(rel.Z) <= half.Z + 0.5
				and rel.Y >= 0
				and rel.Y <= FEET_ABOVE
				and root.AssemblyLinearVelocity.Y <= 5
			then
				local forward = number(pad, "LaunchForward", 30)
				local flat = pad.CFrame.LookVector * Vector3.new(1, 0, 1)
				local push = if flat.Magnitude > 1e-3 then flat.Unit * forward else Vector3.zero
				root.AssemblyLinearVelocity = push + Vector3.new(0, number(pad, "LaunchUp", 99), 0)
				character:SetAttribute("LaunchAt", now)
				character:SetAttribute("LaunchVelocity", push)
				character:SetAttribute("LaunchUp", number(pad, "LaunchUp", 99))
				character:SetAttribute("Launching", true)
				return forward
			end
		end
	end
	return nil
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local spot = LaunchPad.find(ctx.head.Position, req.direction, ctx.stats, ctx.worldParams())
	if not spot.valid then
		return false, spot.reason
	end
	req.placement = spot.cframe
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local pad = Instance.new("Part")
	pad.Name = "LaunchPad"
	pad.Size = LaunchPad.size(stats)
	local placement = req.placement
	if not placement then
		return
	end
	pad.CFrame = placement
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromHex("2A2D33") -- clients recolour by team
	pad.Transparency = 0.15
	pad.CanCollide = true
	pad.CanTouch = false
	pad:SetAttribute("LaunchUp", stats.launchUp)
	pad:SetAttribute("LaunchForward", stats.launchForward)
	ctx.place("LaunchPad", pad, stats.life, stats.hp, stats.charges)
	ctx.fx("Placed", { kind = "LaunchPad", at = pad.Position })
	ctx.active(stats.life)
end

LaunchPad.module = module

return LaunchPad
