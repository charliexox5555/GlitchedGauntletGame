--!strict
-- Cosmetic mesh welds ride the stock rig. Only the local inspect pose drives
-- them, and the stored rest transform is restored when inspect ends.
local CosmeticInspect = {}

type Part = {
	weld: Weld,
	rest: CFrame,
	pivot: Vector3,
	axis: Vector3,
	kind: string,
	distance: number,
}

export type State = {
	parts: { Part },
	active: boolean,
}

function CosmeticInspect.new(model: Model): State?
	local parts = {}
	local scale = model:GetScale()
	for _, part in model:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end
		local kind = part:GetAttribute("CosmeticInspect")
		local pivot = part:GetAttribute("CosmeticInspectPivot")
		local axis = part:GetAttribute("CosmeticInspectAxis")
		local travel = part:GetAttribute("CosmeticInspectTravel")
		local weld = part:FindFirstChild("SkinCosmeticWeld")
		if
			type(kind) == "string"
			and typeof(pivot) == "Vector3"
			and typeof(axis) == "Vector3"
			and axis.Magnitude > 0.001
			and weld
			and weld:IsA("Weld")
		then
			table.insert(parts, {
				weld = weld,
				rest = weld.C0,
				pivot = pivot * scale,
				axis = axis.Unit,
				kind = kind,
				distance = if typeof(travel) == "number" then travel * scale else 0,
			})
		end
	end
	if #parts == 0 then
		return nil
	end
	return { parts = parts, active = false }
end

local function ease(progress: number, from: number, to: number): number
	local t = math.clamp((progress - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

function CosmeticInspect.step(state: State, progress: number?)
	if progress == nil then
		if state.active then
			for _, p in state.parts do
				p.weld.C0 = p.rest
			end
			state.active = false
		end
		return
	end
	state.active = true
	for _, p in state.parts do
		if p.kind == "MeterSweep" then
			local travel = ease(progress, 0.23, 0.60) - ease(progress, 0.60, 0.78)
			p.weld.C0 = p.rest + p.axis * (p.distance * travel)
			continue
		end
		local angle = 0
		if p.kind == "Latch" then
			angle = -1.05 * (ease(progress, 0.23, 0.53) - ease(progress, 0.53, 0.80))
		elseif p.kind == "Dial" then
			angle = math.pi / 4 * ease(progress, 0.23, 0.59)
		elseif p.kind == "ReelFront" then
			angle = math.rad(137) * ease(progress, 0.23, 0.73)
		elseif p.kind == "ReelRear" then
			angle = math.rad(197) * ease(progress, 0.23, 0.73)
		end
		p.weld.C0 = CFrame.new(p.pivot)
			* CFrame.fromAxisAngle(p.axis, angle)
			* CFrame.new(-p.pivot)
			* p.rest
	end
end

return CosmeticInspect
