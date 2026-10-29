--!strict
-- Client side of the Mods (vault/04 Tech/Mod System.md). Reads the Mod1/2/3
-- input actions, runs the held state machine, draws the previews and sends
-- requests; the server decides every result (ModService), and the predicted
-- Mods (Dash) run in the simulation on their own (Simulation/Abilities).
--
-- Held state machine (Mods.md → Rules for held Mods):
--   Idle → Equipping (EQUIP_TIME raise) → Held → Using (USE_TIME) → Idle
--   (HeldSteer, the Firewall: Held → Steering until the server says the
--   wall is built; LMB held streams the look (ModSteer), releasing stops it)
--   (HeldCharge, Recon: Held → Charging while LMB is held → release fires
--   with the charge and the bounces RMB picked → Using)
-- Press a held Mod's key: the gun lowers (WeaponController.setHolstered), the
-- item comes up (ViewmodelController.holdItem) and the server is told
-- (ModHold). While held, Fire = Primary use, Aim = Alt use (and the mobile
-- context button). Cancel with the same key, a weapon key or another Mod's
-- key (which switches to it). Cancelling costs nothing; a use spends a
-- charge only if the server accepts it. Quick-cast (dev panel for now) uses
-- a held Mod on the press.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared.Config.Input)
local Charges = require(Shared.Mods.Charges)
local Config = require(Shared.Config.Mods)
local Mods = require(Shared.Mods)
local ModTypes = require(Shared.Mods.Types)
local Net = require(Shared.Net)
local HealOrb = require(Shared.Mods.HealOrb)
local Recall = require(Shared.Mods.Recall)
local Stim = require(Shared.Mods.Stim)
local Placeable = require(Shared.Mods.Blocks.Placeable)
local Projectile = require(Shared.Mods.Blocks.Projectile)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local VfxPool = require(script.Parent.Parent.Util.VfxPool)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)

type Phase = "Idle" | "Equipping" | "Held" | "Using" | "Steering" | "Charging"

-- What the HUD shows for one slot.
export type SlotView = {
	id: string?,
	level: string,
	def: ModTypes.ModDef?,
	stats: ModTypes.Stats?,
	charges: number,
	max: number,
	remaining: number, -- seconds until the next charge (0 = full)
	cooldown: number,
	held: boolean,
	built: boolean,
}

local ModController = {}

local player = Players.LocalPlayer

local phase: Phase = "Idle"
local current = 0 -- slot being held / used
local phaseAt = 0 -- os.clock() the phase began
local queued: ModTypes.UseMode? = nil -- a use pressed while still equipping
local quickCast = false
-- Steering (HeldSteer): how the wall was started, whether LMB was let go,
-- and when the look was last sent.
local steerMode: ModTypes.UseMode = "Primary"
local steerStopped = false
local steerSentAt = -math.huge
local STEER_RATE = 0.05 -- seconds between ModSteer looks (the server prefers its own camera copy)
-- Charging (HeldCharge): when LMB went down, the bounces RMB picked, the hum.
local chargeStart = 0
local chargeBounces = 0
local chargeHum: ModAudio.Hum? = nil
-- The Heal Orb's hum while it's held.
local orbHum: ModAudio.Hum? = nil
local itemToken = 0
local lastDashStart = 0
local lastUpdraftAt = 0
-- Recall: the wind-up and the arrival last seen on our character, and a
-- key held next to the anchor (a pick-up once it's held long enough).
local lastRecallWindup = 0
local lastRecallAt = 0
local recallHold: { slot: number, at: number }? = nil
local recallPress: (slot: number, view: SlotView) -> ()
-- Seconds a teleport request may take to show its wind-up (a ping and a bit).
local RECALL_CONFIRM = 0.35
local stepRecallHold: (now: number) -> ()

-- Held throws with an arc preview: each Mod's projectile options (the server
-- uses the same). The Molly has none: you just throw it (Molly.md).
local THROW_OPTIONS: { [string]: (ModTypes.Stats) -> Projectile.Options } = {}
-- Held placements: each Mod's spot check and box (the server uses the same).
type Finder = (Vector3, Vector3, ModTypes.Stats, RaycastParams, OverlapParams?) -> Placeable.Spot
type PlaceDef = { find: Finder, size: (ModTypes.Stats) -> Vector3, bodies: boolean }
local PLACE: { [string]: PlaceDef } = {
	Recall = { find = Recall.find, size = Recall.size, bodies = false },
}
-- Overlap params for the hologram, rebuilt twice a second (not per frame).
local overlapCache: { [boolean]: OverlapParams } = {}
local overlapAt = -math.huge

local function overlapFor(bodies: boolean): OverlapParams
	local now = os.clock()
	if now - overlapAt > 0.5 then
		overlapAt = now
		table.clear(overlapCache)
	end
	local o = overlapCache[bodies]
	if not o then
		o = Placeable.overlap(bodies)
		overlapCache[bodies] = o
	end
	return o
end
local VALID = Color3.fromHex("4ADE80")
local INVALID = Color3.fromHex("F87171")
local flash: { text: string, at: number }? = nil

local denyListeners: { (slot: number, reason: string) -> () } = {}

local PREFIXES = {}
for slot = 1, Config.SLOTS do
	PREFIXES[slot] = "Mod" .. slot
end

local GAMEPAD_NAMES: { [string]: string } = {
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	DPadUp = "D-Pad Up",
	DPadLeft = "D-Pad Left",
}

-- Slots and status ------------------------------------------------------------------

local function number(inst: Instance?, name: string, default: number): number
	local v = inst and inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- Your server Mods' cooldowns live on PlayerGui.ModState (owner-only).
local function privateState(): Instance?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("ModState")
end

function ModController.privateState(): Instance?
	return privateState()
end

-- One SlotView per slot per frame (the HUD, the hint and the update all ask).
local views: { [number]: SlotView } = {}
local viewsFrame = -1
local frame = 0

local function buildSlot(slot: number): SlotView
	local p = PREFIXES[slot]
	local id = player:GetAttribute(p .. "Id")
	local levelAttr = player:GetAttribute(p .. "Level")
	local level = if typeof(levelAttr) == "string" then levelAttr else "L1"
	local view: SlotView = {
		id = nil,
		level = level,
		def = nil,
		stats = nil,
		charges = 0,
		max = 0,
		remaining = 0,
		cooldown = 0,
		held = phase ~= "Idle" and current == slot,
		built = false,
	}
	if typeof(id) ~= "string" then
		return view
	end
	local def = Mods.def(id)
	local stats = Mods.stats(id, level)
	if not def or not stats then
		return view
	end
	view.id = id
	view.def = def
	view.stats = stats
	view.max = stats.charges
	view.cooldown = stats.cooldown
	view.built = Mods.isBuilt(id)
	-- Predicted Mods keep their charges on the character in time(); server
	-- Mods on the owner-only holder in the server clock.
	local source: Instance? = privateState()
	local now = Workspace:GetServerTimeNow()
	if def.authority == "Simulation" then
		source = player.Character
		now = time()
	end
	local charges = number(source, p .. "Charges", stats.charges)
	local rechargeAt = number(source, p .. "RechargeAt", now)
	charges, rechargeAt = Charges.settle(charges, rechargeAt, stats.charges, stats.cooldown, now)
	view.charges = charges
	view.remaining = Charges.remaining(charges, rechargeAt, stats.charges, stats.cooldown, now)
	return view
end

function ModController.slot(slot: number): SlotView
	if viewsFrame ~= frame then
		viewsFrame = frame
		table.clear(views)
	end
	local v = views[slot]
	if not v then
		v = buildSlot(slot)
		views[slot] = v
	end
	return v
end

local function ready(view: SlotView): boolean
	return view.charges >= 1 or player:GetAttribute("ModUnlimitedCharges") == true
end

-- The key that drives a slot on the current device ("Q", "LB", ...).
function ModController.keyLabel(slot: number): string
	local b = Bindings[PREFIXES[slot]]
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") and b.gamepad[1] then
		local name = b.gamepad[1].Name
		return GAMEPAD_NAMES[name] or name
	end
	return if b.keys[1] then b.keys[1].Name else ""
end

local function useLabels(): (string, string)
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return "RT", "LT"
	elseif last == Enum.UserInputType.Touch then
		return "FIRE", "ALT"
	end
	return "LMB", "RMB"
end

local function deny(slot: number, reason: string)
	ModAudio.play(ModAudio.SOUNDS.Denied)
	flash = { text = reason, at = os.clock() }
	for _, fn in denyListeners do
		task.spawn(fn, slot, reason)
	end
end

function ModController.onDeny(fn: (slot: number, reason: string) -> ())
	table.insert(denyListeners, fn)
end

function ModController.setQuickCast(on: boolean)
	quickCast = on
end

function ModController.isQuickCast(): boolean
	return quickCast
end

-- The slot being held (0 when none) and whether it can be used yet.
function ModController.heldSlot(): number
	return if phase == "Idle" then 0 else current
end

-- Previews ---------------------------------------------------------------------------

local previewFolder: Folder? = nil
local arcPool: VfxPool.Pool<Part>? = nil
local arcParts: { Part } = {}
local blastRing: Part? = nil
local hologram: Part? = nil
local lastSpot: Placeable.Spot? = nil
local targetHighlight: Highlight? = nil
local ARC_DOTS = 26

local function previewParent(): Folder
	local f = previewFolder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ModPreview"
	made.Parent = Workspace
	previewFolder = made
	arcPool = nil
	blastRing = nil
	hologram = nil
	return made
end

local function newPreviewPart(shape: Enum.PartType, size: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Parent = previewParent()
	return p
end

local function hideArc()
	local pool = arcPool
	if pool then
		for _, p in arcParts do
			pool:release(p)
		end
	end
	table.clear(arcParts)
	if blastRing then
		blastRing.Transparency = 1
	end
end

local function hidePlacement()
	if hologram then
		hologram.Transparency = 1
	end
	lastSpot = nil
end

local function hideTarget()
	if targetHighlight then
		targetHighlight.Adornee = nil
		targetHighlight.Enabled = false
	end
end

-- World-only params for previews: what the server's projectile and line of
-- sight checks ignore (bodies, dummies, effects, the camera). Mod objects
-- count, like on the server (a Firewall stops a grenade).
-- Rebuilt twice a second, not every frame.
local cachedParams: RaycastParams? = nil
local cachedParamsAt = -math.huge

local function previewParams(): RaycastParams
	local now = os.clock()
	if cachedParams and now - cachedParamsAt < 0.5 then
		return cachedParams
	end
	local exclude: { Instance } = { previewParent() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "Effects", "ModFx" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(exclude, cam)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	cachedParams = params
	cachedParamsAt = now
	return params
end

local function headPosition(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return nil
end

local function drawArc(id: string, stats: ModTypes.Stats)
	local head = headPosition()
	local cam = Workspace.CurrentCamera
	local options = THROW_OPTIONS[id]
	if not head or not cam or not options then
		hideArc()
		return
	end
	local params = previewParams()
	local origin, velocity = Projectile.throw(head, cam.CFrame.LookVector, "Primary", stats, params)
	local path = Projectile.simulate(origin, velocity, options(stats), params)
	local pool = arcPool
	if not pool then
		local made = VfxPool.new(function(): Part
			return newPreviewPart(Enum.PartType.Ball, Vector3.one * 0.18)
		end, previewParent(), ARC_DOTS)
		arcPool = made
		pool = made
	end
	local color = TeamColor.ALLY
	local fuse = Projectile.endTime(path)
	for i = 1, ARC_DOTS do
		local p = arcParts[i]
		if not p then
			p = pool:acquire()
			arcParts[i] = p
		end
		local t = fuse * i / ARC_DOTS
		p.CFrame = CFrame.new(Projectile.positionAt(path, t))
		p.Color = color
		p.Transparency = 0.15 + 0.5 * (i / ARC_DOTS)
	end
	local ring = blastRing
	if not ring then
		ring = newPreviewPart(Enum.PartType.Cylinder, Vector3.new(0.05, 1, 1))
		blastRing = ring
	end
	local landing = Projectile.positionAt(path, fuse)
	local r: number = stats.radius
	ring.Size = Vector3.new(0.06, r * 2, r * 2)
	ring.CFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color
	ring.Transparency = 0.82
end

-- The hologram where a placed Mod would go: green when it can, red when not.
local function drawPlacement(id: string, stats: ModTypes.Stats)
	local head = headPosition()
	local cam = Workspace.CurrentCamera
	local place = PLACE[id]
	if not head or not cam or not place then
		hidePlacement()
		return
	end
	local spot =
		place.find(head, cam.CFrame.LookVector, stats, previewParams(), overlapFor(place.bodies))
	lastSpot = spot
	local part = hologram
	if not part then
		part = newPreviewPart(Enum.PartType.Block, Vector3.one)
		part.Material = Enum.Material.ForceField
		hologram = part
	end
	part.Size = place.size(stats)
	part.CFrame = spot.cframe
	part.Color = if spot.valid then VALID else INVALID
	part.Transparency = 0.2
end

local function showTarget(model: Model?)
	if not model or model == player.Character then
		hideTarget()
		return
	end
	local h = targetHighlight
	if not h then
		local made = Instance.new("Highlight")
		made.Name = "ModTarget"
		made.FillTransparency = 0.85
		made.OutlineTransparency = 0
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Parent = previewParent()
		targetHighlight = made
		h = made
	end
	h.FillColor = TeamColor.ALLY
	h.OutlineColor = TeamColor.ALLY
	h.Adornee = model
	h.Enabled = true
end

-- Who the Heal Orb's LMB would heal right now: the ally in the crosshair,
-- else yourself (nil: no character).
local function healTarget(stats: ModTypes.Stats): Model?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	return HealOrb.primaryTarget(
		player,
		cam.CFrame.Position,
		cam.CFrame.LookVector,
		stats,
		previewParams()
	)
end

-- State machine ------------------------------------------------------------------------

local function setPhase(p: Phase, slot: number)
	phase = p
	current = slot
	phaseAt = os.clock()
end

local function dropItem()
	itemToken += 1
	local token = itemToken
	-- Let the item sink with the raising gun before it goes.
	task.delay(0.2, function()
		if token == itemToken then
			ViewmodelController.holdItem(nil)
		end
	end)
end

-- Recon's launcher lights: the bounce counter (0 / 1 / 2) and the charge.
local function launcherLights(charge: number)
	ViewmodelController.setItemPart("Bounce1_Energy", if chargeBounces >= 1 then 0 else 0.85)
	ViewmodelController.setItemPart("Bounce2_Energy", if chargeBounces >= 2 then 0 else 0.85)
	ViewmodelController.setItemPart("Charge_Energy", 0.9 - 0.9 * charge)
end

local function stopChargeHum()
	ModAudio.stopHum(chargeHum)
	chargeHum = nil
	ModAudio.stopHum(orbHum)
	orbHum = nil
end

-- Back to the gun (after a use, a cancel, death).
local function endHold(tellServer: boolean)
	if phase == "Idle" then
		return
	end
	if tellServer then
		Net.event("ModHold"):FireServer(0)
	end
	setPhase("Idle", 0)
	queued = nil
	stopChargeHum()
	WeaponController.setHolstered("Mod", false)
	ViewmodelController.setFreeHand(nil)
	hideArc()
	hidePlacement()
	hideTarget()
	dropItem()
end

function ModController.cancel()
	endHold(true)
end

-- A cancel the player asked for (same key, a weapon key): with its blip.
local function cancelByPlayer()
	ModAudio.play(ModAudio.SOUNDS.Cancel)
	endHold(true)
end

local function sendUse(
	slot: number,
	mode: ModTypes.UseMode,
	target: Model?,
	charge: number?,
	bounces: number?
)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	Net.event("ModUse")
		:FireServer(slot, mode, cam.CFrame.Position, cam.CFrame.LookVector, target, charge, bounces)
end

-- Uses the held Mod (or queues the use while it's still coming up).
local function use(mode: ModTypes.UseMode)
	if phase ~= "Equipping" and phase ~= "Held" then
		return
	end
	local view = ModController.slot(current)
	local def, stats = view.def, view.stats
	if not def or not stats then
		endHold(true)
		return
	end
	if def.activation == "HeldCharge" then
		if mode == "Alt" then
			-- RMB picks the bounces (it isn't a use).
			chargeBounces = (chargeBounces + 1) % ((stats.maxBounces or 2) + 1)
			ModAudio.play(ModAudio.SOUNDS.Recon.bounceSelect)
			launcherLights(0)
			return
		end
		if phase == "Equipping" then
			queued = mode
			return
		end
		-- LMB down: charge until it's let go (stepCharge fires).
		setPhase("Charging", current)
		chargeStart = os.clock()
		stopChargeHum()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		chargeHum = ModAudio.hum(ModAudio.SOUNDS.Recon.charge, root)
		return
	end
	if mode == "Alt" and not def.hint.alt then
		return
	end
	if mode == "Primary" and not def.hint.primary then
		return
	end
	if phase == "Equipping" then
		queued = mode
		return
	end
	if def.activation == "HeldPlace" then
		if not lastSpot then
			drawPlacement(def.id, stats) -- quick-cast: no frame has drawn it yet
		end
		local spot = lastSpot
		if not spot or not spot.valid then
			deny(current, if spot and spot.reason then spot.reason else "Can't place there")
			return
		end
	end
	local target: Model? = nil
	if def.id == "HealOrb" then
		target = if mode == "Alt" then player.Character else healTarget(stats)
		if not target then
			return
		end
		if HealOrb.full(target) then
			ModAudio.play(ModAudio.SOUNDS.HealOrb.refused)
			deny(
				current,
				if target == player.Character then "Full health" else "Ally at full health"
			)
			return
		end
		if mode == "Alt" then
			target = nil -- the server heals the caster itself
		end
	end
	sendUse(current, mode, target)
	queued = nil
	hideArc()
	hidePlacement()
	hideTarget()
	if def.activation == "HeldSteer" then
		-- The hand pushes out and guides the wall while it builds.
		setPhase("Steering", current)
		steerMode = mode
		steerStopped = false
		steerSentAt = -math.huge
		ViewmodelController.setFreeHand("FirewallGuide")
		ModAudio.play(ModAudio.SOUNDS.Firewall.cast)
		return
	end
	setPhase("Using", current)
	ViewmodelController.itemAction(
		if def.activation == "HeldThrow"
			then (if mode == "Alt" then "Lob" elseif def.id == "Frost" then "Javelin" else "Throw")
			elseif def.activation == "HeldPlace" then "Place"
			elseif
				target == nil or target == player.Character
			then "OrbChest" -- yourself: into your chest
			else "Heal" -- to an ally: pushed forward
	)
	if def.id == "HealOrb" then
		stopChargeHum()
		ModAudio.play(
			if target == nil or target == player.Character
				then ModAudio.SOUNDS.HealOrb.absorb
				else ModAudio.SOUNDS.HealOrb.send
		)
	end
end

local function startHold(slot: number, view: SlotView)
	local def = view.def :: ModTypes.ModDef
	setPhase("Equipping", slot)
	queued = nil
	itemToken += 1
	WeaponController.setHolstered("Mod", true)
	if def.activation == "HeldSteer" then
		-- Nothing in the hand: the free hand ignites.
		ViewmodelController.holdItem(nil)
		ViewmodelController.setFreeHand("FirewallReady")
		ModAudio.play(ModAudio.SOUNDS.Firewall.ignite)
	else
		ViewmodelController.holdItem(ModProps.get(def.id, TeamColor.ALLY))
	end
	Net.event("ModHold"):FireServer(slot)
	if def.id == "Recall" then
		ModAudio.play(ModAudio.SOUNDS.Recall.equip)
	elseif def.id == "Recon" then
		ModAudio.play(ModAudio.SOUNDS.Recon.equip)
		chargeBounces = 0
		launcherLights(0)
	elseif def.id == "Frost" then
		ModAudio.play(ModAudio.SOUNDS.Frost.equip)
	elseif def.id == "Molly" then
		-- Canister out, then the free hand pulls the pin.
		ModAudio.play(ModAudio.SOUNDS.Molly.equip)
		local token = itemToken
		task.delay(Config.MOLLY_PIN_AT, function()
			-- Not once the throw has started (a quick-cast or a queued click).
			if token == itemToken and (phase == "Equipping" or phase == "Held") then
				ViewmodelController.gesture("MollyPinPull")
				ViewmodelController.hideItemPart("Pin", Config.MOLLY_PIN_GONE)
				ModAudio.play(ModAudio.SOUNDS.Molly.pinPull)
			end
		end)
	elseif def.id == "HealOrb" then
		-- The orb gathers in the palm, then hums while it's held.
		ModAudio.play(ModAudio.SOUNDS.HealOrb.form)
		ModAudio.stopHum(orbHum)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		orbHum = ModAudio.hum(ModAudio.SOUNDS.HealOrb.heldLoop, root)
	end
	if quickCast and def.quickCast then
		-- Straight to the use: skip the raise.
		phase = "Held"
		use(def.quickCast)
	end
end

-- Recall with its anchor down -------------------------------------------------------

-- Where our anchor stands (nil: none planted).
local function recallAnchor(): Vector3?
	local a = player:GetAttribute("RecallAnchor")
	return if typeof(a) == "Vector3" then a else nil
end

-- When we last asked to teleport (os.clock()).
local recallSentAt = -math.huge

-- Our teleport is winding up (or just asked for and not confirmed yet).
local function recallBusy(): boolean
	local untilT = number(player.Character, "RecallWindupUntil", 0)
	return untilT > Workspace:GetServerTimeNow() or os.clock() - recallSentAt < RECALL_CONFIRM
end

local function recallTeleport(slot: number, _stats: ModTypes.Stats)
	recallSentAt = os.clock()
	Net.event("ModRecall"):FireServer(slot, "Teleport")
	-- No shots until the server's wind-up is seen (it then blocks the rest:
	-- update, RecallWindupUntil); a refusal lifts it (onFx).
	WeaponController.blockFire(RECALL_CONFIRM)
end

-- The key with the anchor down: out of range is refused here; next to it,
-- a tap teleports and a hold picks it up (stepRecallHold); else teleport.
recallPress = function(slot: number, view: SlotView)
	local stats = view.stats
	local anchor = recallAnchor()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not stats or not anchor or not root or not root:IsA("BasePart") then
		return
	end
	local distance = (root.Position - anchor).Magnitude
	if distance > stats.range then
		ModAudio.play(ModAudio.SOUNDS.Recall.outOfRange)
		deny(slot, "Out of range")
		return
	end
	if distance <= stats.pickupRange then
		recallHold = { slot = slot, at = os.clock() }
		return
	end
	recallTeleport(slot, stats)
end

-- Per frame: a key held next to the anchor.
stepRecallHold = function(now: number)
	local hold = recallHold
	if not hold then
		return
	end
	local stats = ModController.slot(hold.slot).stats
	if not stats or not recallAnchor() then
		recallHold = nil
		return
	end
	if not InputController.isDown(PREFIXES[hold.slot]) then
		recallHold = nil
		recallTeleport(hold.slot, stats) -- a tap: teleport after all
	elseif now - hold.at >= stats.pickupHold then
		recallHold = nil
		Net.event("ModRecall"):FireServer(hold.slot, "PickUp")
	end
end

local function onModPressed(slot: number)
	if not player.Character then
		return
	end
	if phase ~= "Idle" and current == slot then
		if phase ~= "Using" and phase ~= "Steering" then
			cancelByPlayer() -- same key: cancel (a wall being built finishes)
		end
		return
	end
	if phase == "Using" or phase == "Steering" then
		return -- mid-throw / mid-wall: let it finish
	end
	if recallBusy() then
		deny(slot, "Teleporting") -- no other Mod (or a second Recall) mid-teleport
		return
	end
	local view = ModController.slot(slot)
	local def = view.def
	if phase ~= "Idle" then
		endHold(true) -- another Mod's key switches to it
	end
	if not def or not view.built then
		deny(slot, if def then def.name .. " isn't built yet" else "Empty slot")
		return
	end
	if not ready(view) then
		-- A predicted Mod may already have cast from this same press (the
		-- simulation step ran before this handler): that's not a refusal.
		local character = player.Character
		local castAt = character and character:GetAttribute(PREFIXES[slot] .. "CastAt")
		local justCast = def.authority == "Simulation"
			and typeof(castAt) == "number"
			and time() - castAt < 0.25
		if not justCast then
			deny(slot, "Not ready")
		end
		return
	end
	if def.id == "Recall" and recallAnchor() then
		recallPress(slot, view)
		return
	end
	if def.activation == "Instant" then
		if def.id == "Stim" then
			-- Nothing under you to drop it on: refused here, nothing spent.
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if
				not root
				or not root:IsA("BasePart")
				or not Stim.floorUnder(root, previewParams())
			then
				deny(slot, "No ground")
				return
			end
		end
		if def.authority == "Server" then
			sendUse(slot, "Primary", nil)
		end
		if def.id == "Stim" then
			-- Off the belt and slammed down at your feet with a quick crouch.
			ModAudio.play(ModAudio.SOUNDS.Stim.grab)
			ViewmodelController.gesture("StimSlam", "Stim")
			CameraController.lunge(Vector3.new(0, -0.45, 0), 0.3)
		end
		-- Simulation Mods (Dash) run from the same input in the simulation.
		return
	end
	startHold(slot, view)
end

-- The server didn't accept something: put our state back.
-- The server finished building our wall (and let go of the hold).
local function onWallBuilt(data: { [string]: any })
	if phase == "Steering" and data.slot == current then
		endHold(false)
	end
end

local function onFx(kind: unknown, data: unknown)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "WallBuilt" then
		onWallBuilt(data :: { [string]: any })
		return
	end
	if kind ~= "Denied" then
		return
	end
	local d = data :: { [string]: any }
	local slot = d.slot
	local reason = d.reason
	if typeof(slot) ~= "number" or typeof(reason) ~= "string" then
		return
	end
	if phase ~= "Idle" and current == slot and phase ~= "Using" then
		endHold(false)
	end
	-- A refused teleport: shoot again at once (unless a wind-up is running).
	if number(player.Character, "RecallWindupUntil", 0) <= Workspace:GetServerTimeNow() then
		recallSentAt = -math.huge
		WeaponController.blockFire(0)
	end
	deny(slot, reason)
end

-- Charging the Recon launcher: the light fills and the hum rises; letting
-- go of LMB fires with the charge and the picked bounces.
local function stepCharge(now: number)
	local view = ModController.slot(current)
	local stats = view.stats
	local chargeTime = if stats then stats.chargeTime else 1
	local charge = math.clamp((now - chargeStart) / chargeTime, 0, 1)
	launcherLights(charge)
	local hum = chargeHum
	if hum then
		hum.sound.PlaybackSpeed = 0.8 + 0.6 * charge
	end
	if InputController.isDown("Fire") then
		return
	end
	stopChargeHum()
	sendUse(current, "Primary", nil, charge, chargeBounces)
	setPhase("Using", current)
	ModAudio.play(ModAudio.SOUNDS.Recon.fire)
	ViewmodelController.setItemPart("Dart", 1)
	ViewmodelController.itemAction("LauncherFire")
	CameraController.kick(1.2, 0, 1, 0.25)
end

-- Steering a wall: stream the flat look while LMB is held; let go = stop.
-- A backstop ends it if the server's "built" never comes.
local function stepSteer(now: number)
	local view = ModController.slot(current)
	local stats = view.stats
	local limit = if stats then stats.maxLength / stats.speed + 1.5 else 3
	if now - phaseAt > limit then
		endHold(false)
		return
	end
	if steerMode ~= "Primary" or steerStopped then
		return
	end
	if not InputController.isDown("Fire") then
		steerStopped = true
		Net.event("ModSteer"):FireServer(current, 0, 0, true)
		return
	end
	local cam = Workspace.CurrentCamera
	if cam and now - steerSentAt >= STEER_RATE then
		steerSentAt = now
		local flat = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.05 then
			flat = flat.Unit
			Net.event("ModSteer"):FireServer(current, flat.X, flat.Z, false)
		end
	end
end

-- Per frame -----------------------------------------------------------------------------

local function update(_dt: number)
	frame += 1
	local now = os.clock()
	local character = player.Character

	-- Dash: the simulation dashed (DashStart moved on). The gun dips and the
	-- free hand gestures the way we go; the camera punches, rolls and leads.
	-- (A re-simulated start a few ms off isn't a new dash.)
	local dashStart = number(character, "DashStart", 0)
	if dashStart > lastDashStart + 0.05 then
		lastDashStart = dashStart
		local velocity = character and character:GetAttribute("DashVelocity")
		local cam = Workspace.CurrentCamera
		if typeof(velocity) == "Vector3" and velocity.Magnitude > 0.1 and cam then
			local feel = Config.DASH_FEEL
			local dir = velocity.Unit
			local localDir = cam.CFrame:VectorToObjectSpace(dir)
			ViewmodelController.gesture(
				if math.abs(localDir.X) > math.abs(localDir.Z)
					then (if localDir.X > 0 then "DashRight" else "DashLeft")
					else (if localDir.Z < 0 then "DashForward" else "DashBack"),
				"Dash"
			)
			CameraController.punchFov(feel.fov, feel.fovTime)
			CameraController.rollKick(-localDir.X * feel.roll, feel.rollTime)
			CameraController.lunge(dir * feel.lunge, feel.lungeTime)
			CameraController.shake(feel.shake)
		end
	end
	-- Updraft: the free hand flicks down, the gun tilts a little (it stays
	-- ready), the camera lurches up.
	local updraftAt = number(character, "UpdraftAt", 0)
	if updraftAt > lastUpdraftAt + 0.05 then
		lastUpdraftAt = updraftAt
		local feel = Config.UPDRAFT_FEEL
		ViewmodelController.gesture("UpdraftDown", "Updraft")
		CameraController.punchFov(feel.fov, feel.fovTime)
		CameraController.lunge(Vector3.new(0, feel.lurch, 0), feel.lurchTime)
		CameraController.shake(feel.shake)
	end
	-- Recall: the wind-up (the hand twists, the view pulls in, no shots),
	-- then the arrival (a kick and a settle).
	local windupUntil = number(character, "RecallWindupUntil", 0)
	if windupUntil > lastRecallWindup + 0.05 then
		lastRecallWindup = windupUntil
		local left = windupUntil - Workspace:GetServerTimeNow()
		if left > 0 then
			ViewmodelController.gesture("RecallTwist", "Recall")
			CameraController.punchFov(-12, left)
			WeaponController.blockFire(left + 0.05)
		end
	end
	local recallAt = number(character, "RecallAt", 0)
	if recallAt > lastRecallAt + 0.05 then
		lastRecallAt = recallAt
		CameraController.punchFov(6, 0.3)
		CameraController.shake(1.2)
	end
	stepRecallHold(now)

	if phase == "Equipping" and now - phaseAt >= Config.EQUIP_TIME then
		phase = "Held"
		local q = queued
		queued = nil
		if q then
			use(q)
		end
	elseif phase == "Using" and now - phaseAt >= Config.USE_TIME then
		endHold(true) -- the server already let go; this is only a backstop
	elseif phase == "Steering" then
		stepSteer(now)
	elseif phase == "Charging" then
		-- The same watchdog as Held: no Mod, or the server never took the hold.
		local view = ModController.slot(current)
		if not view.def or not view.stats or view.id == nil then
			endHold(true)
		elseif now - phaseAt > 0.6 and player:GetAttribute("ModHeld") ~= current then
			endHold(false)
		else
			stepCharge(now)
		end
	end

	if phase == "Equipping" or phase == "Held" then
		local view = ModController.slot(current)
		local def, stats = view.def, view.stats
		if not def or not stats or view.id == nil then
			endHold(true)
			return
		end
		-- The server never took the hold (refused, or slot changed): drop it.
		if
			phase == "Held"
			and now - phaseAt > 0.6
			and player:GetAttribute("ModHeld") ~= current
		then
			endHold(false)
			return
		end
		if def.activation == "HeldThrow" then
			drawArc(def.id, stats)
		elseif def.activation == "HeldPlace" then
			drawPlacement(def.id, stats)
		elseif def.activation == "HeldTarget" then
			local t = healTarget(stats)
			showTarget(if t == player.Character then nil else t)
		end
	end
end

-- The held-mode hint ("LMB Throw · RMB Lob · Q Cancel"), or a short warning
-- after a refused press (second value true). nil: nothing to show.
function ModController.hint(): (string?, boolean)
	local f = flash
	if f and os.clock() - f.at < 1.4 then
		return f.text, true
	end
	if phase ~= "Equipping" and phase ~= "Held" then
		return nil, false
	end
	local view = ModController.slot(current)
	local def = view.def
	if not def then
		return nil, false
	end
	local lmb, rmb = useLabels()
	local parts = {}
	local primary = def.hint.primary
	if def.id == "HealOrb" and view.stats and healTarget(view.stats) == player.Character then
		primary = "Heal self"
	end
	if primary then
		table.insert(parts, lmb .. " " .. primary)
	end
	if def.hint.alt then
		local alt = def.hint.alt
		if def.activation == "HeldCharge" then
			alt ..= ": " .. chargeBounces
		end
		table.insert(parts, rmb .. " " .. alt)
	end
	table.insert(parts, ModController.keyLabel(current) .. " Cancel")
	return table.concat(parts, "  ·  "), false
end

function ModController.useAlt()
	use("Alt")
end

function ModController.start()
	for slot, p in PREFIXES do
		InputController.onPressed(p, function()
			onModPressed(slot)
		end)
	end
	InputController.onPressed("Fire", function()
		use("Primary")
	end)
	InputController.onPressed("Aim", function()
		use("Alt")
	end)
	for _, name in { "Primary", "Secondary", "Melee", "CycleWeapon", "QuickMelee" } do
		InputController.onPressed(name, function()
			if phase == "Equipping" or phase == "Held" then
				cancelByPlayer()
			end
		end)
	end
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	player.CharacterRemoving:Connect(function()
		endHold(false)
		lastDashStart = 0
		lastUpdraftAt = 0
		lastRecallWindup = 0
		lastRecallAt = 0
		recallHold = nil
	end)
	local function watchDeath(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				endHold(false)
			end)
		end
	end
	player.CharacterAdded:Connect(watchDeath)
	if player.Character then
		task.spawn(watchDeath, player.Character)
	end
	RunService:BindToRenderStep("GGMods", Enum.RenderPriority.Input.Value + 2, update)
end

return ModController
