--!strict
-- A local marker for living teammates, including match bots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Fighters = require(Shared.Util.Fighters)
local Health = require(Shared.Health)
local MatchState = require(Shared.MatchState)
local StatusEffects = require(Shared.Config.StatusEffects)
local Teams = require(Shared.Mods.Teams)
local Theme = require(Shared.Config.Theme)

local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local Ui = require(script.Parent.Parent.Util.Ui)

local TeammateBillboardController = {}
local player = Players.LocalPlayer
local colors = Theme.COLORS
local FALLBACK = "rbxassetid://119185654291939"

type Marker = {
	gui: BillboardGui,
	portrait: ImageLabel,
	health: Frame,
	shield: Frame,
}

local function createMarker(playerGui: PlayerGui, head: BasePart): Marker
	local gui: BillboardGui = Ui.make("BillboardGui", {
		Name = "TeammateBillboard",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 140,
		Size = UDim2.fromOffset(54, 43),
		StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
		Enabled = false,
	}, playerGui)
	local badge = Ui.cut(gui, {
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(30, 30),
	}, { corner = 5, color = colors.panel, line = colors.ally })
	local portrait = Ui.make("ImageLabel", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	}, badge)
	local track = Ui.make("Frame", {
		Name = "Vitals",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(54, 11),
		BackgroundColor3 = colors.panel,
		BorderSizePixel = 0,
	}, gui)
	local health = Ui.make("Frame", {
		Name = "Health",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(50, 5),
		BackgroundColor3 = colors.ally,
		BorderSizePixel = 0,
	}, track)
	local shield = Ui.make("Frame", {
		Name = "Shield",
		Position = UDim2.fromOffset(2, 8),
		Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = colors.text,
		BorderSizePixel = 0,
	}, track)
	return { gui = gui, portrait = portrait, health = health, shield = shield }
end

function TeammateBillboardController.start()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local markers: { [Model]: Marker } = {}
	while true do
		local phase = MatchState.phase()
		local body = player.Character
		local seen: { [Model]: boolean } = {}
		if
			(phase == "Countdown" or phase == "Live" or phase == "SuddenDeath")
			and Health.isAlive(body)
		then
			local blindUntil = body and StateValues.get(body, StatusEffects.blinded.attribute)
			local blinded = typeof(blindUntil) == "number"
				and blindUntil > workspace:GetServerTimeNow()
			for _, fighter in Fighters.all(player) do
				local head = fighter.body:FindFirstChild("Head")
				local humanoid = Health.humanoid(fighter.body)
				if
					not (
						head
						and head:IsA("BasePart")
						and humanoid
						and Health.isAlive(humanoid)
						and Teams.isAlly(player, fighter.holder)
					)
				then
					continue
				end
				seen[fighter.body] = true
				local marker = markers[fighter.body]
				if not marker then
					marker = createMarker(playerGui, head)
					markers[fighter.body] = marker
				end
				local holder = fighter.holder
				local userId = if holder:IsA("Player")
					then holder.UserId
					else StateValues.get(holder, "PortraitUserId")
				PlayerTags.loadHeadshot(marker.portrait, userId, FALLBACK)
				local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
				local shieldRatio = if typeof(shield) == "number"
					then math.clamp(shield / Combat.MAX_SHIELD, 0, 1)
					else 0
				local healthWidth =
					math.round(50 * math.clamp(Health.get(humanoid) / Health.max(humanoid), 0, 1))
				local shieldWidth = math.round(50 * shieldRatio)
				marker.health.Size = UDim2.fromOffset(healthWidth, 5)
				marker.shield.Size = UDim2.fromOffset(shieldWidth, 1)
				marker.gui.Adornee = head
				-- (Settings HIDE TEAMMATE TAGS)
				marker.gui.Enabled = not blinded and SettingsApply.get("hideTeammateTags") ~= true
			end
		end
		for model, marker in markers do
			if not seen[model] then
				marker.gui:Destroy()
				markers[model] = nil
			end
		end
		task.wait(0.1)
	end
end

return TeammateBillboardController
