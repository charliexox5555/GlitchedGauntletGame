--!strict
-- The Smoke power's look (Mods/Smoke; vault/01 Design/Abilities/Smoke.md): a canister pop, then a dome of faceted
-- smoke puffs that grows, drifts and thins out. Built from the Blender kit ReplicatedStorage.Abilities.SmokeVFX
-- (Dome shell + Puff1-3; tools/blender/build_mod_smokevfx.py) with the SMOKE_2x2 flipbook for the wisps. Inside a
-- dome your screen fogs over (SmokeVeil). Toxic smokes carry a sickly green tint. Purely visual: what blocks sight
-- for bots and aim assist is Mods/Blocks/Smoke on the same server parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local ModAudio = require(script.Parent.ModAudio)

local SmokeFx = {}

-- Puffs render unlit (Neon, which ignores sunlight): lit faceted grey read as a rock pile in both Studio captures
-- (2026-11-27). Neon brighter than about #8C8C8C clips to white, so the greys stay under it.
local GREY = Color3.fromHex("7C8088")
local GREY_DARK = Color3.fromHex("6A6E76")
local TOXIC = Color3.fromHex("7FA05A")
local PUFFS = 22 -- overlapping puffs around a dome (the dome shell fills between them)
local VEIL_ALPHA = 0.12 -- screen fog inside a smoke (0 = solid)

type Puff = { part: BasePart, base: Vector3, home: Vector3, size: number, spin: Vector3, bob: number }
type Cloud = {
	at: Vector3,
	radius: number,
	start: number, -- server time it popped
	duration: number,
	grow: number,
	fade: number,
	color: Color3,
	dome: BasePart?,
	domeBase: Vector3, -- the kit dome's size at radius 1 (a hemisphere: its box centre is half its height up)
	puffs: { Puff },
	wisps: ParticleEmitter?,
	anchor: Part,
	hum: ModAudio.Hum?,
}

local clouds: { Cloud } = {}
local folder: Folder? = nil
local veil: Frame? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "SmokeFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function kit(name: string): BasePart?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild("SmokeVFX")
	local p = vfx and vfx:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function copy(template: BasePart, color: Color3): BasePart
	local p = template:Clone()
	p:ClearAllChildren()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	if p:IsA("MeshPart") then
		p.TextureID = ""
	end
	p.Parent = fxFolder()
	return p
end

local function veilFrame(): Frame?
	local v = veil
	if v and v.Parent then
		return v
	end
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SmokeVeil"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5 -- under the HUD
	local f = Instance.new("Frame")
	f.Name = "Fog"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = GREY
	f.BackgroundTransparency = 1
	f.Parent = screen
	screen.Parent = gui
	veil = f
	return f
end

-- A dome at `at` (the floor point): `start` server time, sizes in studs.
function SmokeFx.pop(
	at: Vector3,
	radius: number,
	duration: number,
	grow: number,
	fade: number,
	start: number,
	toxic: boolean
)
	local color = if toxic then GREY:Lerp(TOXIC, 0.55) else GREY
	local anchor = Instance.new("Part")
	anchor.Name = "SmokeCore"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
	anchor.Parent = fxFolder()

	-- the canister's gush
	local gush = Instance.new("ParticleEmitter")
	gush.Texture = Tex.SMOKE_2x2
	gush.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	gush.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	gush.Color = ColorSequence.new(color)
	gush.LightInfluence = 0.6
	gush.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, radius * 0.9),
	})
	gush.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	gush.Lifetime = NumberRange.new(0.6, 1)
	gush.Speed = NumberRange.new(radius * 1.2, radius * 2)
	gush.SpreadAngle = Vector2.new(180, 60)
	gush.Drag = 4
	gush.Rate = 0
	gush.Parent = anchor
	gush:Emit(24)

	-- slow wisps at the rim while it stands
	local wisps = gush:Clone()
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.5),
		NumberSequenceKeypoint.new(1, radius * 0.9),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(2.5, 3.5)
	wisps.Speed = NumberRange.new(0.5, 1.5)
	wisps.Drag = 0.5
	wisps.FlipbookMode = Enum.ParticleFlipbookMode.Random
	wisps.Rate = 14
	wisps.Parent = anchor

	local cloud: Cloud = {
		at = at,
		radius = radius,
		start = start,
		duration = duration,
		grow = grow,
		fade = fade,
		color = color,
		dome = nil,
		domeBase = Vector3.new(2, 1, 2),
		puffs = {},
		wisps = wisps,
		anchor = anchor,
		hum = ModAudio.hum(ModSounds.Smoke.loop, anchor),
	}
	local dome = kit("Dome")
	if dome then
		local d = copy(dome, color:Lerp(GREY_DARK, 0.35))
		d.Material = Enum.Material.Neon -- flat, unlit (see GREY)
		d.Transparency = 0.08
		cloud.dome = d
		cloud.domeBase = dome.Size
	end
	local rng = Random.new(math.floor(at.X * 13 + at.Z * 7))
	for i = 1, PUFFS do
		local template = kit("Puff" .. tostring((i - 1) % 3 + 1))
		if not template then
			break
		end
		-- spread over the dome's surface, more at the bottom ring
		local a = (i / PUFFS) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local up = if i % 3 == 0 then rng:NextNumber(0.55, 0.85) else rng:NextNumber(0.05, 0.4)
		local flat = math.sqrt(1 - up * up)
		local dir = Vector3.new(math.cos(a) * flat, up, math.sin(a) * flat)
		local shade = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.06))
		local p = copy(template, shade)
		p.Material = Enum.Material.Neon
		table.insert(cloud.puffs, {
			part = p,
			base = template.Size,
			home = dir * radius * 0.78,
			size = radius * rng:NextNumber(0.6, 0.95),
			spin = Vector3.new(
				rng:NextNumber(-0.15, 0.15),
				rng:NextNumber(-0.25, 0.25),
				rng:NextNumber(-0.15, 0.15)
			),
			bob = rng:NextNumber(0, math.pi * 2),
		})
	end
	ModAudio.play(ModSounds.Smoke.pop, at)
	table.insert(clouds, cloud)
end

function SmokeFx.fizzle(at: Vector3)
	ModAudio.play(ModSounds.Smoke.fizzle, at)
end

local function remove(cloud: Cloud)
	ModAudio.stopHum(cloud.hum)
	if cloud.dome then
		cloud.dome:Destroy()
	end
	for _, puff in cloud.puffs do
		puff.part:Destroy()
	end
	cloud.anchor:Destroy()
end

function SmokeFx.step()
	local now = Workspace:GetServerTimeNow()
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local fog = 0 -- how deep the camera is in smoke (0..1)
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		local age = now - c.start
		if age > c.duration + 0.3 then
			remove(c)
			table.remove(clouds, i)
			continue
		end
		local size = if c.grow > 0 then math.clamp(age / c.grow, 0, 1) else 1
		size = 1 - (1 - size) ^ 3 -- ease out
		local left = c.duration - age
		local thin = if c.fade > 0 then math.clamp(1 - left / c.fade, 0, 1) else 0
		local r = c.radius * size
		if c.dome then
			c.dome.Size = c.domeBase * math.max(r, 0.05)
			c.dome.CFrame = CFrame.new(c.at + Vector3.new(0, c.domeBase.Y * r * 0.5, 0))
			c.dome.Transparency = 0.08 + 0.92 * thin
		end
		for _, puff in c.puffs do
			local drift = Vector3.new(0, math.sin(age * 0.6 + puff.bob) * 0.25, 0)
			local s = math.max(puff.size * size, 0.05)
			puff.part.Size = puff.base * s
			puff.part.CFrame = CFrame.new(c.at + puff.home * size + drift)
				* CFrame.Angles(puff.spin.X * age, puff.spin.Y * age + puff.bob, puff.spin.Z * age)
			puff.part.Transparency = thin
		end
		if c.wisps then
			c.wisps.Rate = if thin > 0 then 0 else 14
		end
		local d = (eye - c.at).Magnitude
		if r > 0 and d < r then
			fog = math.max(fog, math.clamp((r - d) / 1.5, 0, 1) * (1 - thin))
		end
	end
	if fog > 0 or veil then
		local f = veilFrame()
		if f then
			f.BackgroundTransparency = 1 - fog * (1 - VEIL_ALPHA)
		end
	end
end

return SmokeFx
