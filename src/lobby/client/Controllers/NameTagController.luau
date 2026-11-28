--!strict
-- Name tags over every player in the lobby (vault/02 Art/UI Name Tags.md): the equipped title in gold, a level
-- badge, the display name, the win streak (flame + number, only when > 0) and the @username under it.
-- The template is Studio UI (PlayerScripts.UI.Templates.Lobby.NameTag, a BillboardGui; built by
-- tools/studio/BuildNameTag.luau). Each player gets ONE client-side copy for as long as they're in the server,
-- kept in a local folder in Workspace and pointed (Adornee) at their current HumanoidRootPart, so respawns only
-- move it and nothing replicates. Shown only while both you and they are in the lobby (Shared/PlayZone: not in
-- the Range or a match), never over your own head in first person. While a tag shows, that player's Roblox name
-- is hidden on this client and put back when it goes. Size follows distance through the template's UIScale
-- (RefDistance / MinScale / MaxScale attributes), so the art stays crisp pixel UI.

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
local HEAD_HEIGHT = 1.5 -- head centre above the root part
local WATCHED: { [string]: boolean } = { Level = true, WinStreak = true, Title = true }

type Tag = {
	gui: BillboardGui,
	scale: UIScale,
	username: GuiObject?, -- the @name line: close up only
	root: BasePart?, -- the current character's HumanoidRootPart
	humanoid: Humanoid?,
	shownName: Enum.HumanoidDisplayDistanceType?, -- the Roblox name setting we replaced
	conns: { RBXScriptConnection },
	charConns: { RBXScriptConnection },
}

local tags: { [Player]: Tag } = {}
local template: BillboardGui? = nil
local folder: Folder? = nil
-- template attributes: drawn 1:1 at RefDistance studs; size = (RefDistance / distance) ^ Falloff, clamped to
-- MinScale..MaxScale (Falloff < 1 shrinks slower than the world, so far tags stay readable); the @username
-- shows only at DetailScale or bigger
local refDistance, minScale, maxScale, falloff, detailScale = 14, 0.55, 1.6, 0.7, 0.8

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

-- a label and its drop shadow (a darker copy behind it, named Shadow) carry the same text
local function setText(gui: Instance, path: { string }, text: string)
	local label = find(gui, path)
	if label and label:IsA("TextLabel") then
		label.Text = text
		local shadow = label:FindFirstChild("Shadow")
		if shadow and shadow:IsA("TextLabel") then
			shadow.Text = text
		end
	end
end

local function setVisible(gui: Instance, path: { string }, visible: boolean)
	local item = find(gui, path)
	if item and item:IsA("GuiObject") then
		item.Visible = visible
	end
end

local function fill(p: Player, tag: Tag)
	local gui = tag.gui
	setText(gui, { "Root", "Row", "PlayerName" }, p.DisplayName)
	setText(gui, { "Root", "Username" }, "@" .. p.Name)
	setText(gui, { "Root", "Row", "Level", "Value" }, tostring(math.floor(numberOf(p, "Level", 1))))
	local streak = math.floor(numberOf(p, "WinStreak", 0))
	setText(gui, { "Root", "Row", "Streak", "Value" }, tostring(streak))
	setVisible(gui, { "Root", "Row", "Streak" }, streak > 0)
	local title = PlayerData.title(p)
	setText(gui, { "Root", "Title" }, title or "")
	setVisible(gui, { "Root", "Title" }, title ~= nil)
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
	tag.root = nil
	tag.humanoid = nil
	tag.gui.Enabled = false
	tag.gui.Adornee = nil
end

local function bindCharacter(p: Player, tag: Tag, character: Model)
	clearCharacter(tag)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if tags[p] ~= tag or p.Character ~= character then
			return
		end
		if root and root:IsA("BasePart") then
			tag.root = root
			tag.gui.Adornee = root
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
	tag.gui:Destroy()
end

local function add(p: Player)
	if tags[p] or not (template and folder) then
		return
	end
	local gui = template:Clone()
	gui.Name = p.Name
	gui.Enabled = false
	gui.Adornee = nil
	gui.Archivable = false -- never copied (win cutscene, replays, body clones)
	-- on Root (anchored bottom-centre), so the tag grows up from over the head, never down into it
	local root = gui:FindFirstChild("Root")
	local scale = gui:FindFirstChildWhichIsA("UIScale", true) or Instance.new("UIScale")
	scale.Parent = root or gui
	gui.Parent = folder
	local username = gui:FindFirstChild("Username", true)
	local tag: Tag = {
		gui = gui,
		scale = scale,
		username = if username and username:IsA("GuiObject") then username else nil,
		conns = {},
		charConns = {},
	}
	tags[p] = tag
	fill(p, tag)
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

-- every frame: who shows a tag, and how big
local function step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local meInLobby = PlayZone.get(player) == "Lobby"
	for p, tag in tags do
		local root = tag.root
		local gui = tag.gui
		local show = meInLobby and root ~= nil and root.Parent ~= nil and PlayZone.get(p) == "Lobby"
		local dist = if root then (root.Position - camPos).Magnitude else math.huge
		if show and p == player and root then
			local headPos = root.Position + Vector3.new(0, HEAD_HEIGHT, 0)
			if (headPos - camPos).Magnitude < FIRST_PERSON then
				show = false
			end
		end
		if show then
			local size = math.clamp((refDistance / math.max(dist, 1)) ^ falloff, minScale, maxScale)
			tag.scale.Scale = size
			if tag.username then
				tag.username.Visible = size >= detailScale
			end
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
	falloff, detailScale = attr("Falloff", falloff), attr("DetailScale", detailScale)

	-- made on this client, so it never replicates; the tags live here between respawns
	local f = Instance.new("Folder")
	f.Name = "NameTags"
	f.Archivable = false
	f.Parent = Workspace
	folder = f

	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(remove)
	for _, p in Players:GetPlayers() do
		add(p)
	end
	RunService.RenderStepped:Connect(step)
end

return NameTagController
