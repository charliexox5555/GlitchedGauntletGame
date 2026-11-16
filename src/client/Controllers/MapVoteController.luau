--!strict
-- The map vote screen (vault/02 Art/UI Match Overhaul.md): fills the
-- Studio-built StarterGui.MapVote (backup tools/studio/BuildMapVote.luau)
-- from MatchState while the Phase is "Vote" (MapVoteService):
--   * one card per option ("VoteOptions": Random first, then the maps), the
--     map's name and team sizes from Config/Match MAPS, its picture when the
--     entry has an `image`;
--   * every player's vote is their server-set "MapVote" attribute: their
--     head goes on that card, ringed in their team colour, and each card shows
--     its chance (its share of the votes, like RIVALS' "Chance" vote);
--   * clicking a card sends MapVote (the server checks it); your card's foot
--     turns white;
--   * "VoteChosen" set: the picked card pops, the others dim, the title
--     names the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)

local MapVoteController = {}

local DESIGN = Vector2.new(1920, 1080)
local ATTRIBUTE = "MapVote"
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromHex("141418")
local MUTED = Color3.fromHex("A9A9B0")
local FOOT = Color3.fromHex("2A2A31")
local URGENT = Color3.fromHex("FF3232")
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

local player = Players.LocalPlayer
local gui: ScreenGui
local cards: Frame
local title: TextLabel
local sub: TextLabel
local seconds: TextLabel
local ring: UIStroke
local templates: Instance

type Entry = { slot: Frame, card: TextButton, pop: UIScale, name: string }
local entries: { [string]: Entry } = {}
local order: { string } = {}
local shownChosen = ""

local function child(parent: Instance, name: string): Instance
	return parent:WaitForChild(name)
end

local function entryFor(id: string): Config.MapEntry?
	for _, e in Config.MAPS do
		if e.id == id then
			return e
		end
	end
	return nil
end

local function sizeText(e: Config.MapEntry?): string
	if not e then
		return "ANY MAP"
	end
	if e.minTeam == e.maxTeam then
		return string.format("%dV%d", e.minTeam, e.minTeam)
	end
	return string.format("%dV%d – %dV%d", e.minTeam, e.minTeam, e.maxTeam, e.maxTeam)
end

local function displayName(id: string): string
	if id == Config.VOTE.random then
		return "RANDOM"
	end
	local e = entryFor(id)
	local name = if e and e.name then e.name else (id:gsub("(%l)(%u)", "%1 %2"))
	return string.upper(name)
end

local function myVote(): string?
	local v = player:GetAttribute(ATTRIBUTE)
	return if typeof(v) == "string" then v else nil
end

-- Heads, chances and your pick, from every player's MapVote attribute.
local function refreshVotes()
	local byOption: { [string]: { Player } } = {}
	local total = 0
	for _, p in Players:GetPlayers() do
		local v = p:GetAttribute(ATTRIBUTE)
		if typeof(v) == "string" and entries[v] then
			byOption[v] = byOption[v] or {}
			table.insert(byOption[v], p)
			total += 1
		end
	end
	local mine = myVote()
	for id, e in entries do
		local voters = child(e.card, "Voters")
		for _, c in voters:GetChildren() do
			if c:IsA("ImageLabel") then
				c:Destroy()
			end
		end
		local list = byOption[id] or {}
		for i, p in list do
			local h = (child(templates, "Head") :: ImageLabel):Clone()
			h.LayoutOrder = i
			h.Image = string.format(HEADSHOT, math.max(p.UserId, 1))
			local r = h:FindFirstChild("Ring")
			if r and r:IsA("UIStroke") then
				r.Color = TeamColor.forTeam(Teams.of(p))
			end
			h.Parent = voters
		end
		local chance = child(e.card, "Chance") :: TextLabel
		chance.Text = if total > 0 and #list > 0
			then string.format("%d%%", math.floor(#list / total * 100 + 0.5))
			else ""
		local foot = child(e.card, "Foot") :: Frame
		local on = id == mine
		local fill = if on then WHITE else FOOT
		UiMotion.tween(foot, 0.16, { BackgroundColor3 = fill })
		local square = foot:FindFirstChild("Square")
		if square then
			UiMotion.tween(square, 0.16, { BackgroundColor3 = fill })
		end
		local name = child(foot, "Name") :: TextLabel
		local size = child(foot, "Size") :: TextLabel
		UiMotion.tween(name, 0.16, { TextColor3 = if on then INK else WHITE })
		UiMotion.tween(size, 0.16, { TextColor3 = if on then INK else MUTED })
		local stroke = name:FindFirstChild("Outline")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Enabled = not on
		end
		if not e.pop:GetAttribute("Hover") then
			UiMotion.rest(e.pop, if on then 1.04 else 1)
		end
	end
end

local function clearCards()
	for _, e in entries do
		e.slot:Destroy()
	end
	table.clear(entries)
	table.clear(order)
end

local function buildCards()
	clearCards()
	local raw = MatchState.get("VoteOptions")
	if typeof(raw) ~= "string" or raw == "" then
		return
	end
	for i, id in string.split(raw, ",") do
		local slot = (child(templates, "Slot") :: Frame):Clone()
		slot.Name = id
		slot.LayoutOrder = i
		local card = child(slot, "Card") :: TextButton
		local pop = child(card, "Pop") :: UIScale
		local e = entryFor(id)
		local foot = child(card, "Foot");
		(child(foot, "Name") :: TextLabel).Text = displayName(id);
		(child(foot, "Size") :: TextLabel).Text = sizeText(e)
		local picture = child(card, "Picture") :: ImageLabel
		picture.Image = e and e.image or ""
		picture.Visible = picture.Image ~= ""
		local glyph = child(card, "Glyph") :: TextLabel
		glyph.Visible = id == Config.VOTE.random
		UiMotion.button(card, pop, function()
			if shownChosen == "" then
				Net.event("MapVote"):FireServer(id)
			end
		end, {
			card = true,
			enabled = function()
				return shownChosen == ""
			end,
			onHover = function(on)
				pop:SetAttribute("Hover", on)
			end,
		})
		slot.Parent = cards
		entries[id] = { slot = slot, card = card, pop = pop, name = id }
		table.insert(order, id)
		UiMotion.popIn(pop, 0.04 * (i - 1), 0.85)
	end
	-- the grid sits centred in the space under the header
	local rows = math.ceil(#order / 3)
	cards.Size = UDim2.fromOffset(cards.Size.X.Offset, rows * 216 + (rows - 1) * 24)
	cards.Position = UDim2.fromOffset(DESIGN.X / 2, 290 + (3 - rows) * 60)
	refreshVotes()
end

local function showChosen()
	local chosen = MatchState.get("VoteChosen")
	chosen = if typeof(chosen) == "string" then chosen else ""
	if chosen == shownChosen then
		return
	end
	shownChosen = chosen
	if chosen == "" then
		return
	end
	title.Text = displayName(chosen)
	sub.Text = "LOADING MAP"
	for id, e in entries do
		local won = id == chosen
		UiMotion.rest(e.pop, if won then 1.08 else 0.94)
		UiMotion.tween(
			child(e.card, "Dim"),
			0.3,
			{ BackgroundTransparency = if won then 1 else 0.5 }
		)
	end
	if not entries[chosen] then
		-- Random drew this map: the Random card wins on screen
		local r = entries[Config.VOTE.random]
		if r then
			UiMotion.rest(r.pop, 1.08)
			UiMotion.tween(child(r.card, "Dim"), 0.3, { BackgroundTransparency = 1 })
		end
	end
end

local function matchLine(): string
	local size = MatchState.get("VoteTeamSize")
	local mode = if typeof(size) == "number" then string.format("%dV%d  ·  ", size, size) else ""
	return string.format("%sFIRST TO %d", mode, Config.ROUNDS_TO_WIN)
end

local function open(on: boolean)
	if gui.Enabled == on then
		return
	end
	gui.Enabled = on
	if on then
		shownChosen = ""
		title.Text = "VOTE FOR A MAP"
		sub.Text = matchLine()
		buildCards()
		showChosen()
	else
		clearCards()
	end
end

local function tick()
	local endsAt = MatchState.get("EndsAt")
	local left = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
	local s = math.max(0, math.ceil(left))
	seconds.Text = tostring(s)
	local urgent = shownChosen == "" and s <= 3
	seconds.TextColor3 = if urgent then URGENT else WHITE
	ring.Color = if urgent then URGENT else WHITE
	ring.Transparency = if shownChosen ~= "" then 1 else 0.15
	seconds.Visible = shownChosen == ""
end

function MapVoteController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	-- The vote runs before anyone spawns, and StarterGui is only copied into
	-- PlayerGui on a spawn: take our own copy now, and drop the one Roblox
	-- adds at the first spawn.
	local source = StarterGui:WaitForChild("MapVote") :: ScreenGui
	gui = source:Clone()
	gui.Name = "MapVoteLive"
	gui.Parent = playerGui
	local function dropCopy(c: Instance)
		if c.Name == "MapVote" and c:IsA("ScreenGui") then
			task.defer(c.Destroy, c)
		end
	end
	for _, c in playerGui:GetChildren() do
		dropCopy(c)
	end
	playerGui.ChildAdded:Connect(dropCopy)
	local folder = ReplicatedStorage:WaitForChild("UiTemplates")
	templates = folder:WaitForChild("MapVote")
	local canvas = child(gui, "Canvas") :: Frame
	local fit = child(canvas, "Fit") :: UIScale
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.35, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	cards = child(canvas, "Cards") :: Frame
	local head = child(canvas, "Head")
	title = child(head, "Title") :: TextLabel
	sub = child(head, "Sub") :: TextLabel
	local clock = child(head, "Clock")
	seconds = child(clock, "Seconds") :: TextLabel
	ring = child(clock, "Ring") :: UIStroke

	local function refresh()
		local on = MatchState.phase() == "Vote"
		open(on)
		if on then
			showChosen()
		end
	end
	MatchState.changed("Phase"):Connect(refresh)
	MatchState.changed("VoteOptions"):Connect(function()
		if gui.Enabled then
			buildCards()
		end
	end)
	MatchState.changed("VoteChosen"):Connect(showChosen)
	local function watch(p: Player)
		p:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
			if gui.Enabled then
				refreshVotes()
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		if gui.Enabled then
			task.defer(refreshVotes)
		end
	end)
	refresh()
	task.spawn(function()
		while true do
			if gui.Enabled then
				tick()
			end
			task.wait(0.1)
		end
	end)
end

return MapVoteController
