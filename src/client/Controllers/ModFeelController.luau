--!strict
-- Mod "feel" (Stage 4 juice): what the predicted Mods sound like for everyone,
-- and the local screen effects.
--
--   Everyone's character: the simulation's DashStart / Dashing (Dash),
--   UpdraftAt / Updrafting (Updraft) and RecallAt (Recall) attributes
--   replicate, so a new value here means that player just cast: play its 3D
--   sound there (and, for others' Dash and Updraft, Util/WindFx).
--   Your screen: Dash wind streaks and blur, the Updraft's rising-wind edge
--   while you go up, a violet flash as your Recall lands, and the enemy-only
--   warnings (revealed by a Recon dart).
--
-- All overlays are built once and reused.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local WindFx = require(script.Parent.Parent.Util.WindFx)
local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)

local ModFeelController = {}

local player = Players.LocalPlayer
local S = ModAudio.SOUNDS

type Seen = {
	dash: number,
	dashing: boolean,
	dashDir: Vector3,
	updraft: number,
	updrafting: boolean,
	recall: number,
}
local seen: { [Model]: Seen } = setmetatable({}, { __mode = "k" }) :: any
-- Held Mod items in other players' hands, already tinted for this viewer.
local tinted: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local SPEED_LINES = 18
local DASH = Config.DASH_FEEL
local FLASH_TIME = 0.35

-- Dash wind streaks: radial streaks near the edges, weighted toward the
-- way you dash (all round going forward or back), drifting with the wind.
local lines: { ImageLabel } = {}
local lineAngles: { number } = {}
local linesAt = -math.huge
local linesDir = Vector3.new(0, 0, -1) -- the dash in camera space
local blur: BlurEffect? = nil
-- Updraft: our wind loop while rising.
local windHum: ModAudio.Hum? = nil
local windUntil = -math.huge
-- Updraft: the rising-wind screen edge (in fast, sliding down the screen
-- as you go up, gone by the peak).
local updraftEdge: ImageLabel? = nil
local updraftAt = -math.huge
local updraftRise = 0.4
local UPDRAFT_EDGE_IN = 0.06
local UPDRAFT_EDGE_PEAK = 0.25 -- image transparency at its strongest
local flash: Frame? = nil
local revealedTag: TextLabel? = nil
local revealedAt = -math.huge
local REVEALED_TIME = 1.2
local flashAt = -math.huge
local flashPeak = 0

local function number(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function build(): ScreenGui
	local screen = make("ScreenGui", {
		Name = "ModFeel",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 3,
	}, player:WaitForChild("PlayerGui"))
	-- Dash streaks: the streak texture (head on the left) pointing outward.
	for i = 1, SPEED_LINES do
		local angle = (i - 1) / SPEED_LINES * math.pi * 2 + (i % 3) * 0.13
		lineAngles[i] = angle
		lines[i] = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(170 + (i % 4) * 45, 14),
			Rotation = math.deg(angle) + 180,
			BackgroundTransparency = 1,
			Image = VFX.DASH_SCREEN_STREAK,
			ImageTransparency = 1,
		}, screen)
	end
	-- Updraft: wind rising along the sides and the bottom (Blender texture),
	-- a little larger than the screen so it can slide.
	updraftEdge = make("ImageLabel", {
		Name = "UpdraftEdge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.08, 1.08),
		BackgroundTransparency = 1,
		Image = VFX.UPDRAFT_EDGE,
		ImageColor3 = Color3.fromHex("E6F4FF"),
		ImageTransparency = 1,
	}, screen)
	-- "REVEALED" (placeholder) when an enemy Recon spots you.
	revealedTag = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(260, 34),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		TextSize = 26,
		TextColor3 = TeamColor.ENEMY,
		TextStrokeTransparency = 0.5,
		Text = "REVEALED",
		TextTransparency = 1,
	}, screen)
	-- Blast flash.
	flash = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, screen)
	return screen
end

-- A flash over the whole screen (a blast on you), `peak` 0..1.
local function blastFlash(color: Color3, peak: number)
	local f = flash
	if f then
		f.BackgroundColor3 = color
	end
	flashAt = os.clock()
	flashPeak = math.clamp(peak, 0, 0.7)
end

-- Characters ------------------------------------------------------------------

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function stepCharacters()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and rootOf(character)
		if not character or not root then
			continue
		end
		local dash = number(character, "DashStart")
		local dashing = character:GetAttribute("Dashing") == true
		local updraft = number(character, "UpdraftAt")
		local updrafting = character:GetAttribute("Updrafting") == true
		local recall = number(character, "RecallAt")
		local s = seen[character]
		if not s then
			-- First sight: remember, don't replay old casts.
			seen[character] = {
				dash = dash,
				dashing = dashing,
				dashDir = root.CFrame.LookVector,
				updraft = updraft,
				updrafting = updrafting,
				recall = recall,
			}
			continue
		end
		local mine = other == player
		local heldItem = character:FindFirstChild("ModHeldItem")
		if heldItem and heldItem:IsA("Model") and not tinted[heldItem] then
			tinted[heldItem] = true
			ModProps.tint(heldItem, TeamColor.forOwner(other))
		end
		-- (A re-simulated start a few ms off isn't a new dash.)
		local started = false
		if dash > s.dash + 0.05 then
			started = true
			local velocity = character:GetAttribute("DashVelocity")
			local flat = if typeof(velocity) == "Vector3"
				then velocity * Vector3.new(1, 0, 1)
				else Vector3.zero
			local dir = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
			s.dashDir = dir
			if mine then
				ModAudio.play(S.Dash.whoosh)
				if DASH.crackle then
					ModAudio.play(S.Dash.crackle)
				end
				local cam = Workspace.CurrentCamera
				linesAt = os.clock()
				linesDir = if cam
					then cam.CFrame:VectorToObjectSpace(dir)
					else Vector3.new(0, 0, -1)
			else
				local untilT = character:GetAttribute("DashUntil")
				ModAudio.play(S.Dash.world, root.Position)
				WindFx.dashStart(
					character,
					root,
					dir,
					if typeof(untilT) == "number" then untilT - dash else 0.15,
					TeamColor.forOwner(other)
				)
			end
		end
		-- The end (also when a whole short dash fell between two frames).
		if (s.dashing or started) and not dashing then
			if mine then
				ModAudio.play(S.Dash.land)
			else
				WindFx.dashEnd(character, root, s.dashDir, TeamColor.forOwner(other))
			end
		end
		s.dashing = dashing
		-- Updraft: launch sounds, our wind loop while rising; others see WindFx.
		local launched = false
		if updraft > s.updraft + 0.05 then
			launched = true
			local up = character:GetAttribute("UpdraftUp")
			local g = character:GetAttribute("UpdraftGravity")
			local gravity = if typeof(g) == "number" and g > 0 then g else workspace.Gravity
			local rise = if typeof(up) == "number" then up / gravity else 0.4
			if mine then
				ModAudio.play(S.Updraft.launch)
				ModAudio.stopHum(windHum)
				windHum = ModAudio.hum(S.Updraft.wind, root)
				windUntil = os.clock() + rise
				updraftAt = os.clock()
				updraftRise = math.clamp(rise, 0.2, 1)
			else
				ModAudio.play(S.Updraft.world, root.Position)
				WindFx.updraft(character, root, rise, TeamColor.forOwner(other))
			end
		end
		if (s.updrafting or launched) and not updrafting and mine then
			ModAudio.play(S.Updraft.land)
		end
		s.updrafting = updrafting
		-- Recall: a violet flash on our screen as we arrive (the pop and
		-- the sounds everyone gets come with RecallArrive, Util/RecallFx).
		if recall > s.recall + 0.05 and mine then
			blastFlash(Color3.fromHex("9B6BFF"), 0.35)
		end
		s.dash, s.updraft, s.recall = dash, updraft, recall
	end
end

-- Per frame ---------------------------------------------------------------------

local function update(_dt: number)
	local now = os.clock()
	stepCharacters()
	WindFx.step()
	-- Our Updraft wind fades out at the top of the rise.
	if windHum and now >= windUntil then
		ModAudio.stopHum(windHum)
		windHum = nil
	end

	-- Updraft edge: in fast, then fading out toward the peak while it slides
	-- down the screen (the world falls away below you).
	local ue = updraftEdge
	if ue then
		local t = now - updraftAt
		local total = updraftRise + 0.15
		if t >= total then
			if ue.ImageTransparency ~= 1 then
				ue.ImageTransparency = 1
			end
		else
			local strength = if t < UPDRAFT_EDGE_IN
				then t / UPDRAFT_EDGE_IN
				else (1 - (t - UPDRAFT_EDGE_IN) / (total - UPDRAFT_EDGE_IN)) ^ 1.5
			ue.ImageTransparency = 1 - (1 - UPDRAFT_EDGE_PEAK) * strength
			ue.Position = UDim2.fromScale(0.5, 0.47 + 0.06 * (t / total))
		end
	end

	-- Dash streaks: weighted to the dash's side (a sideways dash), all round
	-- going forward (drifting out) or back (drifting in); then a blur pulse.
	local k = (now - linesAt) / DASH.streakTime
	local side, ahead = linesDir.X, -linesDir.Z
	for i, f in lines do
		if k >= 1 then
			if f.ImageTransparency ~= 1 then
				f.ImageTransparency = 1
			end
		else
			local angle = lineAngles[i]
			local cx, cy = math.cos(angle), math.sin(angle)
			local toward = math.max(cx * side, 0) -- this edge is the dash's side
			local weight = math.clamp(math.abs(ahead) + math.sqrt(toward) * math.abs(side), 0, 1)
			local drift = 0.06 * k * (if ahead >= 0 then 1 else -1)
			local r = 0.42 + drift * math.abs(ahead)
			f.Position = UDim2.fromScale(0.5 + cx * r - side * 0.05 * k, 0.5 + cy * r)
			f.ImageTransparency = 1 - (1 - k) * (1 - k) * (0.85 - (i % 2) * 0.15) * weight
		end
	end
	local b = blur
	local bk = (now - linesAt) / DASH.blurTime
	if bk < 1 and not b then
		b = make("BlurEffect", { Name = "DashBlur", Size = 0 }, Lighting)
		blur = b
	end
	if b then
		local size = if bk < 1 then DASH.blur * (1 - bk) * (1 - bk) else 0
		if b.Size ~= size then
			b.Size = size
		end
	end

	local tag = revealedTag
	if tag then
		local rk = (now - revealedAt) / REVEALED_TIME
		tag.TextTransparency = if rk >= 1 then 1 else math.max(rk * 1.5 - 0.5, 0)
	end

	local f = flash
	if f then
		local fk = (now - flashAt) / FLASH_TIME
		f.BackgroundTransparency = if fk >= 1 then 1 else 1 - flashPeak * (1 - fk) ^ 2
	end
end

local function onFx(kind: unknown, data: unknown)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Revealed" then
		-- An enemy Recon dart spotted you: its cue, a red edge flash, a tag.
		ModAudio.play(S.Recon.revealed)
		blastFlash(TeamColor.ENEMY, 0.18)
		revealedAt = os.clock()
	end
end

function ModFeelController.start()
	build()
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	RunService.RenderStepped:Connect(update)
end

return ModFeelController
