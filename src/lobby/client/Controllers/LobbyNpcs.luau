--!strict
-- Lobby NPCs (owner 2026-11-16: "an NPC in there that looks good", like RIVALS' vendors): any Model tagged
-- `LobbyNPC` with a Humanoid plays a looping idle on this client. The rigs are built with the lobby
-- (tools/studio/lobby_v4/Build_V4.luau → M.npcs) and anchored; nothing here touches the server.

local CollectionService = game:GetService("CollectionService")

local LobbyNpcs = {}

local TAG = "LobbyNPC"
-- Roblox's own R15 idle (public, playable in any experience). An attribute `IdleAnim` on the model overrides it.
local DEFAULT_IDLE = "rbxassetid://507766388"

local playing: { [Instance]: AnimationTrack } = {}
local watchers: { [Instance]: RBXScriptConnection } = {}

local function start(model: Instance)
	if playing[model] or not model:IsA("Model") then
		return
	end
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildWhichIsA("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = humanoid
		animator = a
	end
	local anim = Instance.new("Animation")
	local override = model:GetAttribute("IdleAnim")
	anim.AnimationId = if typeof(override) == "string" and override ~= ""
		then override
		else DEFAULT_IDLE
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play(0.3)
		playing[model] = track
	end
end

local function track(model: Instance)
	start(model)
	-- StreamingEnabled: the humanoid can arrive after the tag
	if not watchers[model] then
		watchers[model] = model.DescendantAdded:Connect(function(d)
			if d:IsA("Humanoid") then
				start(model)
			end
		end)
	end
end

local function untrack(model: Instance)
	local t = playing[model]
	if t then
		t:Stop(0)
		t:Destroy()
		playing[model] = nil
	end
	local w = watchers[model]
	if w then
		w:Disconnect()
		watchers[model] = nil
	end
end

function LobbyNpcs.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	for _, m in CollectionService:GetTagged(TAG) do
		track(m)
	end
end

return LobbyNpcs
