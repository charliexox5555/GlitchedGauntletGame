--!strict
-- Name tags over every player in the lobby (vault/05 Production/Handoff - Battle Pass Build 2026-11-27.md, A):
-- level, the equipped title in gold and the win streak, like the lobby player list (Util/LobbyHudView).
-- The template is Studio UI (PlayerScripts.UI.Templates.Lobby.NameTag, a BillboardGui); each character gets its
-- own client-side copy parented to its head (made on this client, so nothing replicates; it goes with the
-- character, and PlayerGui clean-ups on respawn can't take it). Shown only while both you and they
-- are in the lobby (Shared/PlayZone: not in the Range or a match), never over your own head in first person.
-- While a tag shows, that player's Roblox name is hidden on this client and put back when it goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)

local NameTagController = {}

local player = Players.LocalPlayer
local FIRST_PERSON = 1.5 -- studs from camera to head: you're in first person
local WATCHED: { [string]: boolean } = { Level = true, WinStreak = true, Title = true }

type Tag = {
	gui: BillboardGui?, -- the current character's copy
	scale: UIScale?,
	head: BasePart?,
	humanoid: Humanoid?,
	shownName: Enum.HumanoidDisplayDistanceType?, -- the Roblox name setting we replaced
	conns: { RBXScriptConnection },
	charConns: { RBXScriptConnection },
}

local tags: { [Player]: Tag } = {}
local template: BillboardGui? = nil
local refDistance, minScale, maxScale = 18, 0.6, 1

local function numberOf(p: Player, name: string, default: number): number
	local v = StateValues.get(p, name)
	return if typeof(v) == "number" and v == v then v else default
end

local function find(parent: Instance, path: { string }): Instance?
	local at: Instance? = parent
	for _, name in path do
		at = at and at:FindFirstChild(name)
	end
	return at
end

local function setText(gui: Instance, path: { string }, text: string)
	local label = find(gui, path)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function fill(p: Player, tag: Tag)
	local gui = tag.gui
	if not gui then
		return
	end
	setText(gui, { "Root", "Row", "PlayerName" }, string.upper(p.DisplayName))
	setText(gui, { "Root", "Row", "Level", "Value" }, tostring(math.floor(numberOf(p, "Level", 1))))
	local streak = math.floor(numberOf(p, "WinStreak", 0))
	setText(gui, { "Root", "Row", "Streak", "Value" }, tostring(streak))
	local streakChip = find(gui, { "Root", "Row", "Streak" })
	if streakChip and streakChip:IsA("GuiObject") then
		streakChip.Visible = streak > 0
	end
	local title = PlayerData.title(p)
	local titleLabel = find(gui, { "Root", "Title" })
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Visible = title ~= nil
		titleLabel.Text = title or ""
	end
end

-- puts the Roblox name back (when the tag hides or goes)
local function restoreName(tag: Tag)
	if tag.humanoid and tag.shownName then
		tag.humanoid.DisplayDistanceType = tag.shownName
	end
	tag.shownName = nil
end

local function clearCharacter(tag: Tag)
	restoreName(tag)
	for _, c in tag.charConns do
		c:Disconnect()
	end
	table.clear(tag.charConns)
	tag.head = nil
	tag.humanoid = nil
	if tag.gui then
		tag.gui:Destroy()
	end
	tag.gui = nil
	tag.scale = nil
end

local function bindCharacter(p: Player, tag: Tag, character: Model)
	clearCharacter(tag)
	task.spawn(function()
		local head = character:WaitForChild("Head", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if tags[p] ~= tag or p.Character ~= character then
			return
		end
		if head and head:IsA("BasePart") and template then
			local gui = template:Clone()
			gui.Name = "NameTag"
			gui.Enabled = false
			gui.Adornee = head
			gui.Archivable = false -- never copied with the body (win cutscene, replays, body clones)
			local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = gui
			gui.Parent = head
			tag.gui = gui
			tag.scale = scale
			tag.head = head
			fill(p, tag)
		end
		if humanoid and humanoid:IsA("Humanoid") then
			tag.humanoid = humanoid
		end
	end)
end

local function remove(p: Player)
	local tag = tags[p]
	if not tag then
		return
	end
	tags[p] = nil
	clearCharacter(tag)
	for _, c in tag.conns do
		c:Disconnect()
	end
end

local function add(p: Player)
	if tags[p] or not template then
		return
	end
	local tag: Tag = { conns = {}, charConns = {} }
	tags[p] = tag
	table.insert(
		tag.conns,
		StateValues.anyChanged(p):Connect(function(name: string)
			if WATCHED[name] then
				fill(p, tag)
			end
		end)
	)
	table.insert(
		tag.conns,
		p:GetPropertyChangedSignal("DisplayName"):Connect(function()
			fill(p, tag)
		end)
	)
	table.insert(
		tag.conns,
		p.CharacterAdded:Connect(function(character)
			bindCharacter(p, tag, character)
		end)
	)
	table.insert(
		tag.conns,
		p.CharacterRemoving:Connect(function()
			clearCharacter(tag)
		end)
	)
	if p.Character then
		bindCharacter(p, tag, p.Character)
	end
end

-- every frame: who shows a tag, and how big (a distance-scaled UIScale keeps the plate art crisp)
local function step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local meInLobby = PlayZone.get(player) == "Lobby"
	for p, tag in tags do
		local head = tag.head
		local gui, scale = tag.gui, tag.scale
		if not (gui and scale) then
			continue
		end
		local show = meInLobby and head ~= nil and head.Parent ~= nil and PlayZone.get(p) == "Lobby"
		local dist = if head then (head.Position - camPos).Magnitude else math.huge
		if show and p == player and dist < FIRST_PERSON then
			show = false
		end
		if show then
			scale.Scale = math.clamp(refDistance / math.max(dist, 1), minScale, maxScale)
			if tag.humanoid and tag.shownName == nil then
				tag.shownName = tag.humanoid.DisplayDistanceType
				tag.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		else
			restoreName(tag)
		end
		if gui.Enabled ~= show then
			gui.Enabled = show
		end
	end
end

function NameTagController.start()
	local lobby = UiRoot.templates():WaitForChild("Lobby", 15)
	local found = lobby and lobby:WaitForChild("NameTag", 15)
	if not (found and found:IsA("BillboardGui")) then
		warn("[NameTag] UI.Templates.Lobby.NameTag missing")
		return
	end
	template = found
	local function attr(name: string, default: number): number
		local v = found:GetAttribute(name)
		return if typeof(v) == "number" and v == v and v > 0 then v else default
	end
	refDistance, minScale, maxScale =
		attr("RefDistance", refDistance), attr("MinScale", minScale), attr("MaxScale", maxScale)

	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(remove)
	for _, p in Players:GetPlayers() do
		add(p)
	end
	RunService.RenderStepped:Connect(step)
end

return NameTagController
