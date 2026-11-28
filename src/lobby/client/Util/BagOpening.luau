--!strict
-- The goodie bag opening (Config/Crates `bag`, owner 2026-11-27; Lobby/GoodieBags rolls the prize on the server):
-- each bag drops in front of the opener and lands with a squash, wobbles while the server answers, then
-- strains, pops (the tie flies off, sparks) and one prize card rises out of it. Clones
-- ReplicatedStorage.Crates.GoodieBag and colours its parts by role suffix (Config/Crates), like Util/BlindBoxOpening.
-- Util/CaseOpening.start hands bag tiers here; same Handle shape.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PrizeArt = require(script.Parent.PrizeArt)

export type Handle = {
	reveal: (self: Handle, results: { LobbyNet.CaseReward }, onDone: (() -> ())?) -> boolean,
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}

local BagOpening = {}

local RUBIK = "rbxassetid://12187365977"
local HEAVY = Font.new(RUBIK, Enum.FontWeight.Heavy)
local BOLD = Font.new(RUBIK, Enum.FontWeight.Bold)
local INK = Color3.fromHex("F4F6F9")
local PLATE = Color3.fromHex("10141B")
local GOLD = Color3.fromHex("FFC83D")
-- how loud a prize lands: coins and Tickets are everyday, an item or a skin is the big one
local PRIZE_TIER: { [string]: string } = {
	Coins = "Common",
	Tickets = "Common",
	CharmBox = "Rare",
	PowerPack = "Epic",
	Case = "Epic",
	Rare = "Legendary", -- the skin prize's tier field is its skin tier
}
local ROLES = { "Body", "Frame", "Hardware", "Light", "Gem", "Interior" }
local HOLD = 2.6 -- s the prize card stays up

local function rootOf(p: Player): BasePart?
	local ch = p.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function play(spec: any, parent: Instance, gain: number)
	if not spec or gain <= 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = spec.id
	s.Volume = spec.volume * gain
	s.PlaybackSpeed = spec.pitch or 1
	if spec.start then
		s.TimePosition = spec.start
	end
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, if spec.cut then spec.cut + 0.3 else 5)
end

local function roleOf(name: string): string?
	for _, role in ROLES do
		if string.sub(name, -#role) == role then
			return role
		end
	end
	return nil
end

-- recolours a clone by part-name role (Sack_Body, Tie_Hardware, ...)
local function dress(model: Model, tierDef: Crates.Tier)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
			local role = roleOf(d.Name)
			local lookDef = role and (tierDef.roles :: any)[role]
			if lookDef then
				d.Color = lookDef.color
				d.Material = lookDef.material
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		end
	end
end

local function sparks(parent: Instance, color: Color3, count: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Vfx.SPARK
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(6, 13)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Parent = parent
	e:Emit(count)
	Debris:AddItem(e, 1.2)
end

-- the prize card that rises out of the bag: picture, a small kicker, the name
local function prizeCard(
	anchor: BasePart,
	r: LobbyNet.CaseReward,
	color: Color3,
	opener: string?
): (BillboardGui, UIScale)
	local g = Instance.new("BillboardGui")
	g.Name = "BagPrize"
	g.LightInfluence = 0
	g.Size = UDim2.fromScale(3, 3.6)
	g.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	g.MaxDistance = 120
	g.AlwaysOnTop = false
	g.Adornee = anchor
	g.Parent = anchor

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = g
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = holder

	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.fromScale(0.5, 0)
	art.Size = UDim2.fromScale(0.86, 0.62)
	art.ScaleType = Enum.ScaleType.Fit
	art.Image = PrizeArt.image(r) or ""
	art.Parent = holder

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0.66)
	plate.Size = UDim2.fromScale(1, 0.3)
	plate.BackgroundColor3 = PLATE
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = plate
	local edge = Instance.new("Frame") -- the tier strip along the top (no outline)
	edge.Name = "Edge"
	edge.BorderSizePixel = 0
	edge.BackgroundColor3 = color
	edge.Size = UDim2.new(1, 0, 0.07, 0)
	edge.Parent = plate

	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Position = UDim2.fromScale(0.06, 0.14)
	kicker.Size = UDim2.fromScale(0.88, 0.3)
	kicker.FontFace = BOLD
	kicker.TextScaled = true
	kicker.TextColor3 = color
	local word = PrizeArt.kicker(r)
	kicker.Text = if opener then string.upper(opener) .. "  ·  " .. word else word
	kicker.Parent = plate

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.46)
	title.Size = UDim2.fromScale(0.88, 0.44)
	title.FontFace = HEAVY
	title.TextScaled = true
	title.TextColor3 = INK
	title.Text = r.name
	title.Parent = plate
	return g, pop
end

function BagOpening.start(
	owner: Player,
	crateTier: number,
	isLocal: boolean,
	count: number
): Handle?
	local ownerRoot = rootOf(owner)
	local folder = ReplicatedStorage:FindFirstChild(Crates.FOLDER)
	local tierDef = Crates.TIERS[crateTier]
	local template = folder and tierDef and folder:FindFirstChild(tierDef.template or "GoodieBag")
	if not (ownerRoot and tierDef and template and template:IsA("Model")) then
		return nil
	end
	local gain = if isLocal then 1 else 0.42
	local reduced = UiMotion.reduced()
	local scale = tierDef.scale or 1.5
	local n = math.clamp(count, 1, Cfg.MAX_CRATES)
	-- off to the sides of your view so your own body never hides a bag; a third one further back, over your shoulder
	local angles = if n == 1 then { 24 } elseif n == 2 then { -26, 26 } else { -40, 0, 40 }
	local dists = if n == 1 then { 8 } elseif n == 2 then { 8, 8 } else { 8, 17, 8 }

	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	-- your own bags land where you're looking (in front of the camera, past you); someone else's in front of them
	local camera = workspace.CurrentCamera
	local look = (
		if isLocal and camera then camera.CFrame.LookVector else ownerRoot.CFrame.LookVector
	) * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	local origin = ownerRoot.Position

	type Bag = { model: Model, home: CFrame, part: BasePart, tie: { BasePart } }
	local bags: { Bag } = {}
	local dead = false
	local phase = "drop"
	local sway: RBXScriptConnection? = nil

	local function cleanup()
		dead = true
		if sway then
			sway:Disconnect()
			sway = nil
		end
		for _, b in bags do
			b.model:Destroy()
		end
		table.clear(bags)
	end

	for i = 1, n do
		local dir = CFrame.Angles(0, math.rad(angles[i]), 0):VectorToWorldSpace(look)
		local dist = dists[i]
		local target = origin + dir * dist
		local hit = workspace:Raycast(origin, target - origin, params)
		if hit then
			target = origin + dir * math.max(2.5, (hit.Position - origin).Magnitude - 1.2)
		end
		local down = workspace:Raycast(target + Vector3.yAxis * 4, -Vector3.yAxis * 14, params)
		local floorY = if down and down.Normal.Y >= 0.7 then down.Position.Y else origin.Y - 3
		local home = CFrame.lookAt(
			Vector3.new(target.X, floorY, target.Z),
			Vector3.new(origin.X, floorY, origin.Z)
		)
		local model = (template :: Model):Clone()
		model:ScaleTo(scale)
		dress(model, tierDef)
		-- the pivot is the base centre (tools/blender/crates/build_goodie_bag.py)
		model:PivotTo(home * CFrame.new(0, 9, 0))
		model.Parent = workspace
		local sack = model:FindFirstChild("Sack_Body")
		local part = if sack and sack:IsA("BasePart")
			then sack
			else model:FindFirstChildWhichIsA("BasePart", true)
		if not part then
			model:Destroy()
			continue
		end
		local tie: { BasePart } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Top_" then -- the ruffle, tie and tag pop off
				table.insert(tie, d)
			end
		end
		table.insert(bags, { model = model, home = home, part = part :: BasePart, tie = tie })
	end
	if #bags == 0 then
		return nil
	end

	-- drop + squash, staggered; then a soft idle wobble until the answer comes
	task.spawn(function()
		play(Cfg.SOUNDS.Toss, bags[1].part, gain)
		for i, b in bags do
			task.delay((i - 1) * 0.08, function()
				local t0 = os.clock()
				local fall = if reduced then 0.01 else 0.32
				while not dead do
					local t = math.min((os.clock() - t0) / fall, 1)
					local y = 9 * (1 - t * t)
					b.model:PivotTo(b.home * CFrame.new(0, y, 0))
					if t >= 1 then
						break
					end
					RunService.RenderStepped:Wait()
				end
				if dead then
					return
				end
				play(Cfg.SOUNDS.Land, b.part, gain)
				sparks(b.part, tierDef.accent, 6)
			end)
		end
		task.wait(0.32 + 0.08 * #bags)
		if dead then
			return
		end
		phase = "wait"
		local t0 = os.clock()
		sway = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			for i, b in bags do
				local w = if reduced then 0 else math.sin(t * 3.2 + i) * 0.06
				b.model:PivotTo(b.home * CFrame.Angles(0, 0, w))
			end
		end)
	end)

	local handle = {} :: any
	function handle.isDead(_self: Handle): boolean
		return dead
	end
	function handle.abort(_self: Handle)
		cleanup()
	end
	function handle.reveal(
		_self: Handle,
		results: { LobbyNet.CaseReward },
		onDone: (() -> ())?
	): boolean
		if dead or phase == "open" then
			return false
		end
		phase = "open"
		task.spawn(function()
			-- wait for the drop to finish (the wobble starts after it)
			local t0 = os.clock()
			while not sway and not dead and os.clock() - t0 < 1.5 do
				task.wait()
			end
			if sway then
				sway:Disconnect()
				sway = nil
			end
			local opener = if isLocal then nil else owner.DisplayName
			local best = "Common"
			for _, r in results do
				local tier = PRIZE_TIER[r.tier] or "Common"
				if (Skins.TIERS :: any)[tier].order > (Skins.TIERS :: any)[best].order then
					best = tier
				end
			end
			-- strain: a growing shake, longer for a better prize
			local strain = if reduced
				then 0.1
				else 0.55 + 0.2 * ((Skins.TIERS :: any)[best].order - 1)
			play(Cfg.SOUNDS.Rattle, bags[1].part, gain * 0.8)
			local s0 = os.clock()
			while not dead and os.clock() - s0 < strain do
				local k = (os.clock() - s0) / strain
				for i, b in bags do
					local w = math.sin((os.clock() - s0) * 38 + i) * 0.09 * k
					local puff = 1 + 0.06 * k
					b.model:PivotTo(b.home * CFrame.Angles(w, 0, w * 0.6))
					b.model:ScaleTo(scale * puff)
				end
				RunService.RenderStepped:Wait()
			end
			if dead then
				return
			end
			play(Cfg.SOUNDS.Burst, bags[1].part, gain)
			play((Cfg.REVEAL :: any)[best], bags[1].part, gain)
			local cards: { BillboardGui } = {}
			for i, b in bags do
				local r = results[i] or results[#results]
				if not r then
					continue
				end
				local tier = PRIZE_TIER[r.tier] or "Common"
				local color = if r.coins or r.tickets
					then GOLD
					else (Skins.TIERS :: any)[tier].color
				b.model:ScaleTo(scale)
				b.model:PivotTo(b.home)
				sparks(b.part, color, 14 + 8 * (Skins.TIERS :: any)[tier].order)
				-- the tie and tag fly off and fade
				for _, p in b.tie do
					local away = (p.Position - b.part.Position) * Vector3.new(1, 0, 1)
					local fling = (if away.Magnitude > 1e-3 then away.Unit else Vector3.xAxis) * 1.6
						+ Vector3.yAxis * 2.2
					TweenService:Create(
						p,
						TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
						{
							CFrame = p.CFrame + fling,
							Transparency = 1,
						}
					):Play()
				end
				local anchor = Instance.new("Part")
				anchor.Name = "BagPrizeAnchor"
				anchor.Anchored = true
				anchor.CanCollide = false
				anchor.CanQuery = false
				anchor.CanTouch = false
				anchor.Transparency = 1
				anchor.Size = Vector3.one * 0.2
				anchor.CFrame = b.home * CFrame.new(0, 1.2 * scale, 0)
				anchor.Parent = b.model
				local card, pop = prizeCard(anchor, r, color, opener)
				table.insert(cards, card)
				task.delay((i - 1) * 0.06, function()
					local c0 = os.clock()
					while not dead and pop.Parent do
						local t = math.min((os.clock() - c0) / 0.36, 1)
						pop.Scale = if reduced then 1 else backOut(t)
						card.StudsOffsetWorldSpace =
							Vector3.new(0, 1.2 + 1.6 * (1 - (1 - t) ^ 5), 0)
						if t >= 1 then
							break
						end
						RunService.RenderStepped:Wait()
					end
				end)
				-- the bag deflates as the prize comes out
				task.spawn(function()
					local d0 = os.clock()
					while not dead do
						local t = math.min((os.clock() - d0) / 0.5, 1)
						b.model:ScaleTo(scale * (1 - 0.35 * t))
						if t >= 1 then
							break
						end
						RunService.RenderStepped:Wait()
					end
				end)
			end
			task.wait(HOLD)
			if dead then
				return
			end
			play(Cfg.SOUNDS.Collect, bags[1].part, gain)
			for _, c in cards do
				local holder = c:FindFirstChildOfClass("Frame")
				local pop = holder and holder:FindFirstChildOfClass("UIScale")
				if pop then
					TweenService:Create(
						pop,
						TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Scale = 0 }
					):Play()
				end
			end
			task.wait(0.16)
			cleanup()
			if onDone then
				onDone()
			end
		end)
		return true
	end
	return handle :: Handle
end

return BagOpening
