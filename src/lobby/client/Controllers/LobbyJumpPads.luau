--!strict
-- The range's jump pads (owner 2026-11-21). Parts tagged `RangeJumpPad` (the trigger over each modelled pad, built by
-- tools/studio/lobby_v5/BuildRangeV3.luau) launch the local character: `Launch` studs/s up and a `PushX` / `PushZ`
-- nudge toward the roof it serves. Client only, like the rest of the movement (Workspace.AuthorityMode = Automatic,
-- vault/04 Tech/Architecture.md → Authority mode); a lobby toy, nothing is sent to the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LobbyJumpPads = {}

local TAG = "RangeJumpPad"
local COOLDOWN = 0.6 -- seconds before the same character can be launched again

local lastLaunch = 0
local connections: { [Instance]: RBXScriptConnection } = {}

local function num(inst: Instance, key: string, default: number): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" and v == v and math.abs(v) < 1000 then v else default
end

local function launch(pad: BasePart, hit: BasePart)
	local character = Players.LocalPlayer.Character
	if not character or not hit:IsDescendantOf(character) then
		return
	end
	local now = os.clock()
	if now - lastLaunch < COOLDOWN then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	lastLaunch = now
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity =
		Vector3.new(num(pad, "PushX", 0), num(pad, "Launch", 100), num(pad, "PushZ", 0))
end

local function hook(inst: Instance)
	if not inst:IsA("BasePart") or connections[inst] then
		return
	end
	local pad = inst :: BasePart
	connections[inst] = pad.Touched:Connect(function(hit: BasePart)
		launch(pad, hit)
	end)
end

local function unhook(inst: Instance)
	local c = connections[inst]
	if c then
		c:Disconnect()
		connections[inst] = nil
	end
end

function LobbyJumpPads.start()
	for _, inst in CollectionService:GetTagged(TAG) do
		hook(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unhook)
end

return LobbyJumpPads
