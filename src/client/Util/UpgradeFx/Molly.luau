--!strict
-- Molly's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md, Molly.md → Upgrades): what the A / B / glitch levels look and
-- sound like.
--
-- Recharge (A) and Bigger Fire (B) need nothing here: the HUD sweeps the
-- recharge, and Util/MollyFx scales the fire to its radius and duration.
--
-- Fork Fire (G2 / G3) is glitched:
--   MollyThrow   the usual canister (ModFxController), plus magenta static
--                streaming off it so the glitch level reads in the air
--   MollyFork    the canister pops apart (a magenta ring and static, a high
--                pop) and its bomblets fly the server's paths: small neon
--                blocks in the thrower's team colour, moving at a choppy
--                frame rate, snapping to new angles, skipping a little
--                sideways now and then, a magenta static trail and a tick
--                on every bounce
--   MollyBurst   each bomblet's fire, as Util/MollyFx glitch fire
--   MollyFizzle  a bomblet with no floor: a pop of static

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Mods)
local ModSounds = require(Shared.Config.ModSounds)
local Projectile = require(Shared.Mods.Blocks.Projectile)
local VFX = require(Shared.Config.VfxTextures)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local MollyFx = require(script.Parent.Parent.MollyFx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)

local S = ModSounds.Molly
local GLITCH = Config.COLORS.glitch
local player = Players.LocalPlayer

local MAX_FORKS = 8 -- more paths than this in one event: ignored
local BOMBLET_SIZE = 0.5
local CHOPPY_FPS = 20 -- bomblets move at this frame rate (a stutter)
local SKIP_CHANCE = 0.08 -- per frame: drawn a little off its path
local SKIP_DIST = 0.5
local SNAP_GAP = 0.12 -- seconds between snaps to a new angle
local TRAIL_LINGER = 0.4 -- seconds a trail's last particles get before reuse

type Mover = {
	part: Part,
	static: ParticleEmitter,
	path: Projectile.Path,
	start: number, -- server time of t = 0
	stop: number, -- path time it's done
	nextSeg: number, -- the next bounce to tick
	nextSnap: number,
	spin: CFrame,
	bomblet: boolean, -- false: the canister's static trail (invisible part)
}

local movers: { Mover } = {}
type Pooled = { part: Part, static: ParticleEmitter }
local freeParts: { Pooled } = {}
local folder: Folder? = nil
local rng = Random.new()

local function isGlitched(data: { [string]: any }): boolean
	return data.id == "Molly" and (data.level == "G2" or data.level == "G3")
end

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "MollyForkFx"
	made.Parent = Workspace
	folder = made
	table.clear(freeParts)
	return made
end

local function curve(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

-- A bomblet / trail part with its static emitter (pooled).
local function takePart(): (Part, ParticleEmitter)
	fxFolder()
	local pooled = table.remove(freeParts)
	if pooled and pooled.part.Parent then
		return pooled.part, pooled.static
	end
	local made = Instance.new("Part")
	made.Name = "MollyBomblet"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	made.Size = Vector3.one * BOMBLET_SIZE
	local static = Instance.new("ParticleEmitter")
	static.Name = "Static"
	static.Texture = VFX.MOLLY_EMBER
	static.Color = ColorSequence.new(GLITCH, Color3.fromRGB(120, 50, 255))
	static.LightEmission = 1
	static.LightInfluence = 0
	static.Brightness = 2
	static.Lifetime = NumberRange.new(0.15, 0.35)
	static.Speed = NumberRange.new(0.5, 2)
	static.SpreadAngle = Vector2.new(180, 180)
	static.Size = curve(0.35, 0.05)
	static.Transparency = curve(0, 1)
	static.Rate = 0
	static.Parent = made
	local light = Instance.new("PointLight")
	light.Color = GLITCH
	light.Range = 6
	light.Brightness = 2
	light.Shadows = false
	light.Parent = made
	made.Parent = fxFolder()
	return made, static
end

local function release(m: Mover)
	m.static.Rate = 0
	m.part.Transparency = 1
	local light = m.part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	local part, static = m.part, m.static
	-- Let the last static particles fade where they are, then reuse it.
	task.delay(TRAIL_LINGER, function()
		if part.Parent then
			part.CFrame = CFrame.new(0, -10000, 0)
			table.insert(freeParts, { part = part, static = static })
		end
	end)
end

local function addMover(path: Projectile.Path, start: number, color: Color3, bomblet: boolean)
	local part, static = takePart()
	part.Color = color
	part.Transparency = if bomblet then 0 else 1
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = bomblet
	end
	static.Rate = if bomblet then 45 else 60
	static:Clear()
	local elapsed = Workspace:GetServerTimeNow() - start
	part.CFrame = CFrame.new(Projectile.positionAt(path, math.max(elapsed, 0)))
	-- Bounces already behind us (a late event) don't tick.
	local nextSeg = 2
	while nextSeg < #path.segments and path.segments[nextSeg].t <= elapsed do
		nextSeg += 1
	end
	table.insert(movers, {
		part = part,
		static = static,
		path = path,
		start = start,
		stop = Projectile.endTime(path),
		nextSeg = nextSeg,
		nextSnap = 0,
		spin = CFrame.identity,
		bomblet = bomblet,
	})
end

local function colorOf(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

-- The canister in the air: static streaming off it (the canister itself is
-- ModFxController's).
local function onThrow(data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start = data.start
	if not path or typeof(start) ~= "number" then
		return
	end
	addMover(path, start, GLITCH, false)
end

local function onFork(data: { [string]: any })
	local at, paths, start = data.at, data.paths, data.start
	if typeof(at) ~= "Vector3" or typeof(paths) ~= "table" or typeof(start) ~= "number" then
		return
	end
	local color = colorOf(data)
	ModAudio.play(S.forkSplit, at)
	ModAudio.play(S.glitchCrackle, at, 1)
	ModVfx.burst(at, GLITCH, 18, "Sparkle")
	ModVfx.quad({
		texture = VFX.MOD_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.1, 0)),
		from = 1,
		to = 9,
		color = GLITCH,
		life = 0.3,
	})
	for i, raw in ipairs(paths :: { any }) do
		if i > MAX_FORKS then
			break
		end
		local path = Projectile.unpack(raw)
		if path then
			addMover(path, start, color, true)
		end
	end
end

local function onBurst(data: { [string]: any })
	local at, radius, duration, start = data.at, data.radius, data.duration, data.start
	if
		typeof(at) ~= "Vector3"
		or typeof(radius) ~= "number"
		or typeof(duration) ~= "number"
		or typeof(start) ~= "number"
	then
		return
	end
	MollyFx.ignite(at, radius, duration, start, true)
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius * 3 then
			CameraController.shake(0.35 * (1 - away / (radius * 3)))
		end
	end
end

local handler: Types.Handler = {}

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if not isGlitched(data) then
		return false
	end
	if kind == "MollyThrow" then
		onThrow(data)
		return false -- the canister itself is still drawn as usual
	elseif kind == "MollyFork" then
		onFork(data)
		return true
	elseif kind == "MollyBurst" then
		onBurst(data)
		return true
	elseif kind == "MollyFizzle" and data.fork ~= nil then
		if typeof(data.at) == "Vector3" then
			MollyFx.fizzle(data.at, true)
		end
		return true
	end
	return false
end

handler.step = function(_dt: number)
	if #movers == 0 then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local now = os.clock()
	for i = #movers, 1, -1 do
		local m = movers[i]
		local t = serverNow - m.start
		if t >= m.stop then
			table.remove(movers, i)
			release(m)
			continue
		end
		local segs = m.path.segments
		-- A tick and a spit of static on each bounce (the last segment is
		-- the landing: the fire takes it from there).
		if m.bomblet and m.nextSeg < #segs and t >= segs[m.nextSeg].t then
			local seg = segs[m.nextSeg]
			m.nextSeg += 1
			ModAudio.play(S.forkBounce, seg.p)
			ModVfx.burst(seg.p, GLITCH, 5, "Sparkle")
		end
		if not m.bomblet then
			m.part.CFrame = CFrame.new(Projectile.positionAt(m.path, math.max(t, 0)))
			continue
		end
		-- Choppy: drawn at a low frame rate, snapping to new angles, now and
		-- then a little off its path.
		local tq = math.floor(math.max(t, 0) * CHOPPY_FPS) / CHOPPY_FPS
		local pos = Projectile.positionAt(m.path, tq)
		if rng:NextNumber() < SKIP_CHANCE then
			pos += rng:NextUnitVector() * SKIP_DIST
		end
		if now >= m.nextSnap then
			m.nextSnap = now + SNAP_GAP
			m.spin = CFrame.Angles(
				rng:NextInteger(0, 3) * math.pi / 2 + rng:NextNumber(-0.3, 0.3),
				rng:NextInteger(0, 3) * math.pi / 2,
				rng:NextNumber(-0.3, 0.3)
			)
		end
		m.part.CFrame = CFrame.new(pos) * m.spin
	end
end

return handler
