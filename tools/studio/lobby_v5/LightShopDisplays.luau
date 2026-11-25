--!nocheck
-- Draft Duels / Edit mode. Run after BuildShopDisplays. Rebuilds only the display lighting and haze.

local CollectionService = game:GetService("CollectionService")
local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local shop = workspace.LobbyV5.Shell.Shop
assert(game.PlaceId == 71551303511506, "Select the Draft Duels place")

local V = Vector3.new
local iv = Color3.fromHex
local warm = iv("FFF1DC")
local gold = iv("FFC46B")
local lensLook = K.paint(iv("27262A"))

local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function resetRig(parent)
	local previous = parent:FindFirstChild("DisplayLighting")
	if previous then
		previous:Destroy()
	end
	return K.model(parent, "DisplayLighting")
end

local function emitter(rig, name, origin, target)
	local mount =
		K.ghost(K.part(rig, name, V(0.1, 0.1, 0.1), CFrame.lookAt(origin, target), lensLook))
	mount.Transparency = 1
	return mount
end

local function haze(rig, source, target, color)
	local shaft = emitter(rig, "SpotHaze", source, target)
	local start = make("Attachment", shaft, { Name = "Lens" })
	local finish = make(
		"Attachment",
		shaft,
		{ Name = "Falloff", Position = V(0, 0, -(target - source).Magnitude) }
	)
	make("Beam", shaft, {
		Name = "SoftShaft",
		Attachment0 = start,
		Attachment1 = finish,
		Color = ColorSequence.new(color),
		FaceCamera = true,
		Width0 = 0.33,
		Width1 = 2.65,
		LightEmission = 0.62,
		LightInfluence = 0,
		Segments = 12,
		ZOffset = 0.02,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0.94),
			NumberSequenceKeypoint.new(0.44, 0.966),
			NumberSequenceKeypoint.new(0.78, 0.989),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local volume = K.ghost(
		K.part(rig, "DustVolume", V(1.6, 2.6, 1.2), CFrame.new(source:Lerp(target, 0.3)), lensLook)
	)
	volume.Transparency = 1
	make("ParticleEmitter", volume, {
		Name = "LitDust",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color),
		Rate = 2.4,
		Lifetime = NumberRange.new(1.5, 2.7),
		Speed = NumberRange.new(0.10, 0.34),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Bottom,
		LightEmission = 0.32,
		LightInfluence = 0.3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.035),
			NumberSequenceKeypoint.new(1, 0.065),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.22, 0.55),
			NumberSequenceKeypoint.new(0.62, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

local looks = {
	Bay_FEATURED = {
		key = iv("E9F3FF"),
		edge = iv("A9D6FF"),
		height = 2.95,
		display = "Display_FEATURED",
		line = "TempestStrike",
	},
	Bay_NEWIN = {
		key = warm,
		edge = iv("A8E4D4"),
		height = 3.1,
		display = "Display_NEWIN",
		line = "RuinBlighted",
	},
	Bay_CASES = { key = warm, edge = iv("FFE2B6"), height = 3.0 },
	Bay_SEASON = { key = warm, edge = iv("FFF1DD"), screen = true, height = 2.3 },
}

for name, look in looks do
	local bay = shop.Bays[name]
	local rig = resetRig(bay)
	local head = bay.Head
	local frame = head.CFrame - V(0, head.Position.Y, 0)
	frame *= CFrame.new(0, 0, -0.3)
	local ceiling = bay.Ceiling:FindFirstChildOfClass("SurfaceLight")
	ceiling.Enabled = true
	ceiling.Brightness = if look.screen then 1.27 else 0.95
	ceiling.Range = 14
	ceiling.Shadows = false

	for _, can in bay.Truss:GetChildren() do
		if can.Name ~= "Can" then
			continue
		end
		local lens = can.Lens
		local source = can.Light
		local spot = source:FindFirstChildOfClass("SpotLight")
		local x = frame:PointToObjectSpace(source.Position).X
		local center = math.abs(x) < 1
		local target = frame * V(x, look.height, -5.0)
		spot.Enabled = true
		spot.Color = look.key
		spot.Brightness = if center then 2.65 else 1.85
		spot.Range = 14.5
		spot.Angle = if center then 42 else 54
		spot.Shadows = center and not look.screen
		lens.Material = Enum.Material.Neon
		lens.Color = look.key
		local aim = CFrame.lookAt(source.Position, target)
		local old = source.CFrame
		for _, part in { can.Body, lens } do
			part.CFrame = aim * old:ToObjectSpace(part.CFrame)
		end
		source.CFrame = aim
		if center and look.display then
			haze(rig, source.Position + source.CFrame.LookVector * 0.12, target, look.key)
		end
	end

	if look.display then
		-- Light each receiver or blade from the aisle side so the model reads at player height.
		local merchandise = shop.Fit[look.display].Merchandise
		for _, stand in merchandise:GetChildren() do
			local weapon = stand:FindFirstChildWhichIsA("Model")
			if not weapon then
				continue
			end
			local box = weapon:GetBoundingBox()
			local center = frame:PointToObjectSpace(box.Position)
			local front = frame * (center + V(-0.9, 0.80, 2.0))
			local key = emitter(rig, weapon.Name .. "Key", front, box.Position)
			K.spot(rig, key, Enum.NormalId.Front, look.key, 5.0, 6.8, 92)
			local side = frame * (center + V(1.4, 0.45, -0.95))
			local rim = emitter(rig, weapon.Name .. "Edge", side, box.Position)
			K.spot(rig, rim, Enum.NormalId.Front, look.edge, 3.15, 5.8, 91)

			weapon.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			weapon:SetAttribute("ShowcaseLine", look.line)
			CollectionService:AddTag(weapon, "LobbyWeaponShowcase")
		end
	elseif not look.screen then
		-- Small bounced fill at the front of the deck and a tighter edge light behind each side.
		local fill = emitter(rig, "FrontBounce", frame * V(0, 2.25, -2.2), frame * V(0, 3.1, -5.4))
		K.spot(rig, fill, Enum.NormalId.Front, look.key, 2.15, 10, 118)
		for _, x in { -4.1, 4.1 } do
			local rim =
				emitter(rig, "RimLight", frame * V(x, 3.3, -7.9), frame * V(x * 0.78, 2.95, -4.9))
			K.spot(rig, rim, Enum.NormalId.Front, look.edge, 1.05, 7.8, 72)
		end
	end

	local step = bay.StepLight
	local stepSource = K.ghost(K.part(rig, "StepEmitter", step.Size, step.CFrame, lensLook))
	stepSource.Transparency = 1
	make("SurfaceLight", stepSource, {
		Name = "StepSpill",
		Face = Enum.NormalId.Back,
		Color = gold,
		Brightness = 0.36,
		Range = 3.5,
		Angle = 104,
		Shadows = false,
	})
end

local feature = shop.Fit.Feature
local rig = resetRig(feature)
local screen = feature.Screen
for _, light in feature.Hood:GetDescendants() do
	if light:IsA("SpotLight") then
		light.Color = warm
		light.Brightness = 1.85
		light.Range = 13
		light.Angle = 76
		light.Shadows = false
	end
end
for _, x in { -7.25, 7.25 } do
	local origin = screen.CFrame * V(x, -3.72, 0.50)
	local target = screen.CFrame * V(x * 1.18, -5.6, -0.8)
	local bounce = emitter(rig, "ScreenWallWash", origin, target)
	K.spot(rig, bounce, Enum.NormalId.Front, warm, 1.05, 7.0, 90)
end

return "Installed individual key and edge lights on six display skins and enabled their showcase effects."
