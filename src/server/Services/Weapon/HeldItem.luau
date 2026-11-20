--!strict
-- The Mod in a fighter's right hand in third person (ModService for players,
-- BotService for bots): a handheld or thrown Mod's model from
-- ReplicatedStorage.Abilities, welded to the hand while it's held, named
-- "ModHeldItem" (clients hide their own copy in first person). Whoever calls
-- it also hides the gun (WorldModel) while it returns true. A plain module:
-- no init/start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local HeldItem = {}

HeldItem.NAME = "ModHeldItem"
-- The item sits in the right hand like a gun (WeaponService's grip).
local GRIP = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)

-- Puts Mod `id`'s item in `character`'s right hand (nil: takes it away).
-- Returns whether an item is now shown (then the gun should hide).
function HeldItem.show(character: Model, id: string?): boolean
	local old = character:FindFirstChild(HeldItem.NAME)
	if old then
		old:Destroy()
	end
	local folder = ReplicatedStorage:FindFirstChild("Abilities")
	local template = id and folder and folder:FindFirstChild(id)
	local kind = template and StateValues.get(template, "Kind")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local show = template ~= nil
		and template:IsA("Model")
		and (kind == "handheld" or kind == "thrown")
	if not show or not hand or not hand:IsA("BasePart") then
		return show
	end
	local model = (template :: Model):Clone()
	model.Name = HeldItem.NAME
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return false
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local offset = StateValues.get(model, "HoldOffset")
	local grip = Instance.new("Weld")
	grip.Part0 = hand
	grip.Part1 = root
	grip.C0 = GRIP * (if typeof(offset) == "Vector3" then CFrame.new(offset) else CFrame.identity)
	grip.Parent = root
	root.CFrame = hand.CFrame * grip.C0
	model.Parent = character
	return true
end

return HeldItem
