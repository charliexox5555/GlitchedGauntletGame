--!strict
-- World effects of Mods for everyone (ModFx events from ModService), coloured
-- per viewer (Util/TeamColor): cyan for you and your team, orange-red for
-- enemies. Cosmetic only: the server already decided every result. Shapes
-- come from Util/ModVfx (pooled, stylized textures: rings, scans, hexes,
-- chevrons, sparkles), held / thrown models from Util/ModProps.
--
--   MollyThrow   the canister flying its server path (Blocks/Projectile
--                replay), spinning, fuse sparks, hiss, a clink per wall bounce
--   MollyBurst / MollyFizzle   the fire patch (Util/MollyFx), or nothing to
--                burn on
--   Heal         a beam from the healer to the ally, +HP over the target
--   FrostThrow / FrostBurst / FrostFizzle   the frost canister's flight (as
--                the Molly's), its burst (Util/FrostFx; Hinder is shown there)
--   ReconThrow / ReconStick / ReconPulse   the dart's flight (pointing along
--                its path, a light trail, a whistle, ricochet ticks), it
--                sticking (the stuck dart is a Mod object), and each pulse:
--                a scan wave everyone sees, the dart's light flashing
--   StimDrop     the beacon tossed just ahead of the caster and its zone (Util/StimFx;
--                the stimmed players' crackle and screen are there too)
--   Placed / ObjectGone  a pop when a Mod object goes up / breaks or expires
--   FirewallCast  the cast whoosh; the wall itself is Util/WallFx (it dresses
--                the server's pieces in workspace.ModWalls)
-- Also: ModReveal (sent to your team only) outlines revealed enemies through
-- walls; Mod objects in workspace.ModObjects are coloured per viewer and
-- flash when hit.
--   RecallPlaced / RecallWindup / RecallArrive / RecallPickedUp   the anchor
--                planted, the teleport's wind-up, the pop out and the flash
--                in, the anchor picked up (Util/RecallFx; the anchors' glow
--                and hum and the wind-up shimmer are there too)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)
local Tex = require(Shared.Config.VfxTextures)
local ModSounds = require(Shared.Config.ModSounds)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local FrostFx = require(script.Parent.Parent.Util.FrostFx)
local HealFx = require(script.Parent.Parent.Util.HealFx)
local RecallFx = require(script.Parent.Parent.Util.RecallFx)
local StimFx = require(script.Parent.Parent.Util.StimFx)
local MollyFx = require(script.Parent.Parent.Util.MollyFx)
local WallFx = require(script.Parent.Parent.Util.WallFx)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local ModVfx = require(script.Parent.Parent.Util.ModVfx)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local CameraController = require(script.Parent.CameraController)

local ModFxController = {}

local S = ModAudio.SOUNDS

local player = Players.LocalPlayer

type Flight = {
	blink: boolean, -- a fuse blink
	model: Model,
	glow: { BasePart },
	path: Projectile.Path,
	start: number,
	fuse: number, -- when it lands (it goes back to the pool)
	color: Color3,
	key: string,
	spin: number?, -- tumble speed (default 9)
	hum: ModAudio.Hum?, -- a sound riding it (stopped when it lands)
	sparks: ParticleEmitter?, -- turned off when it lands
	streak: Trail?, -- the Recon dart's light streak (off when it lands)
	pointed: boolean?, -- points along its path (a dart) instead of tumbling
}

type Floater = { gui: BillboardGui, label: TextLabel, born: number }

local FLOATER_TIME = 1.1

local folder: Folder? = nil
local flights: { Flight } = {}
local floaters: { Floater } = {}
local grenadeFree: { [string]: { Model } } = {}
local floaterFree: { Floater } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ModFx"
	made.Parent = Workspace
	folder = made
	table.clear(grenadeFree)
	return made
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

local function teamColor(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

-- Molly -----------------------------------------------------------------------------

local function takeGrenade(id: string, color: Color3): (Model?, string)
	local key = id .. color:ToHex()
	local free = grenadeFree[key]
	local model = free and table.remove(free)
	if not model then
		local template = ModProps.get(id, color)
		if not template then
			return nil, key
		end
		model = template:Clone()
	end
	(model :: Model).Parent = fxFolder()
	return model, key
end

-- A thrown canister's trail, made once per pooled model: the Molly's fuse
-- sparks, the Frost's cold vapour.
type TrailSpec = { name: string, texture: string, color: Color3, size: number, rate: number }
local TRAILS: { [string]: TrailSpec } = {
	Molly = {
		name = "MollySparks",
		texture = Tex.MOLLY_EMBER,
		color = Color3.fromRGB(255, 190, 110),
		size = 0.12,
		rate = 40,
	},
	ReconDart = {
		name = "ReconTrail",
		texture = Tex.RECON_GLOW,
		color = Color3.fromHex("9BE7FF"),
		size = 0.5,
		rate = 80,
	},
	Frost = {
		name = "FrostVapor",
		texture = Tex.FROST_VAPOR,
		color = Color3.fromHex("BFE8FF"),
		size = 0.4,
		rate = 30,
	},
}

local function sparksOf(model: Model, trail: TrailSpec): ParticleEmitter?
	local existing = model:FindFirstChild(trail.name, true)
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return nil
	end
	local fuse = root:FindFirstChild("Fuse")
	local e = Instance.new("ParticleEmitter")
	e.Name = trail.name
	e.Texture = trail.texture
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Size = NumberSequence.new(trail.size, trail.size * 0.25)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(trail.color)
	e.Parent = if fuse and fuse:IsA("Attachment") then fuse else root
	return e
end

-- The Recon dart's flight streak (made once per pooled model): a bright
-- light trail that faces the camera, and a light, so the dart reads in flight.
local function streakOf(model: Model, color: Color3): (Trail?, PointLight?)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return nil, nil
	end
	local existing = root:FindFirstChild("ReconStreak")
	local light = root:FindFirstChild("ReconLight")
	if existing and existing:IsA("Trail") and light and light:IsA("PointLight") then
		return existing, light
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "StreakA"
	a0.Position = Vector3.new(0.14, 0, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "StreakB"
	a1.Position = Vector3.new(-0.14, 0, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "ReconStreak"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Texture = Tex.RECON_TRAIL
	t.TextureMode = Enum.TextureMode.Stretch
	t.FaceCamera = true
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Lifetime = 0.3
	t.MinLength = 0.05
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	t.Enabled = false
	t.Parent = root
	local l = Instance.new("PointLight")
	l.Name = "ReconLight"
	l.Color = color
	l.Brightness = 3
	l.Range = 8
	l.Shadows = false
	l.Enabled = false
	l.Parent = root
	return t, l
end

-- A thrown canister (Molly, Frost) flying its server path: spinning, its
-- trail, a hiss, a clink off each wall.
type CanisterSounds = {
	throw: ModSounds.Cue,
	throwLob: ModSounds.Cue,
	bounce: ModSounds.Cue,
	flight: ModSounds.Cue,
}

local function onCanisterThrow(id: string, sounds: CanisterSounds, data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start, land = data.start, data.land
	if not path or typeof(start) ~= "number" or typeof(land) ~= "number" then
		return
	end
	local color = teamColor(data)
	local model, key = takeGrenade(id, color)
	if not model then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - start
	ModAudio.play(
		if data.lob == true then sounds.throwLob else sounds.throw,
		Projectile.positionAt(path, math.max(elapsed, 0))
	)
	-- A metal clink off each wall it bounces from (a drop isn't a bounce: it
	-- has no sideways speed; the last segment is the landing).
	for i = 2, #path.segments - 1 do
		local seg = path.segments[i]
		local sideways = seg.v * Vector3.new(1, 0, 1)
		if sideways.Magnitude > 0.5 and seg.t > elapsed then
			task.delay(seg.t - elapsed, function()
				ModAudio.play(sounds.bounce, seg.p)
			end)
		end
	end
	local trail = TRAILS[id]
	local sparks = if trail then sparksOf(model, trail) else nil
	if sparks and trail then
		sparks.Rate = trail.rate
	end
	local streak: Trail? = nil
	if id == "ReconDart" then
		local light: PointLight?
		streak, light = streakOf(model, color:Lerp(Color3.new(1, 1, 1), 0.3))
		-- Start the streak from where it is now (a pooled model was elsewhere).
		model:PivotTo(CFrame.new(Projectile.positionAt(path, math.max(elapsed, 0))))
		if streak then
			streak:Clear()
			streak.Enabled = true
		end
		if light then
			light.Enabled = true
		end
	end
	table.insert(flights, {
		blink = false,
		model = model,
		glow = {},
		path = path,
		start = start,
		fuse = land,
		color = color,
		key = key,
		spin = 11,
		pointed = id == "ReconDart",
		hum = ModAudio.hum(
			sounds.flight,
			model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		),
		sparks = sparks,
		streak = streak,
	})
end

local function onMollyBurst(data: { [string]: any })
	local at, radius, duration, start = data.at, data.radius, data.duration, data.start
	if
		typeof(at) ~= "Vector3"
		or typeof(radius) ~= "number"
		or typeof(duration) ~= "number"
		or typeof(start) ~= "number"
	then
		return
	end
	MollyFx.ignite(at, radius, duration, start)
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius * 3 then
			CameraController.shake(0.6 * (1 - away / (radius * 3)))
		end
	end
end

-- Patch Up --------------------------------------------------------------------------

local function floater(target: Model, text: string, color: Color3)
	local head = target:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local f = table.remove(floaterFree)
	if not f then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 40)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace =
			Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
		label.TextSize = 26
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		f = { gui = gui, label = label, born = 0 }
	end
	local fl = f :: Floater
	fl.label.Text = text
	fl.label.TextColor3 = color
	fl.gui.Adornee = head
	fl.gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	fl.gui.Parent = player:FindFirstChild("PlayerGui")
	fl.born = os.clock()
	table.insert(floaters, fl)
end

-- +HP numbers as the heal ticks in (the server heals in steps): every
-- HEAL_NUMBER_STEP seconds, what came in since the last number.
local HEAL_NUMBER_STEP = 0.4

-- The heal running on each target (one at a time: a new orb replaces the
-- rest of the old heal, as on the server). A stale delay or number loop sees
-- that its record is no longer the target's.
type HealRecord = { hum: ModAudio.Hum?, conns: { RBXScriptConnection } }
local activeHeals: { [Model]: HealRecord } = {}

local function endHeal(target: Model, record: HealRecord)
	if activeHeals[target] == record then
		activeHeals[target] = nil
	end
	ModAudio.stopHum(record.hum)
	record.hum = nil
	for _, c in record.conns do
		c:Disconnect()
	end
	table.clear(record.conns)
end

local function healNumbers(target: Model, record: HealRecord, duration: number, color: Color3)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or duration <= 0 then
		return
	end
	local last = humanoid.Health
	local pending = 0
	table.insert(
		record.conns,
		humanoid.HealthChanged:Connect(function(health)
			if health > last then
				pending += health - last
			end
			last = health
		end)
	)
	task.spawn(function()
		local untilT = os.clock() + duration + 0.3
		while os.clock() < untilT and target.Parent do
			task.wait(HEAL_NUMBER_STEP)
			if pending >= 1 then
				floater(target, "+" .. tostring(math.floor(pending + 0.5)), color)
				pending = 0
			end
			if activeHeals[target] ~= record then
				return -- replaced (the new heal shows its own numbers) or ended
			end
		end
	end)
end

local function onHeal(data: { [string]: any })
	local target, caster = data.target, data.caster
	local duration, amount = data.duration, data.amount
	if typeof(duration) ~= "number" or typeof(amount) ~= "number" then
		return
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return -- streamed out: nothing to draw on
	end
	local targetModel = target :: Model
	local friendly = data.caster == player
		or TeamColor.isFriendly(if typeof(data.team) == "number" then data.team else nil)
	local color = if friendly then TeamColor.ALLY else TeamColor.ENEMY
	local casterModel = if typeof(caster) == "Instance" and (caster :: Instance):IsA("Player")
		then (caster :: Player).Character
		else nil
	-- The ribbon (or the self-heal burst) and the glow on the healed player:
	-- everyone sees who's being healed (Util/HealFx).
	HealFx.start(targetModel, casterModel, duration)
	-- A new orb replaces the heal already running (no Complete for that one).
	local old = activeHeals[targetModel]
	if old then
		endHeal(targetModel, old)
	end
	local record: HealRecord = { hum = nil, conns = {} }
	activeHeals[targetModel] = record
	local targetRoot = rootOf(targetModel)
	if targetRoot then
		record.hum = ModAudio.hum(S.HealOrb.healLoop, targetRoot)
	end
	-- Dying cuts the heal short on the server: the loop and glow stop, no Complete.
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(
			record.conns,
			humanoid.Died:Connect(function()
				HealFx.stop(targetModel)
				endHeal(targetModel, record)
			end)
		)
	end
	table.insert(
		record.conns,
		targetModel.AncestryChanged:Connect(function()
			if not targetModel:IsDescendantOf(workspace) then
				endHeal(targetModel, record)
			end
		end)
	)
	local involved = caster == player or targetModel == player.Character
	task.delay(math.max(duration, 0.3), function()
		if activeHeals[targetModel] ~= record then
			return -- replaced, or cut short
		end
		-- The numbers loop still collects the last tick (it ends on its own).
		activeHeals[targetModel] = nil
		ModAudio.stopHum(record.hum)
		record.hum = nil
		task.delay(0.4, function()
			for _, c in record.conns do
				c:Disconnect()
			end
			table.clear(record.conns)
		end)
		if involved then
			ModAudio.play(S.HealOrb.complete)
		end
	end)
	if friendly then
		healNumbers(targetModel, record, duration, color)
	end
end

-- Frost ------------------------------------------------------------------------------

local function onFrostBurst(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	FrostFx.burst(at, radius)
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius * 3 then
			CameraController.shake(0.5 * (1 - away / (radius * 3)))
		end
	end
end

-- Recon ------------------------------------------------------------------------------

-- Recent pulses (where, os.clock()): the stuck dart there flashes its light.
type Pulse = { at: Vector3, t: number }
local recentPulses: { Pulse } = {}

local function onReconPulse(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local color = teamColor(data)
	local d = radius * 2
	ModAudio.play(S.Recon.pulse, at)
	table.insert(recentPulses, { at = at, t = os.clock() })
	-- The ground wave sits on the floor under the dart (or at the dart, if
	-- it's high on a wall or a ceiling).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { fxFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local objects = Workspace:FindFirstChild("ModObjects")
	if objects then
		table.insert(exclude, objects)
	end
	params.FilterDescendantsInstances = exclude
	local down = Workspace:Raycast(at, Vector3.new(0, -8, 0), params)
	local floor = if down then down.Position + Vector3.new(0, 0.05, 0) else at
	ModVfx.quad({
		texture = Tex.RECON_SCAN_RING,
		cframe = CFrame.new(at),
		from = 1,
		to = d,
		color = color,
		life = 0.8,
		alpha0 = 0,
	})
	-- A scan wave across the ground and a thin bubble sweeping out.
	ModVfx.quad({
		texture = Tex.MOD_SCAN,
		cframe = CFrame.new(floor),
		from = 2,
		to = d,
		color = color,
		life = 0.7,
		alpha0 = 0,
	})
	local band = ModVfx.mesh({
		name = "ScanRing",
		cframe = CFrame.new(floor),
		from = Vector3.new(2, 2.5, 2),
		to = Vector3.new(d, 1, d),
		color = color,
		life = 0.7,
		alpha0 = 0.2,
	})
	if not band then
		ModVfx.shell({
			shape = Enum.PartType.Ball,
			cframe = CFrame.new(at),
			from = Vector3.one * 2,
			to = Vector3.one * d,
			color = color,
			life = 0.7,
			alpha0 = 0.75,
		})
	end
end

-- Revealed enemies: an orange-red outline through walls (your team only).
type RevealMark = { highlight: Highlight, untilT: number }
local reveals: { [Model]: RevealMark } = {}

local function onReveal(targets: unknown, duration: unknown)
	if typeof(targets) ~= "table" or typeof(duration) ~= "number" then
		return
	end
	local untilT = os.clock() + math.clamp(duration :: number, 0, 10)
	-- pairs, not ipairs: a model that isn't streamed in arrives as a hole.
	for _, target in pairs(targets :: { [any]: any }) do
		if typeof(target) == "Instance" and (target :: Instance):IsA("Model") then
			local model = target :: Model
			local mark = reveals[model]
			if mark then
				mark.untilT = untilT
			else
				local h = Instance.new("Highlight")
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillColor = TeamColor.ENEMY
				h.OutlineColor = TeamColor.ENEMY
				h.FillTransparency = 0.55
				h.OutlineTransparency = 0
				h.Adornee = model
				h.Parent = fxFolder()
				reveals[model] = { highlight = h, untilT = untilT }
			end
		end
	end
end

-- Placed objects ---------------------------------------------------------------------

-- Mod objects are dressed per viewer: a Launch Pad is a charcoal plate with
-- team-coloured chevrons scrolling toward the launch, a Firewall a team-
-- coloured shimmer with hex panels on both faces. They flash white when hit.
local objectFlash: { [BasePart]: number } = {}
local skins: { [BasePart]: { Texture } } = {}
-- Placed objects wearing their finished model (ModProps.dress): the server
-- part is the hitbox, hidden on this client; the model is the look.
type Dressed = { model: Model, energy: { BasePart }, arrows: { BasePart }, flashing: boolean }
local dressed: { [BasePart]: Dressed } = {}
local ARROW_CHASE = 1.6 -- cycles per second of a finished pad's arrow chase

local function objectColor(part: BasePart): Color3
	local team = part:GetAttribute("TeamId")
	return TeamColor.forTeam(if typeof(team) == "number" then team else nil)
end

-- The part's own colour at rest.
local function restColor(part: BasePart): Color3
	return objectColor(part)
end

local function undress(part: BasePart)
	local d = dressed[part]
	if d then
		dressed[part] = nil
		d.model:Destroy()
	end
end

-- The finished model on a placed part, when it's installed. Returns true
-- when it dressed the part.
local function dress(part: BasePart): boolean
	local model = ModProps.dress(part, objectColor(part))
	if not model then
		return false
	end
	local energy, arrows = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Energy") == true then
			table.insert(energy, d)
			if string.match(d.Name, "^Arrow%d") then
				table.insert(arrows, d)
			end
		end
	end
	table.sort(arrows, function(a, b)
		return a.Name < b.Name
	end)
	model.Parent = fxFolder()
	part.LocalTransparencyModifier = 1
	dressed[part] = { model = model, energy = energy, arrows = arrows, flashing = false }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			undress(part)
		end
	end)
	return true
end

-- Parts already dressed: StreamingEnabled parents a part to nil and back,
-- and it must not get a second set of skins and connections.
local known: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- The stuck Recon dart: the thrown dart model at the part's tip (the part's
-- -Z is the way it flew in).
local function dressDart(part: BasePart)
	local template = ModProps.get("ReconDart", objectColor(part))
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(part.CFrame * CFrame.new(0, 0, -part.Size.Z / 2))
	local energy = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(energy, d)
		end
	end
	model.Parent = fxFolder()
	part.LocalTransparencyModifier = 1
	dressed[part] = { model = model, energy = energy, arrows = {}, flashing = false }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			undress(part)
		end
	end)
end

local function colourObject(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	if known[part] then
		if not dressed[part] and not skins[part] then
			-- Streamed back in: put the model back.
			if part:GetAttribute("Kind") == "ReconDart" then
				dressDart(part)
			else
				dress(part)
			end
		end
		return
	end
	known[part] = true
	if part:GetAttribute("Kind") == "ReconDart" then
		dressDart(part)
	else
		dress(part) -- the finished model carries the look, if there is one
	end
	part.Color = restColor(part)
	part.Destroying:Connect(function()
		skins[part] = nil
	end)
	local lastHp = part:GetAttribute("Hp")
	part:GetAttributeChangedSignal("Hp"):Connect(function()
		local hp = part:GetAttribute("Hp")
		if typeof(hp) == "number" and typeof(lastHp) == "number" and hp < lastHp then
			objectFlash[part] = os.clock()
		end
		lastHp = hp
	end)
end

local function onPlaced(data: { [string]: any })
	local at = data.at
	if typeof(at) ~= "Vector3" then
		return
	end
	local color = teamColor(data)
	ModVfx.quad({
		texture = Tex.MOD_RING,
		cframe = CFrame.new(at),
		from = 1,
		to = 10,
		color = color,
		life = 0.35,
	})
	ModVfx.burst(at, color, 14, "Sparkle")
end

local function onObjectGone(data: { [string]: any })
	local at, size = data.at, data.size
	if typeof(at) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local color = TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	local broken = data.why == "Broken"
	if data.kind == "Recall" and (data.why == "Used" or data.why == "PickedUp") then
		return -- the teleport / pick-up has its own effects (RecallFx)
	end
	if data.kind == "Recall" and broken then
		ModAudio.play(S.Recall.destroyed, at)
		ModAudio.play(S.Recall.destroyedBreak, at)
		ModVfx.burst(at, Color3.fromHex("9B6BFF"), 16, "Sparkle")
	end
	if data.kind == "ReconDart" and broken then
		ModAudio.play(S.Recon.destroyed, at)
		ModAudio.play(S.Recon.destroyedBreak, at)
		ModVfx.burst(at, Color3.fromHex("9BE7FF"), 16, "Sparkle")
	end
	ModVfx.shell({
		shape = Enum.PartType.Block,
		cframe = CFrame.new(at),
		from = size,
		to = size * (if broken then 1.4 else 1.05),
		color = color,
		life = if broken then 0.3 else 0.25,
		alpha0 = 0.3,
		material = Enum.Material.Neon,
	})
	ModVfx.burst(at, color, if broken then 30 else 10, "Sparkle")
end

local function onFx(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local d = data :: { [string]: any }
	if kind == "FirewallCast" then
		-- The push-out whoosh at the caster (ours is played on the press).
		if d.caster ~= player and typeof(d.at) == "Vector3" then
			ModAudio.play(S.Firewall.cast, d.at)
		end
	elseif kind == "MollyThrow" then
		onCanisterThrow("Molly", S.Molly, d)
	elseif kind == "FrostThrow" then
		onCanisterThrow("Frost", S.Frost, d)
	elseif kind == "FrostBurst" then
		onFrostBurst(d)
	elseif kind == "FrostFizzle" then
		if typeof(d.at) == "Vector3" then
			FrostFx.fizzle(d.at)
		end
	elseif kind == "MollyBurst" then
		onMollyBurst(d)
	elseif kind == "MollyFizzle" then
		if typeof(d.at) == "Vector3" then
			MollyFx.fizzle(d.at)
		end
	elseif kind == "Heal" then
		onHeal(d)
	elseif kind == "ReconThrow" then
		onCanisterThrow("ReconDart", S.Recon, d)
	elseif kind == "ReconStick" then
		if typeof(d.at) == "Vector3" then
			ModAudio.play(S.Recon.stick, d.at)
		end
	elseif kind == "ReconPulse" then
		onReconPulse(d)
	elseif kind == "RecallPlaced" then
		RecallFx.placed(d)
	elseif kind == "RecallWindup" then
		RecallFx.windup(d)
	elseif kind == "RecallArrive" then
		RecallFx.arrive(d)
	elseif kind == "RecallPickedUp" then
		RecallFx.pickedUp(d)
	elseif kind == "StimDrop" then
		if
			typeof(d.at) == "Vector3"
			and typeof(d.look) == "Vector3"
			and typeof(d.from) == "Vector3"
			and typeof(d.release) == "number"
			and typeof(d.toss) == "number"
			and typeof(d.radius) == "number"
			and typeof(d.duration) == "number"
			and typeof(d.deploy) == "number"
			and typeof(d.start) == "number"
		then
			StimFx.drop({
				at = d.at,
				look = d.look,
				from = d.from,
				release = d.release,
				toss = d.toss,
				radius = d.radius,
				duration = d.duration,
				deploy = d.deploy,
				start = d.start,
				color = teamColor(d),
				own = d.caster == player, -- leaves from our first-person hand
			})
		end
	elseif kind == "Placed" then
		onPlaced(d)
	elseif kind == "ObjectGone" then
		onObjectGone(d)
	end
end

-- Per frame ---------------------------------------------------------------------------

local function update(_dt: number)
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()

	for i = #flights, 1, -1 do
		local f = flights[i]
		local t = serverNow - f.start
		if t >= f.fuse then
			table.remove(flights, i)
			ModAudio.stopHum(f.hum)
			local sparks = f.sparks
			if sparks then
				sparks.Rate = 0
			end
			local streak = f.streak
			if streak then
				streak.Enabled = false
				local light = streak.Parent and streak.Parent:FindFirstChild("ReconLight")
				if light and light:IsA("PointLight") then
					light.Enabled = false
				end
			end
			f.model.Parent = nil
			local free = grenadeFree[f.key]
			if not free then
				free = {}
				grenadeFree[f.key] = free
			end
			table.insert(free, f.model)
			continue
		end
		local pos = Projectile.positionAt(f.path, math.max(t, 0))
		local spin = f.spin or 9
		if f.pointed then
			-- A dart points where it's going (its tip is -Z).
			local ahead = Projectile.positionAt(f.path, math.max(t, 0) + 0.02)
			if (ahead - pos).Magnitude > 1e-3 then
				f.model:PivotTo(CFrame.lookAt(pos, ahead))
			end
		else
			f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * spin, t * spin * 0.55, 0))
		end
		-- Fuse blink, faster as it runs out.
		local rate = 4 + 14 * (t / f.fuse)
		local on = not f.blink or math.sin(now * rate * math.pi * 2) > 0
		for _, g in f.glow do
			g.Transparency = if on then 0 else 0.6
		end
	end
	ModVfx.step()
	MollyFx.step()
	HealFx.step()
	StimFx.step()
	RecallFx.step()
	WallFx.step()
	FrostFx.step()
	for model, mark in reveals do
		if now >= mark.untilT or not model.Parent then
			mark.highlight:Destroy()
			reveals[model] = nil
		end
	end
	for part, at in objectFlash do
		local done = now - at >= 0.12 or not part.Parent
		if done then
			objectFlash[part] = nil
		end
		part.Color = if done then restColor(part) else Color3.new(1, 1, 1)
		local list = skins[part]
		if list then
			for _, t in list do
				t.Color3 = if done then objectColor(part) else Color3.new(1, 1, 1)
			end
		end
		local d = dressed[part]
		if d and (done or not d.flashing) then
			d.flashing = not done
			local c = if done then objectColor(part) else Color3.new(1, 1, 1)
			for _, e in d.energy do
				e.Color = c
				for _, decal in e:GetChildren() do
					if decal:IsA("Decal") then
						decal.Color3 = c
					end
				end
			end
		end
	end
	-- Launch Pad arrows chase toward the launch, back to front.
	for _, d in dressed do
		local n = #d.arrows
		for i, arrow in d.arrows do
			local phase = (now * ARROW_CHASE - (i - 1) / n) % 1
			arrow.Transparency = 0.65 * phase
		end
	end
	for part in skins do
		if not part.Parent then
			skins[part] = nil
		end
	end
	-- Recon darts: a slow blink, a bright flash on each pulse.
	for i = #recentPulses, 1, -1 do
		if now - recentPulses[i].t > 0.25 then
			table.remove(recentPulses, i)
		end
	end
	for part, d in dressed do
		if part:GetAttribute("Kind") == "ReconDart" then
			local flashing = false
			for _, p in recentPulses do
				if (p.at - part.Position).Magnitude < 2 then
					flashing = true
				end
			end
			local on = flashing or math.sin(now * 8) > 0.3
			for _, g in d.energy do
				g.Transparency = if flashing then 0 elseif on then 0.2 else 0.75
			end
		end
	end

	for i = #floaters, 1, -1 do
		local f = floaters[i]
		local k = (now - f.born) / FLOATER_TIME
		if k >= 1 then
			table.remove(floaters, i)
			f.gui.Parent = nil
			f.gui.Adornee = nil
			table.insert(floaterFree, f)
			continue
		end
		f.gui.StudsOffsetWorldSpace = Vector3.new(0, 2 + 1.5 * k, 0)
		f.label.TextTransparency = k * k
		f.label.TextStrokeTransparency = 0.4 + 0.6 * k
	end
end

function ModFxController.start()
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	Net.event("ModReveal").OnClientEvent:Connect(onReveal)
	WallFx.start()
	RunService.RenderStepped:Connect(update)
	-- Mod objects: coloured for this viewer as they stream in.
	task.spawn(function()
		local objects = Workspace:WaitForChild("ModObjects")
		objects.ChildAdded:Connect(function(child)
			task.defer(colourObject, child)
		end)
		for _, child in objects:GetChildren() do
			colourObject(child)
		end
	end)
end

return ModFxController
