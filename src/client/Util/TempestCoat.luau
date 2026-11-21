--!strict
-- Tempest-Strike "water coat" (first person): a glowing water skin over the gun.
-- Each visible mesh gets a slightly inflated ForceField copy welded to it (built
-- before ViewmodelRig, so the rig carries the copies at their rest offsets). The
-- copies sit in three groups (body, sight, mag) whose opacity TempestIdle drives:
-- the draw starts with the gun made of water and solidifies, the new magazine is
-- water before it turns solid, the old one leaves as a water ghost, the inspect
-- roll and the sight light up. Neon and hairline parts get no copy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Style = require(ReplicatedStorage.Shared.Config.SkinPreview).TEMPEST

export type Group = "body" | "sight" | "mag"
type Shell = { shell: BasePart, src: BasePart, group: Group }
export type Coat = {
	shells: { Shell },
	alpha: { [Group]: number },
	-- a group shown even while its source is hidden (the water magazine)
	free: { [Group]: boolean },
}

local TempestCoat = {}

local function groupOf(part: BasePart): Group
	if string.match(part.Name, "^SK_Mag") then
		return "mag"
	elseif string.find(part.Name, "Sight", 1, true) then
		return "sight"
	end
	return "body"
end

function TempestCoat.new(model: Model, scale: number): Coat
	local coat: Coat = {
		shells = {},
		alpha = { body = 0, sight = 0, mag = 0 },
		free = { body = false, sight = false, mag = false },
	}
	for _, d in model:GetDescendants() do
		if not d:IsA("MeshPart") or d.Transparency >= 1 or d.Material == Enum.Material.Neon then
			continue
		end
		local size = d.Size
		if math.min(size.X, size.Y, size.Z) < Style.COAT_MIN_PART * scale then
			continue
		end
		local shell = d:Clone()
		shell:ClearAllChildren()
		shell.Name = "TempestCoat"
		shell.Material = Enum.Material.ForceField
		shell.Color = Style.COAT_COLOR
		shell.Transparency = 1
		shell.CastShadow = false
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.Massless = true
		shell.Size = size * Style.COAT_SCALE + Vector3.one * (Style.COAT_PAD * scale)
		shell.CFrame = d.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = d
		weld.Part1 = shell
		weld.Parent = shell
		shell.Parent = d.Parent
		table.insert(coat.shells, { shell = shell, src = d, group = groupOf(d) })
	end
	return coat
end

-- Every frame after the group alphas are set: opacity, and the source's local
-- hide (a hidden magazine hides its coat unless the group is `free`).
function TempestCoat.step(coat: Coat, visible: boolean)
	for _, s in coat.shells do
		local a = coat.alpha[s.group]
		local t = if visible and a > 0.01 then 1 - a * Style.COAT_OPACITY else 1
		if s.shell.Transparency ~= t then
			s.shell.Transparency = t
		end
		local hide = if not visible
			then 1
			elseif coat.free[s.group] then 0
			else s.src.LocalTransparencyModifier
		if s.shell.LocalTransparencyModifier ~= hide then
			s.shell.LocalTransparencyModifier = hide
		end
	end
end

return TempestCoat
