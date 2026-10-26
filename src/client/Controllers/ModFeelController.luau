--!strict
-- Mod "feel" (Stage 4 juice): what the predicted Mods sound like for everyone,
-- and the local screen effects.
--
--   Everyone's character: the simulation's DashStart (Blink), LaunchAt
--   (Launch Pad) and RollbackAt (Rollback) attributes replicate, so a new
--   value here means that player just cast: play its 3D sound there.
--   Your screen: Blink speed lines, the Rollback "VHS rewind" (wash,
--   scanlines, a REWIND tag), a flash when a Packet goes off on you, and the
--   enemy-only warnings (slowed by a Lag Field, revealed by a Ping).
--
-- All overlays are built once and reused.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local CameraController = require(script.Parent.CameraController)

local ModFeelController = {}

local player = Players.LocalPlayer
local S = ModAudio.SOUNDS

type Seen = { dash: number, launch: number, rollback: number }
local seen: { [Model]: Seen } = setmetatable({}, { __mode = "k" }) :: any
-- Held Mod items in other players' hands, already tinted for this viewer.
local tinted: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local SPEED_LINES = 18
local LINES_TIME = 0.28
local VHS_TIME = 0.55
local SCANLINES = 28
local FLASH_TIME = 0.35

local lines: { Frame } = {}
local linesAt = -math.huge
local scan: Frame? = nil
local scanRows: { Frame } = {}
local rewindTag: TextLabel? = nil
local vhsAt = -math.huge
local flash: Frame? = nil
local flashAt = -math.huge
local flashPeak = 0
local vhs: ColorCorrectionEffect? = nil
local slowedNow = false

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
	-- Speed lines: thin streaks pointing at the centre, near the edges.
	for i = 1, SPEED_LINES do
		local angle = (i - 1) / SPEED_LINES * math.pi * 2 + (i % 3) * 0.13
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.42, 0.5 + math.sin(angle) * 0.42),
			Size = UDim2.fromOffset(160 + (i % 4) * 40, 3),
			Rotation = math.deg(angle),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, screen)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)
		lines[i] = f
	end
	-- VHS: scanlines rolling down and a REWIND tag.
	local s = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ClipsDescendants = true,
	}, screen)
	for i = 1, SCANLINES do
		scanRows[i] = make("Frame", {
			Position = UDim2.fromScale(0, (i - 1) / SCANLINES),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
		}, s)
	end
	rewindTag = make("TextLabel", {
		Position = UDim2.fromOffset(36, 30),
		Size = UDim2.fromOffset(240, 40),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "◀◀ REWIND",
	}, s)
	scan = s
	-- Blast flash.
	flash = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, screen)
	return screen
end

local function playVhs()
	vhsAt = os.clock()
	local effect = vhs
	if not effect or not effect.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "ModRewind"
		made.Parent = Lighting
		vhs = made
		effect = made
	end
	local cc = effect :: ColorCorrectionEffect
	cc.Saturation = -0.85
	cc.Contrast = 0.35
	cc.TintColor = Color3.fromHex("C8F7FF")
	cc.Brightness = 0.05
	TweenService
		:Create(cc, TweenInfo.new(VHS_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Saturation = 0,
			Contrast = 0,
			TintColor = Color3.new(1, 1, 1),
			Brightness = 0,
		})
		:Play()
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
		local launch = number(character, "LaunchAt")
		local rollback = number(character, "RollbackAt")
		local s = seen[character]
		if not s then
			-- First sight: remember, don't replay old casts.
			seen[character] = { dash = dash, launch = launch, rollback = rollback }
			continue
		end
		local mine = other == player
		local heldItem = character:FindFirstChild("ModHeldItem")
		if heldItem and heldItem:IsA("Model") and not tinted[heldItem] then
			tinted[heldItem] = true
			ModProps.tint(heldItem, TeamColor.forOwner(other))
		end
		if dash > s.dash then
			ModAudio.play(S.Blink.use, root.Position)
			task.delay(0.15, function()
				if root.Parent then
					ModAudio.play(S.Blink.arrive, root.Position)
				end
			end)
			if mine then
				linesAt = os.clock()
			end
		end
		if launch > s.launch then
			ModAudio.play(S.LaunchPad.launch, root.Position)
			ModAudio.play(S.LaunchPad.launchHiss, root.Position)
			if mine then
				CameraController.shake(0.5)
				CameraController.punchFov(6, 0.5)
			end
		end
		if rollback > s.rollback then
			local from = character:GetAttribute("RollbackFrom")
			if typeof(from) == "Vector3" then
				ModAudio.play(S.Rollback.snap, from)
			end
			ModAudio.play(S.Rollback.snap, root.Position)
			if mine then
				playVhs()
			end
		end
		s.dash, s.launch, s.rollback = dash, launch, rollback
	end
end

-- Per frame ---------------------------------------------------------------------

local function update(_dt: number)
	local now = os.clock()
	stepCharacters()

	local k = (now - linesAt) / LINES_TIME
	for i, f in lines do
		if k >= 1 then
			if f.BackgroundTransparency ~= 1 then
				f.BackgroundTransparency = 1
			end
		else
			f.BackgroundTransparency = 0.25 + 0.75 * k + (i % 2) * 0.1
		end
	end

	local s = scan
	local v = (now - vhsAt) / VHS_TIME
	if s then
		s.Visible = v < 1
		if v < 1 then
			local roll = (now * 0.9) % (1 / SCANLINES)
			for i, row in scanRows do
				row.Position = UDim2.fromScale(0, (i - 1) / SCANLINES + roll)
				row.BackgroundTransparency = 0.8 + 0.2 * v
			end
			local tag = rewindTag
			if tag then
				tag.TextTransparency = if math.floor(now * 12) % 2 == 0 then 0.1 + 0.9 * v else 0.6
			end
		end
	end

	local f = flash
	if f then
		local fk = (now - flashAt) / FLASH_TIME
		f.BackgroundTransparency = if fk >= 1 then 1 else 1 - flashPeak * (1 - fk) ^ 2
	end

	-- Slowed by an enemy Lag Field: one warning on the way in.
	local mult = player:GetAttribute("ModSpeedMult")
	local slowed = typeof(mult) == "number" and mult < 1
	if slowed and not slowedNow then
		ModAudio.play(S.LagField.slowed)
	end
	slowedNow = slowed
end

local function onFx(kind: unknown, data: unknown)
	if typeof(data) ~= "table" then
		return
	end
	local d = data :: { [string]: any }
	if kind == "Revealed" then
		-- An enemy Ping spotted you.
		ModAudio.play(S.Ping.revealed)
		blastFlash(TeamColor.ENEMY, 0.18)
	elseif kind == "PacketBoom" then
		-- A blast on you: a flash by how close it was.
		local at, radius = d.at, d.radius
		local root = player.Character and rootOf(player.Character)
		if typeof(at) == "Vector3" and typeof(radius) == "number" and root then
			local dist = (root.Position - at).Magnitude
			if dist < radius then
				local mine = d.caster == player
				blastFlash(
					if mine then TeamColor.ALLY else Color3.fromHex("FFE2C8"),
					0.55 * (1 - dist / radius)
				)
			end
		end
	end
end

function ModFeelController.start()
	build()
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	RunService.RenderStepped:Connect(update)
	player.CharacterAdded:Connect(function()
		slowedNow = false
	end)
end

return ModFeelController
