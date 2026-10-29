--!strict
-- Mod "feel" (Stage 4 juice): what the predicted Mods sound like for everyone,
-- and the local screen effects.
--
--   Everyone's character: the simulation's DashStart / Dashing (Dash),
--   LaunchAt (Launch Pad) and RollbackAt (Rollback) attributes replicate, so
--   a new value here means that player just cast: play its 3D sound there
--   (and, for others' dashes, Util/DashFx's trail, burst and puff).
--   Your screen: Dash wind streaks and blur, the Rollback "VHS rewind" (wash,
--   scanlines, a REWIND tag), a flash when a Packet goes off on you, and the
--   enemy-only warnings (slowed by a Lag Field, revealed by a Ping).
--
-- All overlays are built once and reused.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local DashFx = require(script.Parent.Parent.Util.DashFx)
local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local CameraController = require(script.Parent.CameraController)

local ModFeelController = {}

local player = Players.LocalPlayer
local S = ModAudio.SOUNDS

type Seen = { dash: number, dashing: boolean, dashDir: Vector3, launch: number, rollback: number }
local seen: { [Model]: Seen } = setmetatable({}, { __mode = "k" }) :: any
-- Held Mod items in other players' hands, already tinted for this viewer.
local tinted: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local SPEED_LINES = 18
local DASH = Config.DASH_FEEL
local VHS_TIME = 0.55
local SCANLINES = 28
local FLASH_TIME = 0.35

-- Dash wind streaks: radial streaks near the edges, weighted toward the
-- way you dash (all round going forward or back), drifting with the wind.
local lines: { ImageLabel } = {}
local lineAngles: { number } = {}
local linesAt = -math.huge
local linesDir = Vector3.new(0, 0, -1) -- the dash in camera space
local blur: BlurEffect? = nil
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
		local dashing = character:GetAttribute("Dashing") == true
		local launch = number(character, "LaunchAt")
		local rollback = number(character, "RollbackAt")
		local s = seen[character]
		if not s then
			-- First sight: remember, don't replay old casts.
			seen[character] = {
				dash = dash,
				dashing = dashing,
				dashDir = root.CFrame.LookVector,
				launch = launch,
				rollback = rollback,
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
				DashFx.start(
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
				DashFx.finish(character, root, s.dashDir, TeamColor.forOwner(other))
			end
		end
		s.dashing = dashing
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
	DashFx.step()

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
