--!strict
-- One receiver glint shared by inspect, fire and magazine seat. The stock
-- template has ordinary welds. Only the camera clone gets driven joints.
local SlipframeEffects = {}

type Pulse = "Fire" | "Seat"

export type State = {
	panel: Motor6D,
	stroke: Motor6D,
	glint: Part,
	seam: MeshPart,
	scale: number,
	pulse: Pulse?,
	elapsed: number,
}

local FIRE_TIME = 0.10
local SEAT_TIME = 0.15

local function motor(part0: BasePart, part1: BasePart): Motor6D
	local joint = Instance.new("Motor6D")
	joint.Part0 = part0
	joint.Part1 = part1
	return joint
end

function SlipframeEffects.new(model: Model, scale: number): State?
	local insert = model:FindFirstChild("SK_Root_SFInspectPanel")
	local seam = model:FindFirstChild("SK_Root_SFSeam")
	if not insert or not insert:IsA("MeshPart") or not seam or not seam:IsA("MeshPart") then
		return nil
	end
	local weld = insert:FindFirstChild("SkinCosmeticWeld")
	if not weld or not weld:IsA("Weld") or not weld.Part0 or weld.Part1 ~= insert then
		return nil
	end
	local panel = motor(weld.Part0, insert)
	panel.Name = "SlipframeInspectMotion"
	panel.C0 = weld.C0
	panel.C1 = weld.C1
	weld:Destroy()
	panel.Parent = insert

	local glint = Instance.new("Part")
	glint.Name = "SlipframeSeamGlint"
	glint.Size = Vector3.new(0.05, 0.002, 0.001) * scale
	glint.CFrame = seam.CFrame
	glint.Material = Enum.Material.Neon
	glint.Color = Color3.fromRGB(165, 220, 242)
	glint.Transparency = 1
	glint.Anchored = true
	glint.CanQuery = false
	glint.CanTouch = false
	glint.CanCollide = false
	glint.CastShadow = false
	glint.Parent = model
	local stroke = motor(seam, glint)
	stroke.Name = "SlipframeSeamMotion"
	stroke.Parent = glint

	return { panel = panel, stroke = stroke, glint = glint, seam = seam, scale = scale, elapsed = 0 }
end

function SlipframeEffects.pulse(state: State, kind: Pulse)
	state.pulse = kind
	state.elapsed = 0
end

local function ease(progress: number, from: number, to: number): number
	local t = math.clamp((progress - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

local function placeStroke(state: State, fromRear: number, length: number, alpha: number)
	local size = state.seam.Size
	-- The flat importer points the mesh's +X toward the rear and +Z out of
	-- its player-facing side. Keep the glow bounded by the metal inlay.
	local usable = size.X - length
	state.stroke.Transform =
		CFrame.new((0.5 - fromRear) * usable, size.Y * 0.03, size.Z * 0.5 + 0.001 * state.scale)
	state.glint.Size = Vector3.new(length, size.Y * 0.58, 0.0012 * state.scale)
	state.glint.Transparency = 1 - alpha
end

function SlipframeEffects.step(
	state: State,
	dt: number,
	inspect: number?,
	ads: number,
	visible: boolean
)
	local progress = if visible then inspect else nil
	if progress then
		-- Lift clear of the beveled pocket before sliding up. On the return,
		-- lower into alignment first, then let the insert settle flush.
		local lift = ease(progress, 0.16, 0.20) - ease(progress, 0.435, 0.475)
		local slide = ease(progress, 0.20, 0.245) - ease(progress, 0.40, 0.435)
		state.panel.Transform =
			CFrame.new(0, 0.025 * slide * state.scale, 0.019 * lift * state.scale)
	else
		state.panel.Transform = CFrame.identity
	end

	local pulse = state.pulse
	state.elapsed += dt
	if not visible or progress then
		state.pulse = nil
	end
	if progress and progress >= 0.235 and progress < 0.43 then
		local pass = (progress - 0.235) / 0.195
		local alpha = ease(pass, 0, 0.16) * (1 - ease(pass, 0.76, 1))
		placeStroke(state, pass, 0.12 * state.scale, 0.94 * alpha)
	elseif visible and not progress and pulse then
		local duration = if pulse == "Fire" then FIRE_TIME else SEAT_TIME
		local t = state.elapsed / duration
		if t < 1 then
			local fade = (1 - t) ^ 1.35 * (1 - 0.78 * ads)
			if pulse == "Fire" then
				placeStroke(state, 0.04 + 0.23 * t, (0.074 - 0.03 * t) * state.scale, 0.62 * fade)
			else
				placeStroke(state, 0.035, (0.032 - 0.017 * t) * state.scale, 0.78 * fade)
			end
			return
		end
		state.pulse = nil
		state.glint.Transparency = 1
	else
		state.glint.Transparency = 1
	end
end

return SlipframeEffects
