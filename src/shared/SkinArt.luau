--!strict
-- The picture for one skin: the square diagonal portrait (Shared/ItemPortraits, for
-- tiles: CONTENTS, the info popup, the case reveal), else the side-on picture
-- (Shared/ItemIcons, the Locker's wide cards), else nil. Pictures, never live 3D
-- (owner: RIVALS uses images). The PopCircuit knife is the Bat in ItemIcons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)

local SkinArt = {}

local portraits: any = nil
do
	local m = ReplicatedStorage.Shared:FindFirstChild("ItemPortraits")
	if m and m:IsA("ModuleScript") then
		portraits = require(m) :: any
	end
end

function SkinArt.side(gunId: string, line: string): string?
	local gun = if gunId == "Knife" and line == "PopCircuit" then "Bat" else gunId
	return ItemIcons.get(gun, line)
end

function SkinArt.portrait(gunId: string, line: string): string?
	local p = if portraits then portraits.get(gunId, line) else nil
	return p or SkinArt.side(gunId, line)
end

-- the picture that stands for a whole line: its Vandal or Phantom, else any gun's
function SkinArt.line(line: string, guns: { string }): string?
	local hero = SkinArt.portrait("Vandal", line) or SkinArt.portrait("Phantom", line)
	if hero then
		return hero
	end
	for _, g in guns do
		local p = SkinArt.portrait(g, line)
		if p then
			return p
		end
	end
	return nil
end

return SkinArt
