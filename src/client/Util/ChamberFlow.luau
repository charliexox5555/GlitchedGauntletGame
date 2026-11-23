--!strict
-- Moltframe Epic chamber motion & subtle reactive VFX for camera (viewmodel) guns.
-- Each chamber MeshPart carries flow Textures tagged with CHAMBER_FLOW.TAG_ATTRIBUTE.
-- On the local player's first-person viewmodel only:
--   - flow textures drift continuously and accelerate briefly on shot/reload/draw/inspect;
--   - chamber parts breathe over PULSE_PERIOD and flare violet on reactive surges;
--   - one subtle PointLight + sparse ambient lilac mote emitter sit on the primary chamber.
-- World models (other players, pickups) are never touched and keep the static look.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local Config = require(ReplicatedStorage.Shared.Config.SkinPreview)

local FLOW = Config.CHAMBER_FLOW

export type PulseKind = "Fire" | "Seat" | "Draw" | "Inspect"

type SurfacePulse = { base: Color3 }
type PartGlow = { base: Color3, count: number }
type ModelFx = {
	host: BasePart,
	light: PointLight,
	motes: ParticleEmitter,
	parts: { [BasePart]: boolean },
}

local ChamberFlow = {}

local surgeLevel = 0
local activeModelFx: { [Model]: ModelFx } = {}

local function modelOf(instance: Instance): Model?
	local cur = instance.Parent
	while cur do
		if cur:IsA("Model") and StateValues.get(cur, "SkinLine") == "Moltframe" then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function createModelFx(host: BasePart): ModelFx
	local light = Instance.new("PointLight")
	light.Name = "MoltframeChamberLight"
	light.Color = FLOW.LIGHT_COLOR
	light.Brightness = FLOW.LIGHT_IDLE
	light.Range = FLOW.LIGHT_RANGE
	light.Shadows = false
	light.Parent = host

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "MoltframeChamberMote"
	motes.Texture = FLOW.MOTE_TEXTURE
	motes.Color = ColorSequence.new(FLOW.MOTE_COLOR, FLOW.SURGE_COLOR)
	motes.LightEmission = 0.85
	motes.LightInfluence = 0
	motes.Brightness = 1.4
	motes.LockedToPart = true
	motes.Lifetime = NumberRange.new(0.45, 0.85)
	motes.Speed = NumberRange.new(0.08, 0.22)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Drag = 2.5
	motes.Rate = FLOW.MOTE_RATE
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, FLOW.MOTE_SIZE),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Parent = host

	return {
		host = host,
		light = light,
		motes = motes,
		parts = {},
	}
end

local function destroyModelFx(fx: ModelFx)
	if fx.light.Parent then
		pcall(function()
			fx.light:Destroy()
		end)
	end
	if fx.motes.Parent then
		pcall(function()
			fx.motes:Destroy()
		end)
	end
end

function ChamberFlow.pulse(kind: PulseKind)
	local boost = if kind == "Seat"
		then FLOW.SEAT_SURGE
		elseif kind == "Fire" then FLOW.SHOT_SURGE
		elseif kind == "Draw" then FLOW.DRAW_SURGE
		else FLOW.INSPECT_SURGE
	surgeLevel = math.clamp(math.max(surgeLevel, boost), 0, 1)
	local burst = if kind == "Seat" or kind == "Inspect"
		then FLOW.MOTE_BURST_SEAT
		elseif kind == "Fire" then FLOW.MOTE_BURST_FIRE
		else 0
	if burst > 0 then
		local count = SettingsApply.vfxCount(burst)
		if count > 0 then
			for _, fx in activeModelFx do
				if fx.motes.Parent then
					fx.motes:Emit(count)
				end
			end
		end
	end
end

function ChamberFlow.start(): () -> ()
	local layers: { [Texture]: number } = {}
	local textureBase: { [Texture]: Color3 } = {}
	local pulses: { [SurfaceAppearance]: SurfacePulse } = {}
	local chamberParts: { [BasePart]: PartGlow } = {}
	local cameraConnections: { RBXScriptConnection } = {}
	local clock = 0

	local function ensureModelFx(part: BasePart)
		local model = modelOf(part)
		if not model then
			return
		end
		local fx = activeModelFx[model]
		if not fx then
			fx = createModelFx(part)
			activeModelFx[model] = fx
		elseif part.Size.Magnitude > fx.host.Size.Magnitude then
			-- Prefer the largest chamber MeshPart (receiver/barrel) as the light host.
			fx.host = part
			fx.light.Parent = part
			fx.motes.Parent = part
		end
		fx.parts[part] = true
	end

	local function releaseModelFx(part: BasePart)
		for model, fx in activeModelFx do
			if fx.parts[part] then
				fx.parts[part] = nil
				if next(fx.parts) == nil or not model.Parent then
					activeModelFx[model] = nil
					destroyModelFx(fx)
				elseif fx.host == part then
					local replacement = next(fx.parts)
					if replacement and replacement.Parent then
						-- If the old host was destroyed, its child light/motes have locked NULL parents.
						if fx.light.Parent and fx.motes.Parent then
							fx.host = replacement
							pcall(function()
								fx.light.Parent = replacement
								fx.motes.Parent = replacement
							end)
						else
							activeModelFx[model] = createModelFx(replacement)
							activeModelFx[model].parts = fx.parts
						end
					else
						activeModelFx[model] = nil
						destroyModelFx(fx)
					end
				end
			end
		end
	end

	local function track(instance: Instance)
		if instance:IsA("Texture") then
			local layer = StateValues.get(instance, FLOW.TAG_ATTRIBUTE)
			if typeof(layer) == "number" and FLOW.LAYERS[layer] then
				layers[instance] = layer
				textureBase[instance] = instance.Color3
				local parent = instance.Parent
				if parent and parent:IsA("BasePart") then
					local entry = chamberParts[parent]
					if entry then
						entry.count += 1
					else
						chamberParts[parent] = { base = parent.Color, count = 1 }
						ensureModelFx(parent)
					end
				end
			end
		elseif
			instance:IsA("SurfaceAppearance")
			and StateValues.get(instance, FLOW.PULSE_ATTRIBUTE) == true
		then
			pulses[instance] = { base = instance.Color }
		end
	end

	local function untrack(instance: Instance)
		if instance:IsA("Texture") then
			if layers[instance] ~= nil then
				layers[instance] = nil
				local base = textureBase[instance]
				if base then
					textureBase[instance] = nil
					instance.Color3 = base
				end
				local parent = instance.Parent
				if parent and parent:IsA("BasePart") then
					local entry = chamberParts[parent]
					if entry then
						entry.count -= 1
						if entry.count <= 0 then
							chamberParts[parent] = nil
							parent.Color = entry.base
							releaseModelFx(parent)
						end
					end
				end
			end
		elseif instance:IsA("BasePart") then
			local entry = chamberParts[instance]
			if entry then
				chamberParts[instance] = nil
				instance.Color = entry.base
				releaseModelFx(instance)
			end
		elseif instance:IsA("SurfaceAppearance") then
			local pulse = pulses[instance]
			if pulse then
				pulses[instance] = nil
				instance.Color = pulse.base
			end
		end
	end

	local function clearTracked()
		for texture, base in textureBase do
			if texture.Parent then
				texture.Color3 = base
			end
		end
		for part, entry in chamberParts do
			if part.Parent then
				part.Color = entry.base
			end
		end
		for appearance, pulse in pulses do
			if appearance.Parent then
				appearance.Color = pulse.base
			end
		end
		for model, fx in activeModelFx do
			activeModelFx[model] = nil
			destroyModelFx(fx)
		end
		table.clear(layers)
		table.clear(textureBase)
		table.clear(chamberParts)
		table.clear(pulses)
	end

	local function bindCamera()
		for _, connection in cameraConnections do
			connection:Disconnect()
		end
		table.clear(cameraConnections)
		clearTracked()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		for _, d in camera:GetDescendants() do
			track(d)
		end
		table.insert(cameraConnections, camera.DescendantAdded:Connect(track))
		table.insert(cameraConnections, camera.DescendantRemoving:Connect(untrack))
	end

	bindCamera()
	local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

	local step = RunService.RenderStepped:Connect(function(dt: number)
		if next(layers) == nil and next(pulses) == nil then
			surgeLevel = 0
			return
		end
		dt = math.min(dt, FLOW.MAX_STEP)
		clock = (clock + dt) % FLOW.PULSE_PERIOD
		if surgeLevel > 0 then
			surgeLevel = math.max(0, surgeLevel * math.exp(-FLOW.SURGE_DECAY * dt))
			if surgeLevel < 0.005 then
				surgeLevel = 0
			end
		end
		local speedMult = 1 + surgeLevel * FLOW.SURGE_SPEED_BOOST
		local wave = 0.5 - 0.5 * math.cos(clock / FLOW.PULSE_PERIOD * 2 * math.pi)
		local texTint = FLOW.TEXTURE_IDLE:Lerp(FLOW.TEXTURE_SURGE, surgeLevel)
		for texture, layer in layers do
			local spec = FLOW.LAYERS[layer]
			local tileU = math.max(texture.StudsPerTileU, 1e-3)
			local tileV = math.max(texture.StudsPerTileV, 1e-3)
			texture.OffsetStudsU = (texture.OffsetStudsU + spec.speedU * speedMult * dt) % tileU
			texture.OffsetStudsV = (texture.OffsetStudsV + spec.speedV * speedMult * dt) % tileV
			texture.Color3 = texTint
		end
		for part, entry in chamberParts do
			local breathed = entry.base:Lerp(FLOW.BREATHE_COLOR, wave * FLOW.BREATHE_MIX)
			part.Color = breathed:Lerp(FLOW.SURGE_COLOR, surgeLevel * 0.72)
		end
		for appearance, pulse in pulses do
			local mix = math.clamp(wave * 0.5 + surgeLevel * 0.5, 0, 1)
			appearance.Color = pulse.base:Lerp(FLOW.PULSE_TINT, mix)
		end
		local lightBrightness = FLOW.LIGHT_IDLE
			+ wave * FLOW.LIGHT_PULSE
			+ surgeLevel * FLOW.LIGHT_SURGE
		local moteRate = if SettingsApply.vfxCount(1) > 0 then FLOW.MOTE_RATE else 0
		for _, fx in activeModelFx do
			fx.light.Brightness = lightBrightness
			fx.motes.Rate = moteRate
		end
	end)

	return function()
		step:Disconnect()
		cameraChanged:Disconnect()
		for _, connection in cameraConnections do
			connection:Disconnect()
		end
		clearTracked()
		surgeLevel = 0
	end
end

return ChamberFlow
