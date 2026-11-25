--!strict
-- The Mod in a fighter's right hand in third person (ModService for players,
-- BotService for bots): a held Mod's model from ReplicatedStorage.Abilities
-- (handheld, thrown, scaled placed devices, or a Firewall hand puck), welded
-- to the hand while held and named "ModHeldItem" (clients hide their own copy
-- in first person). Whoever calls it also hides the gun (WorldModel) while
-- it returns true. A plain module: no init/start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local HeldItem = {}

HeldItem.NAME = "ModHeldItem"
-- The item sits in the right hand like a gun (WeaponService's grip).
local GRIP = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)
local PLACED_OFFSET = Vector3.new(0, 0.22, -0.12)
local FIREWALL_OFFSET = Vector3.new(0, 0.28, -0.10)
local PLACED_SCALE: { [string]: number } = {
	Stim = 0.45,
	Recall = 0.48,
	Roller = 0.34,
	LaunchPad = 0.14,
}
local SHELL_COLOR = Color3.fromHex("2A2D33")
local DEFAULT_GLOW = Color3.fromHex("FFC83D")

local function firewallHandPuck(): Model
	local model = Instance.new("Model")
	model.Name = "Firewall"

	local core = Instance.new("Part")
	core.Name = "Core_Energy"
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(0.22, 0.32, 0.32)
	core.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	core.Color = DEFAULT_GLOW
	core.Material = Enum.Material.Neon
	core.CastShadow = false
	core.Parent = model
	StateValues.set(core, "Energy", true)

	local disc = Instance.new("Part")
	disc.Name = "Shell"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.18, 0.56, 0.56)
	disc.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	disc.Color = SHELL_COLOR
	disc.Material = Enum.Material.SmoothPlastic
	disc.CastShadow = false
	disc.Parent = model

	local weld = Instance.new("Weld")
	weld.Part0 = core
	weld.Part1 = disc
	weld.Parent = disc

	local light = Instance.new("PointLight")
	light.Color = DEFAULT_GLOW
	light.Range = 5
	light.Brightness = 1.4
	light.Parent = core

	model.PrimaryPart = core
	model.WorldPivot = CFrame.identity
	return model
end

-- Puts Mod `id`'s item in `character`'s right hand (nil: takes it away).
-- Returns whether an item is now shown (then the gun should hide).
function HeldItem.show(character: Model, id: string?): boolean
	local old = character:FindFirstChild(HeldItem.NAME)
	if old then
		old:Destroy()
	end
	if not id or id == "" then
		return false
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return false
	end

	local folder = ReplicatedStorage:FindFirstChild("Abilities")
	local template = folder and folder:FindFirstChild(id)
	local kind = template and StateValues.get(template, "Kind")
	local model: Model? = nil
	local offset: Vector3? = nil

	if id == "Firewall" then
		model = firewallHandPuck()
		offset = FIREWALL_OFFSET
	elseif template and template:IsA("Model") and (kind == "handheld" or kind == "thrown") then
		model = template:Clone()
		local authored = StateValues.get(template, "HoldOffset")
		if typeof(authored) == "Vector3" then
			offset = authored
		end
	elseif template and template:IsA("Model") and kind == "placed" then
		local scaled = template:Clone()
		scaled:ScaleTo(PLACED_SCALE[id] or 0.45)
		model = scaled
		offset = PLACED_OFFSET
	end

	if not model then
		return false
	end
	model.Name = HeldItem.NAME
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		model:Destroy()
		return false
	end
	model.PrimaryPart = root
	StateValues.set(model, "ModId", id)

	local gripC0 = GRIP * (if offset then CFrame.new(offset) else CFrame.identity)
	-- Move the assembled model into hand pose BEFORE unanchoring parts.
	model:PivotTo(hand.CFrame * gripC0)

	local grip = Instance.new("Motor6D")
	grip.Name = "ModGrip"
	grip.Part0 = hand
	grip.Part1 = root
	grip.C0 = gripC0
	grip.Parent = root

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	model.Parent = character
	return true
end

return HeldItem
