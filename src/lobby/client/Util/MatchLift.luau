--!strict
-- Match-found motion for the Lobby V5 queue bays (vault/02 Art/Lobby V5 Plan.md → Match-found motion).
-- When your match is found while you stand on a bay's team square, a lift plate rises out of that square and
-- carries you up (a short coil down, a fast Quint rise that overshoots a little and settles), a team-coloured
-- light column climbs with it, and the bay's lightbox sign flashes to MATCH FOUND. MatchFoundController waits
-- `play()`'s returned hold before it dims the screen, and calls `stop()` when the queue goes back to idle
-- (a failed teleport, or Studio's skipped one) so the plate, sign and character are put back.
-- Everything here is local to this player's client; the server is not involved and nothing is sent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MatchLift = {}

local player = Players.LocalPlayer

-- motion (seconds / studs)
local COIL_T = 0.14 -- dip before the rise
local COIL = 0.3
local RISE_T = 1.45
local RISE = 7
local OVERSHOOT = 0.35
local SETTLE_T = 0.35
local HOLD = 2.1 -- how long the overlay waits; the server teleports 3.5 s after "found"
-- the queue bays' team colours (keep in step with LobbyPadFx TEAM)
local TEAM = { [1] = Color3.fromHex("FFB627"), [2] = Color3.fromHex("2EC8FF") }
local GOLD = Color3.fromHex("FFB627")
local STAND_H = 8 -- studs above a square that still count as standing on it

type Active = {
	model: Model,
	conn: RBXScriptConnection?,
	root: BasePart?,
	rootStart: CFrame,
	rootWasAnchored: boolean,
	restoreSign: (() -> ())?,
	started: number,
}
local active: Active? = nil

local function inside(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X
		and math.abs(rel.Z) <= half.Z
		and rel.Y >= -half.Y - 2
		and rel.Y <= half.Y + STAND_H
end

-- the V5 bay square under the character, and its bay model (Bay_xx_mode under Duels.QueueBays)
local function findSquare(pos: Vector3): (BasePart?, Model?)
	for _, inst in CollectionService:GetTagged("LobbyPadSquare") do
		if inst:IsA("BasePart") and inside(inst, pos) then
			local pad = inst.Parent
			local bay = pad and pad.Parent
			if bay and bay:IsA("Model") and bay.Parent and bay.Parent.Name == "QueueBays" then
				return inst, bay
			end
		end
	end
	return nil, nil
end

local function teamOf(square: BasePart): number
	local name = square.Name
	return if string.sub(name, -1) == "B" then 2 else 1
end

-- flash the bay's sign to MATCH FOUND; returns a function that puts it back
local function flashSign(bay: Model): (() -> ())?
	local sign = bay:FindFirstChild("Sign")
	local face = sign and sign:FindFirstChild("Face")
	local gui = face and face:FindFirstChildWhichIsA("SurfaceGui")
	local bg = gui and gui:FindFirstChildWhichIsA("Frame")
	if not bg then
		return nil
	end
	local frame = bg :: Frame
	local status: TextLabel? = nil
	for _, c in frame:GetChildren() do
		if c:IsA("TextLabel") and c.TextXAlignment == Enum.TextXAlignment.Right then
			status = c
		end
	end
	local oldBg = frame.BackgroundColor3
	local oldText = if status then status.Text else ""
	if status then
		status.Text = "MATCH FOUND"
	end
	-- three quick flashes, then hold gold
	task.spawn(function()
		for _ = 1, 3 do
			if not frame.Parent then
				return
			end
			frame.BackgroundColor3 = GOLD
			task.wait(0.09)
			frame.BackgroundColor3 = oldBg
			task.wait(0.07)
		end
		frame.BackgroundColor3 = GOLD
	end)
	return function()
		frame.BackgroundColor3 = oldBg
		if status then
			status.Text = oldText
		end
	end
end

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- height of the lift at time t
local function heightAt(t: number): number
	if t < COIL_T then
		return -COIL
			* TweenService:GetValue(t / COIL_T, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end
	t -= COIL_T
	if t < RISE_T then
		local q =
			TweenService:GetValue(t / RISE_T, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		return -COIL + (RISE + COIL + OVERSHOOT) * q
	end
	t -= RISE_T
	local s = TweenService:GetValue(
		math.min(1, t / SETTLE_T),
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	return RISE + OVERSHOOT * (1 - s)
end

-- Starts the lift if the player stands on a V5 bay square. Returns how long the overlay should wait (0 = no lift).
function MatchLift.play(): number
	if active then
		return math.max(0, HOLD - (os.clock() - active.started))
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return 0
	end
	local square, bay = findSquare(root.Position)
	if not (square and bay) then
		return 0
	end
	local colour = TEAM[teamOf(square)]
	local model = Instance.new("Model")
	model.Name = "LobbyMatchLift"
	model.Parent = workspace
	local top = square.CFrame * CFrame.new(0, square.Size.Y / 2, 0)
	local w, d = square.Size.X - 0.4, square.Size.Z - 0.4
	-- the plate: deck, a dark under-skirt and team-colour edge strips
	local base = top * CFrame.new(0, -0.1, 0) -- plate top 0.02 above the square (no shared face, feet stay put)
	local plate = part(
		model,
		Vector3.new(w, 0.24, d),
		base,
		square.Color:Lerp(Color3.new(1, 1, 1), 0.15),
		Enum.Material.SmoothPlastic
	)
	local skirt = part(
		model,
		Vector3.new(w - 0.6, 0.9, d - 0.6),
		base * CFrame.new(0, -0.57, 0),
		Color3.fromRGB(52, 54, 58),
		Enum.Material.Metal
	)
	local edges: { { p: Part, off: CFrame } } = {}
	for _, e in
		{
			{ Vector3.new(w, 0.08, 0.25), CFrame.new(0, 0.16, d / 2 - 0.125) },
			{ Vector3.new(w, 0.08, 0.25), CFrame.new(0, 0.16, -d / 2 + 0.125) },
			{ Vector3.new(0.25, 0.08, d - 0.5), CFrame.new(w / 2 - 0.125, 0.16, 0) },
			{ Vector3.new(0.25, 0.08, d - 0.5), CFrame.new(-w / 2 + 0.125, 0.16, 0) },
		}
	do
		table.insert(edges, {
			p = part(
				model,
				e[1],
				base * e[2],
				colour:Lerp(Color3.new(0, 0, 0), 0.25),
				Enum.Material.Neon
			),
			off = e[2],
		})
	end
	local column = part(model, Vector3.new(w - 0.8, 0.1, d - 0.8), base, colour, Enum.Material.Neon)
	column.Transparency = 1
	local glow = Instance.new("PointLight")
	glow.Color = colour
	glow.Brightness = 0
	glow.Range = 16
	glow.Shadows = false
	glow.Parent = plate

	local rootStart = root.CFrame
	local a: Active = {
		model = model,
		root = root,
		rootStart = rootStart,
		rootWasAnchored = root.Anchored,
		started = os.clock(),
	}
	a.restoreSign = flashSign(bay)
	active = a

	-- carry the character: anchor the root and move it with the plate (its idle animation keeps playing)
	root.Anchored = true
	a.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - a.started
		local y = heightAt(t)
		local cf = base + Vector3.new(0, y, 0)
		plate.CFrame = cf
		skirt.CFrame = cf * CFrame.new(0, -0.57, 0)
		for _, e in edges do
			e.p.CFrame = cf * e.off
		end
		-- the light column climbs above the plate and fades in, then thins
		local c = math.clamp(t / 0.6, 0, 1)
		local h = 2
			+ 14 * TweenService:GetValue(c, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		column.Size = Vector3.new(column.Size.X, h, column.Size.Z)
		column.CFrame = cf * CFrame.new(0, 0.12 + h / 2, 0)
		column.Transparency = 0.93
			- 0.07 * math.sin(math.min(1, t / 0.6) * math.pi / 2)
			+ 0.05 * math.clamp((t - 1.2) / 0.8, 0, 1)
		glow.Brightness = 2.5 * c
		if root.Parent then
			root.CFrame = rootStart + Vector3.new(0, y, 0)
		end
	end)
	return HOLD
end

-- Puts everything back (the queue left "found" without a teleport).
function MatchLift.stop()
	local a = active
	if not a then
		return
	end
	active = nil
	if a.conn then
		a.conn:Disconnect()
	end
	if a.restoreSign then
		a.restoreSign()
	end
	local root = a.root
	if root and root.Parent then
		root.CFrame = a.rootStart -- back down onto the pad, not dropped from the top
		root.Anchored = a.rootWasAnchored
	end
	a.model:Destroy()
end

function MatchLift.isActive(): boolean
	return active ~= nil
end

return MatchLift
