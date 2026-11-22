--!strict
-- The end of a match (vault/05 Production/Match Structure Revamp.md, phase
-- D): the winner cutscene (Util/WinCutscene, vault/02 Art/Win Cutscene.md:
-- copies of the winning side on the map's stage, several keyed shots cut to
-- the ending song, held on a low final pose) and then the post-match screen:
-- the Studio-built MatchEndScreen (Util/MatchEndScreen, every device), filled
-- from the results. The server decides everything (Services/MatchEndService);
-- the buttons only ask.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Workspace = game:GetService("Workspace")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local DraftController = require(script.Parent.DraftController)
local ReplayController = require(script.Parent.ReplayController)
local SpectateController = require(script.Parent.SpectateController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local MatchEndScreen = require(script.Parent.Parent.Util.MatchEndScreen)
local UiSound = require(script.Parent.Parent.Util.UiSound)
local WinCutscene = require(script.Parent.Parent.Util.WinCutscene)

local MatchEndController = {}

local player = Players.LocalPlayer

type Line = {
	id: string,
	name: string,
	userId: number?,
	portraitUserId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	mvp: boolean?,
	weapon: string?, -- the gun they got the most eliminations with (StatsService)
}

type Results = {
	winner: number,
	lines: { Line },
	score1: number,
	score2: number,
	rounds: { string },
}

local summary: { Line } = {}
local active = false
local screenUp = false -- the results screen is in (after the cutscene)
local hidden: { Instance } = {}
local hiddenGuis: { ScreenGui } = {}
local picked: string? = nil

-- Helpers ---------------------------------------------------------------------------

local function hideLive()
	for _, body in Fighters.bodies() do
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
				table.insert(hidden, d)
			end
		end
	end
	for _, copy in CollectionService:GetTagged(DeathFxController.COPY_TAG) do
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end

-- The screen (the Studio-built Util/MatchEndScreen) ----------------------------

local BOT_HEAD = "rbxassetid://119185654291939"

local function lineOf(body: Model): Line?
	local owner = Players:GetPlayerFromCharacter(body)
	for _, line in summary do
		if (owner and line.id == "p" .. owner.UserId) or (not owner and line.name == body.Name) then
			return line
		end
	end
	return nil
end

-- The winning side's bodies, best performing first (owner 2026-11-20: the
-- cutscene's slots go in order of performance, slot 1 = the lead in the
-- middle). The MVP first, then eliminations, damage dealt, fewer deaths,
-- assists; still level: the last one standing, then the name.
local function rank(line: Line?): { number }
	if not line then
		return { 0, 0, 0, 0, 0 }
	end
	return { if line.mvp then 1 else 0, line.eliminations, line.dealt, -line.deaths, line.assists }
end

local function winnersOf(winner: number): { Model }
	local winners: { Model } = {}
	local keys: { [Model]: { number } } = {}
	for _, body in Fighters.bodies() do
		if Teams.of(body) == winner then
			table.insert(winners, body)
			keys[body] = rank(lineOf(body))
		end
	end
	table.sort(winners, function(a, b)
		local ka, kb = keys[a], keys[b]
		for i = 1, #ka do
			if ka[i] ~= kb[i] then
				return ka[i] > kb[i]
			end
		end
		local la, lb = Health.isAlive(a), Health.isAlive(b)
		if la ~= lb then
			return la
		end
		return a.Name < b.Name
	end)
	return winners
end

-- What the screen's choice buttons do (the server decides; these only ask).
local function choose(name: string)
	if picked == "PlayAgain" or picked == "Leave" then
		return
	end
	if name == "Rematch" and MatchState.get("RematchOpen") ~= true then
		UiSound.play("Denied")
		return
	end
	UiSound.play("Select")
	picked = name
	Net.event("MatchChoice"):FireServer(name)
end

local function screenData(results: Results): MatchEndScreen.Data
	local winner = results.winner
	local myTeam = Teams.of(player) or 1
	local one, two = results.score1, results.score2
	local rounds: { MatchEndScreen.Round } = {}
	for _, item in results.rounds do
		local w, tier = string.match(item, "^(%d+):(%a*)$")
		if w then
			local team = tonumber(w) or 0
			table.insert(rounds, { won = team == myTeam, draw = team == 0, tier = tier or "" })
		end
	end
	local allies: { MatchEndScreen.RowData } = {}
	local enemies: { MatchEndScreen.RowData } = {}
	local me = "p" .. player.UserId
	local lines = table.clone(summary)
	table.sort(lines, function(a, b)
		if a.eliminations ~= b.eliminations then
			return a.eliminations > b.eliminations
		end
		return a.dealt > b.dealt
	end)
	for _, line in lines do
		local ally = line.team == myTeam
		local row: MatchEndScreen.RowData = {
			name = line.name,
			ally = ally,
			image = PlayerTags.headshot(line.userId or line.portraitUserId, BOT_HEAD),
			stats = { line.eliminations, line.deaths, line.assists, line.dealt },
			mine = line.id == me,
			mvp = line.mvp == true,
		}
		table.insert(if ally then allies else enemies, row)
	end
	local build = {}
	for slot = 1, 3 do
		local id = StateValues.get(player, "Mod" .. slot .. "Id")
		local level = StateValues.get(player, "Mod" .. slot .. "Level")
		if typeof(id) == "string" and id ~= "" then
			table.insert(
				build,
				{ id = id, level = if typeof(level) == "string" then level else "L1" }
			)
		end
	end
	return {
		won = winner == myTeam,
		us = if myTeam == 1 then one else two,
		them = if myTeam == 1 then two else one,
		rounds = rounds,
		allies = allies,
		enemies = enemies,
		build = build,
	}
end

local function showPlates(winner: number)
	local myTeam = Teams.of(player)
	local list: { MatchEndScreen.PlateData } = {}
	for _, pair in WinCutscene.copies() do
		local owner = Players:GetPlayerFromCharacter(pair.body)
		local line = lineOf(pair.body)
		table.insert(list, {
			model = pair.copy,
			name = if owner then owner.DisplayName else pair.body.Name,
			ally = winner == myTeam,
			mvp = line ~= nil and line.mvp == true,
		})
	end
	MatchEndScreen.plates(list)
end

local function portraitOf(line: Line?): string
	local id = line and (line.portraitUserId or line.userId)
	if id and id > 0 then
		return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", id)
	end
	return BOT_HEAD
end

-- A card under each winner in the cutscene's final shot (owner 2026-11-20),
-- the best one's bigger; built from their results lines.
local function cardOf(
	copy: Model,
	body: Model,
	line: Line?,
	ally: boolean,
	lead: boolean
): MatchEndScreen.CardData
	local owner = Players:GetPlayerFromCharacter(body)
	return {
		model = copy,
		name = if owner then owner.DisplayName else (if line then line.name else body.Name),
		portrait = portraitOf(line),
		ally = ally,
		lead = lead,
		mvp = line ~= nil and line.mvp == true,
		eliminations = if line then line.eliminations else 0,
		deaths = if line then line.deaths else 0,
		assists = if line then line.assists else 0,
		dealt = if line then line.dealt else 0,
		taken = if line then line.taken else 0,
	}
end

local function showCards(winner: number)
	local ally = winner == Teams.of(player)
	local list: { MatchEndScreen.CardData } = {}
	for i, pair in WinCutscene.copies() do
		table.insert(list, cardOf(pair.copy, pair.body, lineOf(pair.body), ally, i == 1))
	end
	MatchEndScreen.cards(list)
end

local function refreshScreen()
	if MatchEndScreen.active() then
		MatchEndScreen.refresh(
			MatchState.get("RematchOpen") == true,
			MatchState.get("RematchVotes") or 0,
			MatchState.get("RematchNeeded") or 0,
			MatchState.timeLeft(),
			picked
		)
	end
end

-- Start and end -------------------------------------------------------------------

function MatchEndController.stop()
	if not active then
		return
	end
	active = false
	screenUp = false
	MatchEndScreen.hide() -- (its plates follow the copies: gone first)
	WinCutscene.stop()
	CameraController.setOverride(nil)
	if not DraftController.isOpen() then -- a rematch's draft may already want it
		CameraController.setCursorVisible(false)
	end
	for _, d in hidden do
		local body = Fighters.bodyOfPart(d)
		if d.Parent and body and Health.isAlive(body) then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	WeaponController.setSpectating(false)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
end

local function begin()
	if active then
		return
	end
	local results = MatchState.get("Results") :: Results?
	if not results then
		return
	end
	active = true
	screenUp = false
	local data: Results = results
	summary = data.lines
	local winner = data.winner
	SpectateController.stop()
	DeathFxController.clearGrade()
	WeaponController.setSpectating(true)
	ViewmodelController.unequip()
	CameraController.setZoom(nil, 0)
	CameraController.setCursorVisible(true)
	hideLive()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Name ~= "MatchEndScreen" and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	end
	-- The results screen comes in as the song rings out over the final
	-- pose (or at once on a skip, or with no cutscene).
	local function screen()
		if screenUp or not active or not MatchEndScreen.active() then
			return
		end
		screenUp = true
		picked = nil
		MatchEndScreen.show(screenData(data), choose)
		-- the winners' cards under them (the cutscene's copies), else name plates
		if #WinCutscene.copies() > 0 then
			showCards(winner)
		else
			showPlates(winner)
		end
		refreshScreen()
	end
	-- one positive ending song for everyone, winner or not (owner
	-- 2026-11-20): the cutscene starts it and runs on its clock
	local winners = winnersOf(winner)
	local guns: { [number]: string } = {}
	for i, body in winners do
		local line = lineOf(body)
		if line and line.weapon then
			guns[i] = line.weapon
		end
	end
	local played = WinCutscene.play(winners, {
		guns = guns,
		onScreen = screen,
		onFrame = function()
			for _, d in hidden do
				(d :: any).LocalTransparencyModifier = 1
			end
		end,
	})
	if not played then
		UiSound.play("MatchEnd")
		screen()
	end
end

local function onPhase()
	if MatchState.phase() == "MatchEnd" then
		-- The replay hands its screen back first (it ends at the same moment).
		task.spawn(function()
			local deadline = os.clock() + 3
			while ReplayController.isPlaying() and os.clock() < deadline do
				task.wait(0.05)
			end
			if MatchState.phase() == "MatchEnd" then
				begin()
			end
		end)
	else
		MatchEndController.stop()
	end
end

-- Studio preview (vault/02 Art/Win Cutscene.md → Studio preview): the
-- cutscene with you as the winner, no results screen. In Play, Client
-- command bar: require(game.ReplicatedStorage.Shared.StateValues).set(workspace,
-- "PreviewWinCutscene", os.clock()); `false` stops it.
local PREVIEW_FIELD = "PreviewWinCutscene"
-- (and "PreviewWinCutsceneAt" = song time holds it on that frame, for captures)
local PREVIEW_AT = "PreviewWinCutsceneAt"
local PREVIEW_COUNT = "PreviewWinCutsceneCount"
local PREVIEW_SCREEN = "PreviewWinCutsceneScreen"
local previewing = false

local function stopPreview()
	if not previewing then
		return
	end
	previewing = false
	MatchEndScreen.hide()
	WinCutscene.stop()
	CameraController.setOverride(nil)
	WeaponController.setSpectating(false)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 0
			end
		end
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

-- Studio preview of the results screen over the cutscene ("PreviewWinCutsceneScreen"
-- = true): made-up lines for the copies (you first) and two losers.
local function previewScreen(n: number)
	if not MatchEndScreen.active() then
		return
	end
	local team = Teams.of(player) or 1
	local lines: { Line } = {}
	for i = 1, n do
		table.insert(lines, {
			id = if i == 1 then "p" .. player.UserId else "b" .. i,
			name = if i == 1 then player.DisplayName else "Winner " .. i,
			userId = if i == 1 then player.UserId else nil,
			team = team,
			eliminations = 16 - 3 * i,
			deaths = 2 + i,
			assists = i,
			dealt = 2400 - 330 * i,
			taken = 800 + 90 * i,
			mvp = i == 1,
		})
	end
	for i = 1, 2 do
		table.insert(lines, {
			id = "e" .. i,
			name = "Enemy " .. i,
			team = 3 - team,
			eliminations = 4 - i,
			deaths = 9,
			assists = 1,
			dealt = 900,
			taken = 2000,
		})
	end
	summary = lines
	local results: Results = {
		winner = team,
		lines = lines,
		score1 = if team == 1 then 5 else 3,
		score2 = if team == 1 then 3 else 5,
		rounds = {
			"1:Sidearm",
			"2:Sidearm",
			"1:Primary",
			"1:Primary",
			"2:Primary",
			"2:Power",
			"1:Power",
			"1:Power",
		},
	}
	MatchEndScreen.show(screenData(results), function() end)
	local list: { MatchEndScreen.CardData } = {}
	for i, pair in WinCutscene.copies() do
		table.insert(list, cardOf(pair.copy, pair.body, lines[i], true, i == 1))
	end
	MatchEndScreen.cards(list)
end

local function preview()
	local character = player.Character
	if active or not character then
		return
	end
	stopPreview()
	previewing = true
	WeaponController.setSpectating(true)
	ViewmodelController.unequip()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "WinCutscene" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	end
	-- "PreviewWinCutsceneCount" = how many winners (copies of you), 1-5
	local count = StateValues.get(Workspace, PREVIEW_COUNT)
	local n = if typeof(count) == "number" then math.clamp(math.floor(count), 1, 5) else 1
	local winners: { Model } = {}
	for _ = 1, n do
		table.insert(winners, character)
	end
	-- (each copy a different gun, as real winners would have)
	local pool =
		{ "Vandal", "Phantom", "Operator", "Spectre", "Bulldog", "Judge", "Odin", "Sheriff" }
	local guns: { [number]: string } = {}
	for i = 1, n do
		guns[i] = table.remove(pool, math.random(1, #pool)) :: string
	end
	WinCutscene.play(winners, {
		guns = guns,
		onScreen = function()
			if StateValues.get(Workspace, PREVIEW_SCREEN) == true then
				previewScreen(n)
			end
		end,
		onFrame = function()
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					(d :: any).LocalTransparencyModifier = 1
				end
			end
		end,
	})
end

function MatchEndController.start()
	MatchEndScreen.start()
	WinCutscene.preload()
	-- Keys: Enter = PLAY AGAIN, R = REMATCH.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if
			not active
			or not screenUp
			or not MatchEndScreen.active()
			or UserInputService:GetFocusedTextBox()
		then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			MatchEndScreen.press("PlayAgain")
		elseif input.KeyCode == Enum.KeyCode.R then
			MatchEndScreen.press("Rematch")
		end
	end)
	if RunService:IsStudio() then
		StateValues.changed(Workspace, PREVIEW_FIELD):Connect(function()
			if StateValues.get(Workspace, PREVIEW_FIELD) then
				preview()
			else
				stopPreview()
			end
		end)
		StateValues.changed(Workspace, PREVIEW_AT):Connect(function()
			local at = StateValues.get(Workspace, PREVIEW_AT)
			WinCutscene.freeze(if typeof(at) == "number" then at else nil)
		end)
	end
	MatchState.changed("Phase"):Connect(onPhase)
	MatchState.changed("Results"):Connect(onPhase)
	player.CharacterAdded:Connect(MatchEndController.stop)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if active then
				refreshScreen()
			end
		end
	end)
	onPhase()
end

return MatchEndController
