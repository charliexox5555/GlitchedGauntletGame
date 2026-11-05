--!strict
-- Map life, client only (2026-11-05, lane F). Data: Config/MapLife; the
-- instances are built and tagged by tools/studio/maps/<Map>/Life.luau.
-- Fans turn, the crane's load sways, gulls circle, pigeons take off when a
-- character walks up, steam rises, signs flicker, a far ship drifts.
-- Pattern from the Lobby's AmbienceClient_V2 (tag-driven, streaming-safe,
-- asleep beyond a distance). LihFolk: "VFX Performance Budgets and Culling"
-- (one shared stepper, idle gates, decoration asleep beyond ~160 studs,
-- emitters set once and only switched on and off, no per-frame property
-- churn on emitters), "Water Sky and Atmosphere Art" (foam and glints at the
-- water line), "World Composition and Set Dressing" (life in the backdrop,
-- never in the lanes).
-- Lane G's art is never edited: its parts move through LifeRules (by name),
-- not tags on them. Never in the way of play: every moved part must be CanCollide false (the
-- controller refuses others), and the map scripts keep everything out of
-- head-height sightlines.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLife = require(ReplicatedStorage.Shared.Config.MapLife)

local AudioController = require(script.Parent.AudioController)

local MapLifeController = {}

local TAG = MapLife.TAG
local TAU = math.pi * 2

type Rig = { parts: { BasePart }, base: { CFrame } }
type Entry = {
	kind: string,
	inst: Instance,
	at: Vector3, -- where the wake check measures from
	wake: number,
	awake: boolean,
	phase: number,
	rig: Rig?,
	data: any,
}

local entries: { [Instance]: Entry } = {}
local refused: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local characters: { Vector3 } = {}
local emitterScale = 1
local lastFlap = 0

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function vec(inst: Instance, name: string): Vector3?
	local v = inst:GetAttribute(name)
	return if typeof(v) == "Vector3" then v else nil
end

local function frameOf(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	end
	return nil
end

-- Every part that moves with the instance, with its resting frame. Refuses
-- (nil) anything with a colliding part: map life never moves collision.
local function rigOf(inst: Instance): Rig?
	local parts: { BasePart } = {}
	if inst:IsA("BasePart") then
		parts = { inst }
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	local base = {}
	for i, p in parts do
		if p.CanCollide then
			if not refused[inst] then
				refused[inst] = true
				warn("MapLife: skipped " .. inst:GetFullName() .. " (a part collides)")
			end
			return nil
		end
		base[i] = p.CFrame
	end
	return { parts = parts, base = base }
end

local function move(rig: Rig, d: CFrame)
	for i, p in rig.parts do
		table.insert(moveParts, p)
		table.insert(moveFrames, d * rig.base[i])
	end
end

-- Birds: each part's rest offset from the Body, and which wing it belongs to.
type Bird = {
	body: BasePart,
	rest: CFrame,
	parts: { BasePart },
	rel: { CFrame },
	side: { number }, -- -1 left wing, 1 right wing, 0 body / head
	head: { boolean },
	hinge: number,
	transparency: { number },
}

local function birdOf(model: Instance): Bird?
	local body = model:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) or not model:IsA("Model") then
		return nil
	end
	local rest = body.CFrame
	local bird: Bird = {
		body = body,
		rest = rest,
		parts = {},
		rel = {},
		side = {},
		head = {},
		hinge = num(model, "HingeX", 0.2),
		transparency = {},
	}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.CanCollide then
				return nil
			end
			table.insert(bird.parts, d)
			table.insert(bird.rel, rest:ToObjectSpace(d.CFrame))
			local name = d.Name
			table.insert(
				bird.side,
				if string.sub(name, 1, 5) == "WingL"
					then -1
					elseif string.sub(name, 1, 5) == "WingR" then 1
					else 0
			)
			table.insert(bird.head, string.sub(name, 1, 4) == "Head")
			table.insert(bird.transparency, d.Transparency)
		end
	end
	return bird
end

-- Places a bird: body at `cf`, wings raised by `flap` (radians, + = up),
-- swept back by `fold` (0 spread .. 1 folded along the back), head nodded.
local function poseBird(b: Bird, cf: CFrame, flap: number, fold: number, nod: number)
	for i, p in b.parts do
		local side = b.side[i]
		local f: CFrame
		if side ~= 0 then
			local hinge = CFrame.new(side * b.hinge, 0, 0)
			f = cf
				* hinge
				* CFrame.Angles(0, -side * fold * math.pi * 0.5, side * flap)
				* hinge:Inverse()
				* b.rel[i]
		elseif b.head[i] then
			f = cf
				* CFrame.new(0, -0.12 * nod, -0.06 * nod)
				* CFrame.Angles(-0.5 * nod, 0, 0)
				* b.rel[i]
		else
			f = cf * b.rel[i]
		end
		table.insert(moveParts, p)
		table.insert(moveFrames, f)
	end
end

-- 0 = as built, 1 = gone. Writes only when the value changes.
local function fadeBird(b: Bird, alpha: number)
	if (b :: any).alpha == alpha then
		return
	end
	(b :: any).alpha = alpha
	for i, p in b.parts do
		local base = b.transparency[i]
		p.Transparency = base + (1 - base) * alpha
	end
end

-- Adding ---------------------------------------------------------------------

-- `src` holds the attributes: the instance itself (tagged) or a LifeRule.
local function add(kind: string, inst: Instance, src: Instance?)
	if entries[inst] then
		return
	end
	local a: Instance = src or inst
	local cf = frameOf(inst)
	local e: Entry = {
		kind = kind,
		inst = inst,
		at = if cf then cf.Position else Vector3.zero,
		wake = num(a, "Wake", MapLife.WAKE),
		awake = false,
		phase = math.rad(num(a, "Phase", math.random() * 360)),
		rig = nil,
		data = nil,
	}
	if kind == "Spin" or kind == "Sway" or kind == "Drift" then
		local rig = rigOf(inst)
		if not (rig and cf) then
			return
		end
		e.rig = rig
		if kind == "Spin" then
			e.data = {
				speed = math.rad(num(a, "SpinSpeed", 120)),
				axis = (vec(a, "Axis") or cf.UpVector).Unit,
				centre = cf.Position,
			}
		elseif kind == "Sway" then
			e.data = {
				pivot = vec(a, "Pivot") or if typeof(a:GetAttribute("PivotY")) == "number"
					then Vector3.new(cf.X, a:GetAttribute("PivotY") :: number, cf.Z)
					else cf.Position,
				deg = math.rad(num(a, "SwayDeg", 2)),
				hz = num(a, "SwayHz", 0.2),
				axis = (vec(a, "SwayAxis") or Vector3.xAxis).Unit,
				deg2 = math.rad(num(a, "Sway2Deg", 0)),
				axis2 = (vec(a, "Sway2Axis") or Vector3.zAxis).Unit,
			}
		else
			local from = vec(a, "From") or cf.Position
			local to = vec(a, "To") or cf.Position
			local bases = {}
			for i, p in rig.parts do
				bases[i] = p.Transparency
			end
			e.data = {
				from = from,
				to = to,
				speed = num(a, "Speed", 1),
				origin = cf.Position,
				bases = bases,
				alpha = -1,
			}
			e.wake = num(a, "Wake", 2500)
		end
	elseif kind == "Pulse" or kind == "Flicker" then
		if not inst:IsA("BasePart") then
			return
		end
		e.data = {
			lo = num(a, "PulseMin", 0),
			hi = num(a, "PulseMax", 0.5),
			hz = num(a, "PulseHz", 0.3),
			base = inst.Transparency,
			to = num(a, "FlickerTo", 0.85),
			gap = a:GetAttribute("FlickerGap"),
			nextAt = os.clock() + 2 + math.random() * 6,
			from = 0,
			untilAt = 0,
		}
	elseif kind == "Gull" or kind == "Pigeon" then
		local bird = birdOf(inst)
		if not bird then
			return
		end
		if kind == "Gull" then
			local centre = vec(a, "Center") or bird.rest.Position
			local radius = num(a, "Radius", 40)
			e.at = centre
			e.wake = num(a, "Wake", MapLife.GULL.wake + radius)
			e.data = {
				bird = bird,
				centre = centre,
				radius = radius,
				speed = math.rad(num(a, "Speed", 14)),
			}
		else
			local flee = vec(a, "FleeDir") or -bird.rest.LookVector
			e.at = bird.rest.Position
			e.wake = num(a, "Wake", 120)
			e.data = {
				bird = bird,
				flee = if flee.Magnitude > 0 then flee.Unit else Vector3.xAxis,
				state = "perched",
				flapHz = num(a, "FlapHz", MapLife.PIGEON.flapHz),
				flapDeg = math.rad(num(a, "FlapDeg", MapLife.PIGEON.flapDeg)),
				away = num(a, "Away", MapLife.PIGEON.away),
				rise = num(a, "Rise", MapLife.PIGEON.rise),
				sound = a:GetAttribute("Sound") or MapLife.PIGEON.sound,
				volume = num(a, "Volume", MapLife.PIGEON.volume),
				since = 0,
				delay = math.random() * 0.35,
				backAt = 0,
				nodAt = os.clock() + math.random() * 3,
				yaw = 0,
			}
		end
	elseif kind == "Emitter" then
		if not inst:IsA("ParticleEmitter") then
			return
		end
		local parent = inst.Parent
		e.at = if parent and parent:IsA("BasePart")
			then parent.Position
			elseif parent and parent:IsA("Attachment") then parent.WorldPosition
			else e.at
		e.wake = num(a, "Range", MapLife.EMITTER_RANGE)
		e.data = { rate = inst.Rate }
		inst.Rate = inst.Rate * emitterScale
		inst.Enabled = false
	else
		return
	end
	entries[inst] = e
end

local function remove(inst: Instance)
	entries[inst] = nil
end

-- Updating -------------------------------------------------------------------

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function nearestCharacter(p: Vector3): number
	local best = math.huge
	for _, c in characters do
		local d = (c - p).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

local function updatePigeon(e: Entry, now: number)
	local d = e.data
	local b: Bird = d.bird
	local cfg = MapLife.PIGEON
	local rest = b.rest * CFrame.Angles(0, d.yaw, 0)
	if d.state == "perched" then
		if nearestCharacter(rest.Position) < cfg.scare then
			d.state = "out"
			d.since = now + d.delay
			if now - lastFlap > 1.2 then
				lastFlap = now
				AudioController.play(d.sound, {
					group = "Ambience",
					volume = d.volume,
					pitch = 0.95 + math.random() * 0.1,
					at = rest.Position,
					range = cfg.range,
				})
			end
		else
			-- Pecks and turns now and then.
			local nod = 0
			if now >= d.nodAt then
				local into = now - d.nodAt
				if into > 0.3 then
					d.nodAt = now + 1.5 + math.random() * 3.5
					if math.random() < 0.3 then
						d.yaw = math.rad(math.random(-35, 35))
					end
				else
					nod = math.sin(into / 0.3 * math.pi)
				end
			end
			poseBird(b, rest, 0, 1, nod)
			return
		end
	end
	local fly = cfg.flyTime
	local s: number
	if d.state == "out" then
		s = (now - d.since) / fly
		if s >= 1 then
			d.state = "away"
			d.backAt = now + cfg.back[1] + math.random() * (cfg.back[2] - cfg.back[1])
			fadeBird(b, 1)
			return
		end
	elseif d.state == "away" then
		if now >= d.backAt and nearestCharacter(rest.Position) > cfg.calm then
			d.state = "in"
			d.since = now + d.delay
		end
		return
	else -- "in": the path backwards
		s = 1 - (now - d.since) / fly
		if s <= 0 then
			d.state = "perched"
			fadeBird(b, 0)
			poseBird(b, rest, 0, 1, 0)
			return
		end
	end
	s = math.clamp(s, 0, 1)
	local flee: Vector3 = d.flee
	local pos = rest.Position + flee * d.away * s ^ 1.6 + Vector3.yAxis * d.rise * (1 - (1 - s) ^ 2)
	-- Out: along the flee line, climbing. In: facing home, gliding down, with a
	-- nose-up flare over the last stretch before the perch.
	local ahead = if d.state == "out"
		then pos + flee + Vector3.yAxis * 0.6
		else pos - flee + Vector3.yAxis * (-0.5 + 1.4 * (1 - smooth(s / 0.15)))
	local cf = CFrame.lookAt(pos, ahead)
	local flap = d.flapDeg * math.sin(now * d.flapHz * TAU + e.phase)
	-- Fade over the far end of the path instead of popping.
	fadeBird(b, smooth((s - 0.8) / 0.2))
	poseBird(b, cf, flap, 1 - smooth(s * 8), 0)
end

local function update(e: Entry, now: number)
	local kind = e.kind
	local d = e.data
	if kind == "Spin" then
		local c: Vector3 = d.centre
		local angle = d.speed * now + e.phase
		move(e.rig :: Rig, CFrame.new(c) * CFrame.fromAxisAngle(d.axis, angle) * CFrame.new(-c))
	elseif kind == "Sway" then
		local w = TAU * d.hz * now
		local a = d.deg * (0.8 * math.sin(w + e.phase) + 0.2 * math.sin(w * 2.3 + e.phase * 1.7))
		local b = d.deg2 * math.sin(w * 0.71 + e.phase * 0.5)
		local p: Vector3 = d.pivot
		move(
			e.rig :: Rig,
			CFrame.new(p)
				* CFrame.fromAxisAngle(d.axis, a)
				* CFrame.fromAxisAngle(d.axis2, b)
				* CFrame.new(-p)
		)
	elseif kind == "Drift" then
		local from: Vector3, to: Vector3 = d.from, d.to
		local length = (to - from).Magnitude
		if length > 0 then
			local u = ((now * d.speed + e.phase / TAU * length) % length) / length
			move(e.rig :: Rig, CFrame.new(from + (to - from) * u - d.origin))
			-- Fade in and out over the first and last 6% so the loop never pops.
			local alpha = math.floor(smooth(math.min(u, 1 - u) / 0.06) * 20 + 0.5) / 20
			if alpha ~= d.alpha then
				d.alpha = alpha
				for i, p in (e.rig :: Rig).parts do
					local base = d.bases[i]
					p.Transparency = 1 - (1 - base) * alpha
				end
			end
		end
	elseif kind == "Pulse" then
		local part = e.inst :: BasePart
		part.Transparency = d.lo
			+ (d.hi - d.lo) * (0.5 + 0.5 * math.sin(TAU * d.hz * now + e.phase))
	elseif kind == "Flicker" then
		local part = e.inst :: BasePart
		if now >= d.nextAt then
			local gap: Vector2 = if typeof(d.gap) == "Vector2" then d.gap else Vector2.new(6, 16)
			d.from = now
			d.untilAt = now + 0.12 + math.random() * 0.3
			d.nextAt = now + gap.X + math.random() * (gap.Y - gap.X)
		end
		local off = now < d.untilAt and math.floor((now - d.from) / 0.055) % 2 == 0
		part.Transparency = if off then d.to else d.base
	elseif kind == "Gull" then
		local cfg = MapLife.GULL
		-- An egg-shaped loop that breathes, at a speed that wanders a little.
		local centre: Vector3 = d.centre
		local function at(t: number): Vector3
			local a = d.speed * t + e.phase + 0.35 * math.sin(t * 0.27 + e.phase)
			local r = d.radius * (1 + 0.15 * math.sin(a + e.phase * 0.7))
			return centre
				+ Vector3.new(
					math.cos(a) * r * 1.12,
					cfg.bob * math.sin(2 * a + e.phase),
					math.sin(a) * r * 0.9
				)
		end
		local pos = at(now)
		local tangent = at(now + 0.05) - pos
		local cf = CFrame.lookAt(pos, pos + Vector3.new(tangent.X, 0, tangent.Z))
		local inward = if cf.RightVector:Dot(centre - pos) > 0 then -1 else 1
		cf *= CFrame.Angles(0, 0, inward * math.rad(cfg.bank))
		-- Bursts of flapping between glides.
		local c = (now * 0.22 + e.phase / TAU) % 1
		local k = if c < 0.4 then math.sin(math.pi * c / 0.4) else 0
		local flap = math.rad(7)
			+ math.rad(cfg.flapDeg) * k * math.sin(now * cfg.flapHz * TAU + e.phase)
		poseBird(d.bird, cf, flap, 0, 0)
	elseif kind == "Pigeon" then
		updatePigeon(e, now)
	end
end

local function wakeCheck(cam: Vector3)
	table.clear(characters)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(characters, root.Position)
		end
	end
	for inst, e in entries do
		if not inst.Parent then
			entries[inst] = nil
			continue
		end
		local awake = (e.at - cam).Magnitude <= e.wake
		if awake ~= e.awake then
			e.awake = awake
			if e.kind == "Emitter" then
				(inst :: ParticleEmitter).Enabled = awake
			end
		end
	end
end

-- Rules: a LifeRule (any instance in a map's Life folder) names parts of the
-- map's own art to move, by Name, with the kind's attributes on the rule.
-- Nothing is written to those parts, so a rebuild of the art keeps working.
local ruleConns: { [Instance]: RBXScriptConnection } = {}

local function mapOf(inst: Instance): Instance?
	local node: Instance? = inst
	while node and node.Parent and node.Parent ~= Workspace do
		node = node.Parent
	end
	return if node and node.Parent == Workspace then node else nil
end

-- Rotor rule: copies of the rule's Template (a model in the map's Life
-- folder) sit on the target at Offset1..Offset4 (studs, in the target's own
-- frame) and spin about the target's up axis: blades over a fan disc whose
-- own mesh shows no turning. The copies are client-only and go with the target.
local function addRotors(target: Instance, rule: Instance)
	local name = rule:GetAttribute("Template")
	local life = rule.Parent and rule.Parent.Parent
	local template = if typeof(name) == "string" and life then life:FindFirstChild(name) else nil
	local cf = frameOf(target)
	if not (template and template:IsA("Model") and cf) then
		return
	end
	local copies: { Instance } = {}
	for k = 1, 4 do
		local offset = vec(rule, "Offset" .. k)
		if offset then
			local copy = template:Clone()
			copy:PivotTo(cf * CFrame.new(offset))
			copy.Parent = rule
			table.insert(copies, copy)
			add("Spin", copy, rule)
		end
	end
	target.AncestryChanged:Connect(function()
		if not target:IsDescendantOf(Workspace) then
			for _, c in copies do
				c:Destroy()
			end
		end
	end)
end

local function addRule(rule: Instance)
	local kind = rule:GetAttribute("Kind")
	local target = rule:GetAttribute("Target")
	local map = mapOf(rule)
	if typeof(kind) ~= "string" or typeof(target) ~= "string" or not map or ruleConns[rule] then
		return
	end
	local only = num(rule, "Only", math.huge)
	local matched: { Instance } = {}
	local function try(d: Instance)
		if d.Name ~= target or not (d:IsA("BasePart") or d:IsA("Model")) then
			return
		end
		-- Only counts matches still in the map (a streamed-out one frees its slot).
		for i = #matched, 1, -1 do
			if not matched[i]:IsDescendantOf(map) then
				table.remove(matched, i)
			end
		end
		if #matched >= only then
			return
		end
		table.insert(matched, d)
		if kind == "Rotor" then
			addRotors(d, rule)
		else
			add(kind, d, rule)
		end
	end
	for _, d in map:GetDescendants() do
		try(d)
	end
	ruleConns[rule] = map.DescendantAdded:Connect(try)
end

local function removeRule(rule: Instance)
	local c = ruleConns[rule]
	if c then
		c:Disconnect()
		ruleConns[rule] = nil
	end
end

function MapLifeController.start()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and typeof(level) == "number" and level > 0 and level <= MapLife.LOW_QUALITY then
		emitterScale = 0.5
	end
	for kind, tag in TAG do
		for _, inst in CollectionService:GetTagged(tag) do
			add(kind, inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			add(kind, inst)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	end
	for _, rule in CollectionService:GetTagged(MapLife.RULE) do
		addRule(rule)
	end
	CollectionService:GetInstanceAddedSignal(MapLife.RULE):Connect(addRule)
	CollectionService:GetInstanceRemovedSignal(MapLife.RULE):Connect(removeRule)
	local acc = MapLife.TICK
	RunService.Heartbeat:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		acc += dt
		if acc >= MapLife.TICK then
			acc = 0
			wakeCheck(cam.CFrame.Position)
		end
		local now = os.clock()
		for _, e in entries do
			if e.awake and e.kind ~= "Emitter" then
				update(e, now)
			end
		end
		if #moveParts > 0 then
			Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(moveParts)
			table.clear(moveFrames)
		end
	end)
end

-- For tests: how many entries are awake / known.
function MapLifeController.counts(): (number, number)
	local awake, total = 0, 0
	for _, e in entries do
		total += 1
		if e.awake then
			awake += 1
		end
	end
	return awake, total
end

return MapLifeController
