--!strict
-- The Firewall's walls (Mods/Firewall, vault/01 Design/Abilities/Firewall.md),
-- built and burned on the server. A wall starts at the caster's feet and
-- grows forward at `speed` along the floor (each new point is dropped onto
-- the ground below; it goes through walls and over cover), turning toward
-- the caster's look at most `turnRate` degrees a second unless it's straight.
-- It stops at `maxLength`, when the caster lets go (ModSteer stop), dies or
-- leaves. Every `segment` studs it adds a part to workspace.ModWalls:
-- invisible, no collision, no queries (shots and players pass through), with
-- attributes clients dress as fire (Util/WallFx):
--   WallId, Index, OwnerId, TeamId, BuiltAt (server time)
--   ExpiresAt   set on every piece when the wall is finished (server time)
-- Every `tick` from the start, everyone standing in a piece burns: enemies
-- full `dps`, the caster's team Config/Mods FRIENDLY_FIRE of it, the caster
-- not at all (BurningUntil + BurnKind "Firewall" for the client effect).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Mods)
local Firewall = require(Shared.Mods.Firewall)
local ModTypes = require(Shared.Mods.Types)
local Target = require(Shared.Mods.Blocks.Target)
local Teams = require(Shared.Mods.Teams)

local ModWalls = {}

local GROUND_ABOVE = 8 -- a new point looks for the floor from this high...
local GROUND_BELOW = 30 -- ...down to this far
local START_AHEAD = 1.5 -- studs in front of the feet the wall starts
local BODY_MARGIN = 1 -- a body this far out of a piece's thickness is in it
local FADE = 0.5 -- the pieces stay this long after ExpiresAt (the flames sink)

export type Hooks = {
	-- Damage to `victim` (the caster's ModService ctx.damage).
	damage: (victim: Model, amount: number, at: Vector3) -> (),
	-- Where the caster looks now (nil: fall back to the streamed look).
	look: () -> Vector3?,
	-- The wall stopped growing (the hold can end).
	built: () -> (),
}

type Wall = {
	id: number,
	owner: Player,
	team: number?,
	stats: ModTypes.Stats,
	hooks: Hooks,
	heading: Vector3, -- flat unit
	straight: boolean,
	streamed: Vector3?, -- the client's last ModSteer look
	head: Vector3, -- the growing end (on the floor)
	lastPoint: Vector3, -- where the newest piece ends
	length: number,
	building: boolean,
	pieces: { BasePart },
	nextTick: number, -- os.clock()
	expiresAt: number?, -- os.clock(), once built
}

local walls: { Wall } = {}
local nextId = 0

local function folder(): Folder
	local existing = workspace:FindFirstChild("ModWalls")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "ModWalls"
	f.Parent = workspace
	return f
end

-- The floor under a point: world parts only (no bodies, effects or walls).
local function floorParams(): RaycastParams
	local exclude: { Instance } = { folder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "Effects", "ModFx", "MollyFx" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function snap(at: Vector3, params: RaycastParams): Vector3
	local hit = workspace:Raycast(
		Vector3.new(at.X, at.Y + GROUND_ABOVE, at.Z),
		Vector3.new(0, -(GROUND_ABOVE + GROUND_BELOW), 0),
		params
	)
	return if hit then hit.Position else at
end

-- A piece of wall from `a` to `b` (both on the floor).
local function addPiece(wall: Wall, a: Vector3, b: Vector3)
	local stats = wall.stats
	local flat = (b - a) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.05 then
		return
	end
	local floorY = math.min(a.Y, b.Y)
	local mid = Vector3.new((a.X + b.X) / 2, floorY + stats.height / 2, (a.Z + b.Z) / 2)
	local part = Instance.new("Part")
	part.Name = "FirewallPiece"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(stats.thickness, stats.height, flat.Magnitude)
	part.CFrame = CFrame.lookAt(mid, mid + flat.Unit)
	part:SetAttribute("WallId", wall.id)
	part:SetAttribute("Index", #wall.pieces + 1)
	part:SetAttribute("OwnerId", wall.owner.UserId)
	part:SetAttribute("TeamId", wall.team)
	part:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
	part.Parent = folder()
	table.insert(wall.pieces, part)
end

local function finish(wall: Wall)
	if not wall.building then
		return
	end
	wall.building = false
	-- The last bit since the newest piece.
	addPiece(wall, wall.lastPoint, wall.head)
	local duration = wall.stats.duration
	wall.expiresAt = os.clock() + duration
	local expires = workspace:GetServerTimeNow() + duration
	for _, p in wall.pieces do
		p:SetAttribute("ExpiresAt", expires)
	end
	task.spawn(wall.hooks.built)
end

-- Turns `from` toward `to` (flat units) by at most `maxAngle` radians.
local function turnToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxAngle or angle < 1e-4 then
		return to
	end
	local side = if from:Cross(to).Y >= 0 then 1 else -1
	return (CFrame.Angles(0, side * maxAngle, 0):VectorToWorldSpace(from)).Unit
end

local function grow(wall: Wall, dt: number, params: RaycastParams)
	local stats = wall.stats
	if not wall.straight then
		local look = wall.hooks.look() or wall.streamed
		local flat = if look then look * Vector3.new(1, 0, 1) else Vector3.zero
		if flat.Magnitude > 0.05 then
			wall.heading = turnToward(wall.heading, flat.Unit, math.rad(stats.turnRate) * dt)
		end
	end
	local step = math.min(stats.speed * dt, stats.maxLength - wall.length)
	if step <= 0 then
		finish(wall)
		return
	end
	wall.head = snap(wall.head + wall.heading * step, params)
	wall.length += step
	local flatGap = ((wall.head - wall.lastPoint) * Vector3.new(1, 0, 1)).Magnitude
	if flatGap >= stats.segment then
		addPiece(wall, wall.lastPoint, wall.head)
		wall.lastPoint = wall.head
	end
	if wall.length >= stats.maxLength - 1e-3 then
		finish(wall)
	end
end

local function burn(wall: Wall)
	local stats = wall.stats
	local amount = stats.dps * stats.tick
	local untilT = workspace:GetServerTimeNow() + stats.tick + 0.1
	for _, model in Target.combatants() do
		if not Target.alive(model) or model == wall.owner.Character then
			continue -- you're immune to your own wall
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		local inside = false
		for _, piece in wall.pieces do
			if Firewall.inside(piece, root.Position, BODY_MARGIN) then
				inside = true
				break
			end
		end
		if inside then
			local ally = Teams.isAlly(wall.owner, model)
			wall.hooks.damage(
				model,
				if ally then amount * Config.FRIENDLY_FIRE else amount,
				root.Position
			)
			model:SetAttribute("BurningUntil", untilT)
			model:SetAttribute("BurnKind", "Firewall")
		end
	end
end

local function remove(index: number)
	local wall = walls[index]
	table.remove(walls, index)
	for _, p in wall.pieces do
		p:Destroy()
	end
end

-- Starts a wall for `owner` from their feet. One building wall per owner:
-- a new one finishes the old.
function ModWalls.build(
	owner: Player,
	root: BasePart,
	stats: ModTypes.Stats,
	spec: ModTypes.WallSpec,
	hooks: Hooks
)
	for _, w in walls do
		if w.owner == owner and w.building then
			finish(w)
		end
	end
	nextId += 1
	local params = floorParams()
	local feet = snap(root.Position + spec.heading * START_AHEAD, params)
	local wall: Wall = {
		id = nextId,
		owner = owner,
		team = Teams.of(owner),
		stats = stats,
		hooks = hooks,
		heading = spec.heading,
		straight = spec.straight,
		streamed = nil,
		head = feet,
		lastPoint = feet,
		length = 0,
		building = true,
		pieces = {},
		nextTick = os.clock(),
		expiresAt = nil,
	}
	table.insert(walls, wall)
end

-- The caster's streamed look while steering (nil: stop building here).
function ModWalls.steer(owner: Player, look: Vector3?)
	for _, w in walls do
		if w.owner == owner and w.building then
			if look then
				w.streamed = look
			else
				finish(w)
			end
		end
	end
end

function ModWalls.isBuilding(owner: Player): boolean
	for _, w in walls do
		if w.owner == owner and w.building then
			return true
		end
	end
	return false
end

-- The caster died: their wall stops growing (it keeps burning).
function ModWalls.stop(owner: Player)
	ModWalls.steer(owner, nil)
end

local function step(dt: number)
	if #walls == 0 then
		return
	end
	local now = os.clock()
	local params: RaycastParams? = nil
	for i = #walls, 1, -1 do
		local wall = walls[i]
		if wall.owner.Parent ~= Players then
			remove(i) -- the caster left: their wall goes
			continue
		end
		if wall.building then
			params = params or floorParams()
			grow(wall, dt, params :: RaycastParams)
		end
		local expiresAt = wall.expiresAt
		if expiresAt and now >= expiresAt + FADE then
			remove(i)
			continue
		end
		if now >= wall.nextTick and (not expiresAt or now < expiresAt) then
			wall.nextTick += wall.stats.tick
			burn(wall)
		end
	end
end

function ModWalls.init()
	folder()
end

function ModWalls.start()
	RunService.Heartbeat:Connect(step)
end

return ModWalls
