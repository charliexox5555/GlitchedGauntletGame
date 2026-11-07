--!strict
-- The third-person gun (what other players see), for WeaponService: clones
-- the gun from the Studio-owned ReplicatedStorage.Weapons into the
-- character's hand(s), and hides it while a Mod is in the hand. A plain
-- module: no init/start (WeaponService calls it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared.Config.Animations)
local Weapons = require(Shared.Config.Weapons)

local WorldModel = {}

local GRIP_C0 = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)

local WeaponsFolder: Instance? = nil

-- The installed model for weapon `id`, if there is one.
function WorldModel.template(id: string): Model?
	if not WeaponsFolder then
		WeaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	end
	local folder = WeaponsFolder
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function holdModel(
	character: Model,
	templateId: string,
	handName: string,
	name: string,
	gripC0: CFrame?
): Model?
	local template = WorldModel.template(templateId)
	local hand = character:FindFirstChild(handName)
		or character:FindFirstChild(if handName == "RightHand" then "Right Arm" else "Left Arm")
	if not template or not hand or not hand:IsA("BasePart") then
		return nil
	end
	local model = template:Clone()
	model.Name = name
	local handle = model.PrimaryPart
	if not handle then
		model:Destroy()
		return nil
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
	local grip = Instance.new("Motor6D")
	grip.Name = "WeaponGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	local c0 = gripC0 or GRIP_C0
	grip.C0 = c0
	grip.Parent = handle
	handle.CFrame = hand.CFrame * c0
	model.Parent = character
	return model
end

-- Puts weapon `id` in the character's hand(s) (or removes it with nil).
-- Akimbo guns hold a second model in the left hand ("WorldWeaponLeft").
function WorldModel.attach(character: Model, id: string?): Model?
	for _, name in { "WorldWeapon", "WorldWeaponLeft" } do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not id then
		return nil
	end
	local config = Weapons.get(id)
	local rightId = if config and config.models then config.models.right else id
	-- Melee: the blade sticks forward out of the fist (Config/Animations
	-- KNIFE_WORLD_GRIP), not along the forearm like a gun's grip.
	local gripC0 = if config and config.fireMode == "Melee"
		then Animations.KNIFE_WORLD_GRIP
		else nil
	local model = holdModel(character, rightId, "RightHand", "WorldWeapon", gripC0)
	if model then
		model:SetAttribute("WeaponId", id)
	end
	if config and config.models and config.models.left then
		holdModel(character, config.models.left, "LeftHand", "WorldWeaponLeft")
	end
	-- Cosmetic state lives on the Player (not the predicted character) so it
	-- never triggers Server Authority rollbacks. Dummies keep it on the model.
	local owner = Players:GetPlayerFromCharacter(character)
	if owner then
		owner:SetAttribute("WeaponId", id)
	else
		character:SetAttribute("WeaponId", id)
	end
	return model
end

-- Hides the third-person gun while a Mod is in the hand (ModService), and
-- keeps it hidden across a re-equip until shown again.
local hidden: { [Player]: boolean } = {}

local function applyHidden(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hide = hidden[player] == true
	for _, name in { "WorldWeapon", "WorldWeaponLeft" } do
		local model = character:FindFirstChild(name)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local base = d:GetAttribute("BaseTransparency")
					if base == nil then
						base = d.Transparency
						d:SetAttribute("BaseTransparency", base)
					end
					d.Transparency = if hide then 1 else base :: number
				end
			end
		end
	end
end

function WorldModel.setHidden(player: Player, hide: boolean)
	hidden[player] = if hide then true else nil
	applyHidden(player)
end

-- After a new gun model went into the hand: hide it too if it should be.
function WorldModel.reapplyHidden(player: Player)
	if hidden[player] then
		applyHidden(player)
	end
end

function WorldModel.forget(player: Player)
	hidden[player] = nil
end

return WorldModel
