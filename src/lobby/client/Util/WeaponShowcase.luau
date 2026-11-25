--!strict
-- Presentation-only versions of the Tempest water ribbons and Ruin shard energy.
-- Use simple 3D geometry so the same accents render in the world and a ViewportFrame.

local RS = game:GetService("ReplicatedStorage")
local UiMotion = require(RS.Shared.UiMotion)
local StateValues = require(RS.Shared.StateValues)
local SkinPreview = require(RS.Shared.Config.SkinPreview)
local Tempest = SkinPreview.TEMPEST
local Ruin = SkinPreview.SHADOW_MIST

local WeaponShowcase = {}
WeaponShowcase.TAG = "LobbyWeaponShowcase"

local WATER = Tempest.WATER
local MINT = Color3.fromRGB(105, 228, 193)

type Look = { tint: Color3, peak: Color3, ambient: Color3, key: Color3, ribbons: boolean }
local LOOKS: { [string]: Look } = {
	TempestStrike = {
		tint = WATER,
		peak = Tempest.FLASH_CORE,
		ambient = Color3.fromRGB(198, 213, 237),
		key = Color3.fromRGB(238, 248, 255),
		ribbons = true,
	},
	RuinBlighted = {
		tint = MINT,
		peak = Color3.fromRGB(186, 255, 233),
		ambient = Color3.fromRGB(194, 216, 208),
		key = Color3.fromRGB(255, 242, 221),
		ribbons = false,
	},
}

type Seam = { part: BasePart, color: Color3, at: number }
type Shard = {
	part: BasePart,
	rest: CFrame,
	joint: CFrame,
	offset: Vector3,
	phase: number,
	tilt: number,
}
export type Effect = { step: (number) -> (), destroy: () -> () }

function WeaponShowcase.light(view: ViewportFrame, line: string?)
	local look = line and LOOKS[line]
	view.Ambient = if look then look.ambient else Color3.fromRGB(183, 188, 203)
	view.LightColor = if look then look.key else Color3.fromRGB(255, 246, 228)
	view.LightDirection = Vector3.new(-0.44, -0.67, -0.61)
end

local function piece(parent: Instance, ribbons: boolean): BasePart
	local part: BasePart = if ribbons then Instance.new("Part") else Instance.new("WedgePart")
	part.Name = if ribbons then "WaterRibbon" else "RuinShard"
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

function WeaponShowcase.mount(model: Model, line: string?): Effect?
	local look = line and LOOKS[line]
	if not look then
		return nil
	end

	local box, size = model:GetBoundingBox()
	local origin = model:GetPivot()
	local centre = origin:ToObjectSpace(box)
	local folder = Instance.new("Folder")
	folder.Name = "WeaponPresentation"
	folder.Parent = model

	local seams: { Seam } = {}
	local shards: { Shard } = {}
	local joints: { [string]: Motor6D } = {}
	local parts = model:GetDescendants()
	if not look.ribbons then
		for _, instance in parts do
			if
				instance:IsA("Motor6D")
				and typeof(StateValues.get(instance, "RuinIdleAxis")) == "Vector3"
			then
				joints[instance.Name] = instance
			end
		end
	end
	for _, part in parts do
		if not part:IsA("BasePart") then
			continue
		end
		local group = string.match(part.Name, "^SK_(Ruin[%w]+_%d+)_")
		local motor = group and joints[group]
		if motor and part.Anchored and part.Transparency < 0.9 then
			local axis = StateValues.get(motor, "RuinIdleAxis")
			local phase = StateValues.get(motor, "RuinIdlePhase")
			local travel = StateValues.get(motor, "RuinIdleTravel")
			local tilt = StateValues.get(motor, "RuinIdleTilt")
			if typeof(axis) == "Vector3" and typeof(phase) == "number" then
				local pivot = if motor.Part1
					then motor.Part1.CFrame * motor.C1
					else origin + (part.Position - origin.Position)
				table.insert(shards, {
					part = part,
					rest = origin:ToObjectSpace(part.CFrame),
					joint = origin:ToObjectSpace(pivot),
					offset = axis * model:GetScale() * (if typeof(travel) == "number"
						then travel
						else Ruin.SHARD_TRAVEL),
					phase = phase,
					tilt = if typeof(tilt) == "number" then tilt else Ruin.SHARD_TILT,
				})
			end
		end
		if part.Material == Enum.Material.Neon and part.Transparency < 0.9 then
			local z = box:PointToObjectSpace(part.Position).Z / math.max(size.Z, 0.1)
			table.insert(seams, { part = part, color = part.Color, at = math.clamp(0.5 - z, 0, 1) })
		end
	end

	local pieces: { BasePart } = {}
	for _ = 1, if look.ribbons then 6 else 4 do
		table.insert(pieces, piece(folder, look.ribbons))
	end
	local unit = math.clamp(size.Z / 4.5, 0.48, 1.35)
	local side = size.X * 0.5 + 0.085 * unit
	local phase = (box.X * 0.07 + #model.Name * 0.19) % 1

	local function step(now: number)
		local reduced = UiMotion.reduced()
		local cycle = (now / (if look.ribbons then 3.2 else 4.1) + phase) % 1
		local pivot = model:GetPivot()
		local frame = pivot * centre
		for _, shard in shards do
			local beat = now * math.pi * 2 / Ruin.PERIOD + shard.phase
			local lift = if reduced then 0 else (0.16 + 0.84 * (math.sin(beat) + 1) / 2) * 1.35
			local tilt = if reduced then 0 else shard.tilt * math.sin(beat)
			shard.part.CFrame = pivot
				* shard.joint
				* CFrame.new(shard.offset * lift)
				* CFrame.Angles(tilt, 0, tilt * 0.55)
				* shard.joint:Inverse()
				* shard.rest
		end
		for _, seam in seams do
			local wave = math.exp(-((cycle - seam.at) / 0.22) ^ 2)
			local color = seam.color:Lerp(look.peak, if reduced then 0.25 else 0.18 + wave * 0.48)
			if seam.part.Parent then
				seam.part.Color = color
			end
		end

		for i, part in pieces do
			if reduced then
				part.Transparency = 1
			elseif look.ribbons then
				local sign = if i <= 3 then 1 else -1
				local segment = (i - 1) % 3
				local travel = (cycle + (if sign == 1 then 0 else 0.46)) % 1
				local angle = travel * math.pi * 2
				local z = size.Z * (0.26 - travel * 0.57)
				local function point(at: number): Vector3
					return Vector3.new(
						sign * (side + (0.07 + 0.07 * math.cos(angle + at * 0.78)) * unit),
						size.Y * (0.02 + 0.17 * math.sin(angle + at * 0.78)),
						z - at * 0.14 * unit
					)
				end
				local from, to = point(segment), point(segment + 1)
				part.Size = Vector3.new(0.035 * unit, 0.059 * unit, (to - from).Magnitude + 0.016)
				part.CFrame = frame * CFrame.lookAt((from + to) / 2, to)
				part.Color = look.tint:Lerp(look.peak, segment * 0.23)
				part.Transparency = 1 - math.sin(travel * math.pi) ^ 2 * (0.84 - segment * 0.12)
			else
				local travel = (cycle + i * 0.29) % 1
				local sign = if i % 2 == 0 then 1 else -1
				local angle = (travel + i * 0.24) * math.pi * 2
				local z = size.Z * ((i - 2.5) * 0.145 + travel * 0.13)
				local flare = 0.7 + math.sin(travel * math.pi) * 0.45
				part.Size = Vector3.new(0.036, 0.070, 0.15) * unit * flare
				part.CFrame = frame
					* CFrame.new(
						sign * (side + 0.16 * unit),
						size.Y * 0.22 + 0.25 * unit * travel,
						z
					)
					* CFrame.Angles(angle, angle * 0.7, angle * 0.34)
				part.Color = look.tint:Lerp(look.peak, i * 0.15)
				part.Transparency = 1 - math.sin(travel * math.pi) ^ 2 * 0.76
			end
		end
	end

	return {
		step = step,
		destroy = function()
			local pivot = model:GetPivot()
			for _, shard in shards do
				if shard.part.Parent then
					shard.part.CFrame = pivot * shard.rest
				end
			end
			folder:Destroy()
			for _, seam in seams do
				if seam.part.Parent then
					seam.part.Color = seam.color
				end
			end
		end,
	}
end

return WeaponShowcase
