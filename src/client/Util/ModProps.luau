--!strict
-- Models for held Mods (the item in your hand) and thrown ones. Uses the
-- finished model from ReplicatedStorage.Abilities when it's there (Studio-
-- owned, like the guns; art pass in Stage 3), else a placeholder built here:
-- a matte charcoal shell with team-coloured neon, the Mod look in miniature.
-- Built once per Mod and cached; callers clone what they need.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModProps = {}

local SHELL = Color3.fromHex("2A2D33")
local SHELL_DARK = Color3.fromHex("1B1D21")

local cache: { [string]: Model } = {}
local HELD_PLACED_SCALE = 0.45 -- a placed Mod's model held in the hand
-- Placed models drawn bigger than built, so they're easy to find (the
-- Recall anchor is 1.1 studs tall in Blender).
local PLACED_SCALE: { [string]: number } = {
	Recall = 1.3,
}

-- Mods whose light isn't a team colour (the Heal Orb is soft green-teal for
-- everyone).
local OWN_COLOUR: { [string]: Color3 } = {
	HealOrb = Color3.fromHex("5CFFC8"),
}

local function part(
	model: Model,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Name = if neon then "Glow" else "Shell"
	p.Parent = model
	return p
end

-- Placeholders have their pivot at the origin: the grip for held items, the
-- centre for thrown ones. A thrown one held in the hand sits HoldOffset
-- (attribute) from the grip, so the hand doesn't cover it.
local function placeholder(id: string, glow: Color3): Model?
	local model = Instance.new("Model")
	model.Name = id
	if id == "Molly" then
		model:SetAttribute("HoldOffset", Vector3.new(0, 0.32, -0.12))
		part(model, Enum.PartType.Ball, Vector3.one * 0.5, CFrame.identity, SHELL)
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.12, 0.55, 0.55),
			CFrame.Angles(0, 0, math.pi / 2),
			glow,
			true
		)
		part(
			model,
			Enum.PartType.Block,
			Vector3.new(0.14, 0.16, 0.14),
			CFrame.new(0, 0.26, 0),
			SHELL_DARK
		)
	elseif id == "Frost" then
		model:SetAttribute("HoldOffset", Vector3.new(0, 0.34, -0.12))
		part(model, Enum.PartType.Ball, Vector3.one * 0.32, CFrame.identity, glow, true)
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.1, 0.58, 0.58),
			CFrame.Angles(0, 0, math.pi / 2),
			SHELL
		)
		part(model, Enum.PartType.Cylinder, Vector3.new(0.1, 0.58, 0.58), CFrame.identity, SHELL)
	elseif id == "Firewall" then
		-- A deployable puck: a charcoal disc with a team-coloured core.
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.22, 0.62, 0.62),
			CFrame.new(0, 0.3, -0.1) * CFrame.Angles(0, 0, math.pi / 2),
			SHELL
		)
		part(
			model,
			Enum.PartType.Cylinder,
			Vector3.new(0.24, 0.3, 0.3),
			CFrame.new(0, 0.3, -0.1) * CFrame.Angles(0, 0, math.pi / 2),
			glow,
			true
		)
	elseif id == "HealOrb" then
		-- An orb of light hovering above the palm: a neon core in a soft halo.
		model:SetAttribute("HoldOffset", Vector3.new(0, 0.34, -0.12))
		part(model, Enum.PartType.Ball, Vector3.one * 0.16, CFrame.identity, glow, true)
		local halo = part(model, Enum.PartType.Ball, Vector3.one * 0.32, CFrame.identity, glow)
		halo.Material = Enum.Material.ForceField
	else
		model:Destroy()
		return nil
	end
	model.WorldPivot = CFrame.identity
	-- A root for things that ride the model (a thrown canister's sparks and hiss).
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	end
	return model
end

-- Recolours a finished model's energy (parts named *_Energy / Energy = true,
-- and the Decals on them) to `glow`. Parts named *_Yellow / *_Violet keep
-- their own colour (the Stim's electric coil, the Recall anchor's light).
function ModProps.tint(model: Model, glow: Color3)
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and (d:GetAttribute("Energy") == true or d.Material == Enum.Material.Neon)
			and string.sub(d.Name, -7) ~= "_Yellow"
			and string.sub(d.Name, -7) ~= "_Violet"
		then
			d.Color = glow
			for _, decal in d:GetChildren() do
				if decal:IsA("Decal") then
					decal.Color3 = glow
				end
			end
		end
	end
end

-- The finished Studio model (ReplicatedStorage.Abilities) for `id`, if it's
-- there and of one of `kinds` ("handheld", "thrown", "placed", "vfx").
function ModProps.finished(id: string, kinds: { string }): Model?
	local folder = ReplicatedStorage:FindFirstChild("Abilities")
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("Model") and table.find(kinds, m:GetAttribute("Kind") :: any) then
		return m
	end
	return nil
end

-- The model held in the hand or thrown for Mod `id`, neon in `glow` (nil: no
-- model for it). Placed Mods hold a small puck (their finished model is the
-- deployed object). Returns a shared template: clone it before parenting.
function ModProps.get(id: string, glow: Color3): Model?
	local key = id .. glow:ToHex()
	local cached = cache[key]
	if cached then
		return cached
	end
	local own = OWN_COLOUR[id]
	local finished = ModProps.finished(id, { "handheld", "thrown" })
	local model: Model? = nil
	if finished then
		model = finished:Clone()
		if not own then
			ModProps.tint(model :: Model, glow)
		end
	else
		model = placeholder(id, own or glow)
		-- A placed Mod held in the hand: its finished model, small, above
		-- the palm (the Recall anchor).
		local placed = if model then nil else ModProps.finished(id, { "placed" })
		if placed then
			local small = placed:Clone()
			ModProps.tint(small, glow)
			small:ScaleTo(HELD_PLACED_SCALE)
			small:SetAttribute("HoldOffset", Vector3.new(0, 0.12, -0.15))
			model = small
		end
	end
	if model and id == "HealOrb" then
		-- The swirl on the orb's ForceField shell (it animates on its own).
		local shell = model:FindFirstChild("Shell", true)
		if shell and shell:IsA("MeshPart") then
			shell.TextureID = VFX.HEALORB_SWIRL
		end
	end
	if model then
		cache[key] = model
	end
	return model
end

-- A client-side copy of the finished model standing on a placed server part
-- (Launch Pad, Firewall): pivot at the part's floor centre, facing its
-- LookVector. nil when there's no finished model (the part stays as it is).
function ModProps.dress(object: BasePart, glow: Color3): Model?
	local kind = object:GetAttribute("Kind")
	local finished = if typeof(kind) == "string" then ModProps.finished(kind, { "placed" }) else nil
	if not finished then
		return nil
	end
	local model = finished:Clone()
	ModProps.tint(model, glow)
	local scale = PLACED_SCALE[kind :: string]
	if scale then
		model:ScaleTo(scale)
	end
	model:PivotTo(object.CFrame * CFrame.new(0, -object.Size.Y / 2, 0))
	return model
end

return ModProps
