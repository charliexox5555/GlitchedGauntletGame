--!strict
-- The Slipframe receiver wakes up from rear to front. All moving pieces and
-- light live in the camera clone and are solved with the gun in the same frame.
local SlipframeEffects = {}

type Pulse = "Fire" | "Seat"

type Finish = {
	part: MeshPart,
	color: Color3,
	material: Enum.Material,
}

export type State = {
	panel: Motor6D,
	insert: Finish,
	seam: Finish,
	foreEnd: Finish,
	contacts: { Part },
	railGlint: Part,
	railMotion: Motor6D,
	light: PointLight,
	scale: number,
	pulse: Pulse?,
	elapsed: number,
	lit: boolean,
}

local FIRE_TIME = 0.17
local SEAT_TIME = 0.16
local ICE = Color3.fromRGB(191, 232, 255)
local BLUE = Color3.fromRGB(100, 175, 245)

local function finish(part: MeshPart): Finish
	return { part = part, color = part.Color, material = part.Material }
end

local function glowPart(model: Model, name: string, size: Vector3, placement: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = placement
	part.Material = Enum.Material.Neon
	part.Color = ICE
	part.Transparency = 1
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function contactsInRecess(model: Model, seam: MeshPart, scale: number): { Part }
	local contacts = {}
	for i = 1, 3 do
		-- +X points toward the shooter and +Z faces out of the left recess.
		-- The contacts sit behind the closed blue insert's outer face.
		local offset = CFrame.new((2 - i) * seam.Size.X * 0.29, 0.013 * scale, 0.006 * scale)
		local contact = glowPart(
			model,
			"SlipframeContact" .. i,
			Vector3.new(seam.Size.X * 0.25, 0.010 * scale, 0.002 * scale),
			seam.CFrame * offset
		)
		local weld = Instance.new("Weld")
		weld.Part0 = seam
		weld.Part1 = contact
		weld.C0 = offset
		weld.Parent = contact
		table.insert(contacts, contact)
	end
	return contacts
end

function SlipframeEffects.new(model: Model, scale: number): State?
	local insert = model:FindFirstChild("SK_Root_SFInspectPanel")
	local seam = model:FindFirstChild("SK_Root_SFSeam")
	-- Guardian r05fx's two installed blue fore-end faces share this MeshPart.
	local foreEnd = model:FindFirstChild("SK_Root_02")
	if
		not insert
		or not insert:IsA("MeshPart")
		or not seam
		or not seam:IsA("MeshPart")
		or not foreEnd
		or not foreEnd:IsA("MeshPart")
	then
		return nil
	end
	local weld = insert:FindFirstChild("SkinCosmeticWeld")
	if not weld or not weld:IsA("Weld") or not weld.Part0 or weld.Part1 ~= insert then
		return nil
	end
	local panel = Instance.new("Motor6D")
	panel.Name = "SlipframeInspectMotion"
	panel.Part0 = weld.Part0
	panel.Part1 = insert
	panel.C0 = weld.C0
	panel.C1 = weld.C1
	weld:Destroy()
	panel.Parent = insert

	local railGlint = glowPart(
		model,
		"SlipframeRailGlint",
		Vector3.new(0.24, 0.010, 0.0018) * scale,
		foreEnd.CFrame
	)
	local railMotion = Instance.new("Motor6D")
	railMotion.Name = "SlipframeRailMotion"
	railMotion.Part0 = foreEnd
	railMotion.Part1 = railGlint
	railMotion.Parent = railGlint

	local light = Instance.new("PointLight")
	light.Name = "SlipframeReceiverLight"
	light.Range = 2.2 * scale
	light.Color = BLUE
	light.Brightness = 0
	light.Enabled = false
	light.Shadows = false
	light.Parent = seam

	return {
		panel = panel,
		insert = finish(insert),
		seam = finish(seam),
		foreEnd = finish(foreEnd),
		contacts = contactsInRecess(model, seam, scale),
		railGlint = railGlint,
		railMotion = railMotion,
		light = light,
		scale = scale,
		elapsed = 0,
		lit = false,
	}
end

function SlipframeEffects.pulse(state: State, kind: Pulse)
	state.pulse = kind
	state.elapsed = 0
end

local function ease(progress: number, from: number, to: number): number
	local t = math.clamp((progress - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

local function paint(f: Finish, hot: Color3, amount: number, emissive: boolean)
	f.part.Color = f.color:Lerp(hot, amount)
	f.part.Material = if emissive then Enum.Material.Neon else f.material
end

local function lightBody(state: State, receiver: number, foreEnd: number, brightness: number)
	local lit = receiver > 0 or foreEnd > 0 or brightness > 0
	if not lit and not state.lit then
		return
	end
	state.lit = lit
	paint(state.seam, ICE, receiver, receiver >= 0.18)
	paint(state.insert, BLUE, receiver * 0.70, false)
	paint(state.foreEnd, ICE, foreEnd, false)
	state.light.Enabled = brightness > 0.03
	state.light.Brightness = brightness
end

local function drawRail(state: State, progress: number, opacity: number)
	local plate = state.foreEnd.part.Size
	local scale = state.scale
	local length = (0.27 - 0.09 * progress) * scale
	state.railGlint.Size = Vector3.new(length, 0.010 * scale, 0.0018 * scale)
	state.railMotion.Transform = CFrame.new(
		(0.5 - progress) * (plate.X - length - 0.17 * scale),
		0.0085 * scale,
		plate.Z * 0.5 + 0.0012 * scale
	)
	state.railGlint.Transparency = 1 - opacity
end

local function showInspect(state: State, progress: number)
	local lift = ease(progress, 0.19, 0.24) - ease(progress, 0.755, 0.80)
	local slide = ease(progress, 0.24, 0.34) - ease(progress, 0.68, 0.755)
	state.panel.Transform =
		CFrame.new(Vector3.new(0.072 * slide, 0.018 * slide, 0.019 * lift) * state.scale)

	local fade = 1 - ease(progress, 0.63, 0.735)
	for i, contact in state.contacts do
		local startAt = 0.32 + (i - 1) * 0.055
		local rise = ease(progress, startAt, startAt + 0.025)
		local settle = ease(progress, startAt + 0.035, startAt + 0.15)
		contact.Color = ICE:Lerp(BLUE, settle * 0.6)
		contact.Transparency = 1 - rise * fade * (0.98 - 0.46 * settle)
	end
	local receiver = ease(progress, 0.32, 0.39) * fade
	local foreEnd = ease(progress, 0.46, 0.54) * (1 - ease(progress, 0.56, 0.72))
	lightBody(state, receiver, foreEnd * 0.76, receiver * 0.62 + foreEnd * 0.28)
	local sweep = math.clamp((progress - 0.46) / 0.23, 0, 1)
	drawRail(state, sweep, ease(sweep, 0, 0.12) * (1 - ease(sweep, 0.62, 1)))
end

function SlipframeEffects.step(
	state: State,
	dt: number,
	inspect: number?,
	ads: number,
	visible: boolean
)
	if visible and inspect then
		state.pulse = nil
		showInspect(state, inspect)
		return
	end
	state.panel.Transform = CFrame.identity
	for _, contact in state.contacts do
		contact.Transparency = 1
	end

	local pulse = state.pulse
	if visible and pulse then
		local duration = if pulse == "Fire" then FIRE_TIME else SEAT_TIME
		local t = state.elapsed / duration
		state.elapsed += dt
		if t < 1 then
			local fade = (1 - t) ^ 1.2 * (1 - 0.44 * ads)
			if pulse == "Fire" then
				local forward = (0.66 + 0.34 * ease(t, 0, 0.16)) * (1 - t) * (1 - 0.34 * ads)
				lightBody(state, fade, forward, fade * 0.95)
				drawRail(state, math.clamp(t / 0.85, 0, 1), (1 - t) * (1 - 0.38 * ads))
			else
				lightBody(state, fade * 0.72, fade * 0.24, fade * 0.45)
				state.railGlint.Transparency = 1
			end
			return
		end
	end
	state.pulse = nil
	state.railGlint.Transparency = 1
	lightBody(state, 0, 0, 0)
end

return SlipframeEffects
