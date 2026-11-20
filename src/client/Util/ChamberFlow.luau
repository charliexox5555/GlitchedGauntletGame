--!strict
-- Moltframe chamber motion for camera (viewmodel) guns.
-- The chamber MeshParts carry a static baked map (the fallback everyone sees)
-- plus two flow Textures tagged with CHAMBER_FLOW.TAG_ATTRIBUTE. On the local
-- viewmodel only, the layers drift in opposite directions and the chamber's
-- SurfaceAppearance tint breathes over PULSE_PERIOD. The metal and the chamber
-- edges are separate geometry, so they never move. World models (other
-- players, pickups) are not touched and keep the static look.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Config = require(ReplicatedStorage.Shared.Config.SkinPreview)

local FLOW = Config.CHAMBER_FLOW

type Pulse = { base: Color3 }

local ChamberFlow = {}

function ChamberFlow.start(): () -> ()
	local layers: { [Texture]: number } = {}
	local pulses: { [SurfaceAppearance]: Pulse } = {}
	local cameraConnections: { RBXScriptConnection } = {}
	local clock = 0

	local function track(instance: Instance)
		if instance:IsA("Texture") then
			local layer = StateValues.get(instance, FLOW.TAG_ATTRIBUTE)
			if typeof(layer) == "number" and FLOW.LAYERS[layer] then
				layers[instance] = layer
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
			layers[instance] = nil
		elseif instance:IsA("SurfaceAppearance") then
			local pulse = pulses[instance]
			if pulse then
				pulses[instance] = nil
				instance.Color = pulse.base
			end
		end
	end

	local function bindCamera()
		for _, connection in cameraConnections do
			connection:Disconnect()
		end
		table.clear(cameraConnections)
		table.clear(layers)
		table.clear(pulses)
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
			return
		end
		dt = math.min(dt, FLOW.MAX_STEP)
		clock = (clock + dt) % FLOW.PULSE_PERIOD
		for texture, layer in layers do
			local spec = FLOW.LAYERS[layer]
			local tileU = math.max(texture.StudsPerTileU, 1e-3)
			local tileV = math.max(texture.StudsPerTileV, 1e-3)
			texture.OffsetStudsU = (texture.OffsetStudsU + spec.speedU * dt) % tileU
			texture.OffsetStudsV = (texture.OffsetStudsV + spec.speedV * dt) % tileV
		end
		local wave = 0.5 - 0.5 * math.cos(clock / FLOW.PULSE_PERIOD * 2 * math.pi)
		for appearance, pulse in pulses do
			appearance.Color = pulse.base:Lerp(FLOW.PULSE_TINT, wave * 0.5)
		end
	end)

	return function()
		step:Disconnect()
		cameraChanged:Disconnect()
		for _, connection in cameraConnections do
			connection:Disconnect()
		end
		for appearance, pulse in pulses do
			appearance.Color = pulse.base
		end
		table.clear(layers)
		table.clear(pulses)
	end
end

return ChamberFlow
