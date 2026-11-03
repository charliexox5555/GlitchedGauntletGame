--!strict
-- Dash's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md, Dash.md → Upgrades). Dash is predicted, so there are no ModFx
-- events: everything keys on the simulation's character attributes
-- (Mods/Dash), read for every player each frame.
--   A2/A3 Long Dash: numbers only, nothing to draw.
--   B2/B3 Ghost, G3's cloak: how see-through each dasher is (DashGhost).
--   G2/G3 Desync: the decoy, built locally on every client (DashDecoy).

local Players = game:GetService("Players")

local DashDecoy = require(script.Parent.DashDecoy)
local DashGhost = require(script.Parent.DashGhost)
local TeamColor = require(script.Parent.Parent.TeamColor)
local ModVfx = require(script.Parent.Parent.ModVfx)
local Types = require(script.Parent.Types)

local handler: Types.Handler = {}

-- The last DashStart seen per character (a new character is first only
-- remembered, so an old dash isn't replayed).
local seen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function number(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function onDash(owner: Player, character: Model, start: number)
	local now = time()
	local root = character:FindFirstChild("HumanoidRootPart")
	-- Ghost: a team-tinted pop as the dodge window opens.
	if number(character, "DashDodgeUntil") > now and root and root:IsA("BasePart") then
		ModVfx.burst(root.Position, TeamColor.forOwner(owner), 10, "Sparkle")
	end
	-- Desync: the decoy.
	local untilT = number(character, "DashDecoyUntil")
	if untilT <= now then
		return
	end
	local from = character:GetAttribute("DashDecoyFrom")
	local velocity = character:GetAttribute("DashDecoyVelocity")
	local stats = DashGhost.statsOf(owner)
	if typeof(from) ~= "Vector3" or typeof(velocity) ~= "Vector3" or not stats then
		return
	end
	DashDecoy.spawn({
		owner = owner,
		character = character,
		from = from,
		yaw = number(character, "DashDecoyYaw"),
		velocity = velocity,
		start = start,
		untilT = untilT,
		fires = character:GetAttribute("DashDecoyFires") == true,
		stats = stats,
	})
end

handler.step = function(dt: number)
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		if not character then
			continue
		end
		local start = number(character, "DashStart")
		local last = seen[character]
		seen[character] = math.max(start, last or 0)
		-- (A re-simulated start a few ms off isn't a new dash.)
		if last and start > last + 0.05 then
			onDash(owner, character, start)
		end
	end
	DashDecoy.step(dt)
	DashGhost.step()
end

return handler
