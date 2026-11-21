--!strict
-- A crate for a tier: a copy of its template in ReplicatedStorage.Crates (the big Crate, or
-- the tier's own model, e.g. the KnifeCase) painted with Config/Crates.
-- Used by the Backpack's stage, the Shop and (later) the opening sequence.
--
--   local crate = CrateLook.make(2)        -- an Elite crate (nil if the template is missing)
--   CrateLook.paint(model, 3)              -- repaint an existing copy
--   CrateLook.joint(model, "Lid")          -- its Motor6D (Base, Lid, Gem, LatchL, LatchR, Handle)
--   joint.Transform = CFrame.Angles(math.rad(105), 0, 0)  -- opens the lid (positive X = open)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crates = require(ReplicatedStorage.Shared.Config.Crates)

local CrateLook = {}

function CrateLook.template(tier: number?): Model?
	local def = if tier then Crates.TIERS[tier] else nil
	local folder = ReplicatedStorage:FindFirstChild(Crates.FOLDER)
	local t = folder and folder:FindFirstChild(def and def.template or Crates.TEMPLATE)
	if not (t and t:IsA("Model")) and def and def.template and folder then
		t = folder:FindFirstChild(Crates.TEMPLATE) -- its own model isn't there: the big crate
	end
	return if t and t:IsA("Model") then t else nil
end

-- the in-world opening's scale for a tier's model, or nil for the default
function CrateLook.scale(tier: number): number?
	local def = Crates.TIERS[tier]
	return def and def.scale
end

function CrateLook.paint(model: Model, tier: number)
	local def = Crates.TIERS[tier] or Crates.TIERS[1]
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			local role = string.match(d.Name, "_(%a+)$")
			local look = role and (def.roles :: any)[role]
			if look then
				d.Color = look.color
				d.Material = look.material
			end
		end
	end
	model:SetAttribute("Tier", tier)
end

function CrateLook.make(tier: number): Model?
	local t = CrateLook.template(tier)
	if not t then
		return nil
	end
	local m = t:Clone()
	CrateLook.paint(m, tier)
	return m
end

function CrateLook.joint(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

return CrateLook
