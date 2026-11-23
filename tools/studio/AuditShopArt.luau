--!strict
-- Studio Edit command. Returns the same client-safe art inventory it prints to Output.

local RS = game:GetService("ReplicatedStorage")
local Weapons = require(RS.Shared.Config.Weapons)
local SkinConfig = require(RS.Shared.Config.SkinPreview)
local SkinArt = require(RS.Shared.SkinArt)
local ItemPortraits = require(RS.Shared.ItemPortraits)
local ItemIcons = require(RS.Shared.ItemIcons)
local Locker = require(RS.Shared.Locker)
local ShopCatalog = require(RS.Lobby.ShopCatalog)

local findings: { string } = {}
local checked: { [string]: boolean } = {}
local lines: { [string]: { string } } = {}
local pairsChecked = 0
local function present(id: string?): boolean
	return id ~= nil and id ~= ""
end

local function check(gun: string, line: string)
	local key = `{gun}/{line}`
	if checked[key] then
		return
	end
	checked[key] = true
	pairsChecked += 1
	local guns = lines[line] or {}
	table.insert(guns, gun)
	lines[line] = guns

	if line ~= "Stock" and not present(ItemPortraits.get(gun, line)) then
		table.insert(findings, "Missing portrait: " .. key)
	end
	local sideGun = if gun == "Knife" and line == "PopCircuit" then "Bat" else gun
	if not present(ItemIcons.get(sideGun, line)) then
		table.insert(findings, "Missing side icon: " .. key)
	end
end

for gun in Weapons.list do
	for _, line in Locker.linesFor(gun) do
		check(gun, line)
	end
end

local bundlesChecked = 0
for _, bundle in ShopCatalog.BUNDLES do
	for _, item in bundle.items do
		if item.gun and item.line then
			check(item.gun, item.line)
		elseif item.kind == "Skin" then
			table.insert(findings, `Missing gun or line: {bundle.id}/{item.name}`)
		end
	end
	if not bundle.soon then
		bundlesChecked += 1
		if not present(bundle.banner) then
			table.insert(findings, "Missing banner: " .. bundle.id)
		end
		local art: { [string]: string } = ShopCatalog.ART
		if bundle.slot == "Starter" then
			if not present(art.starterContents) then
				table.insert(findings, "Missing Starter hero: ShopCatalog.ART.starterContents")
			end
		elseif not present(bundle.hero) then
			table.insert(findings, "Missing bundle hero: " .. bundle.id)
		end
	end
end

local linesChecked = 0
for _, line in SkinConfig.LINES do
	linesChecked += 1
	local guns = lines[line]
	if guns and not present(SkinArt.line(line, guns)) then
		table.insert(findings, "Missing line picture (SkinArt.line): " .. line)
	end
	if not present(Locker.EMBLEMS[line]) then
		table.insert(findings, "Missing line emblem (Locker.EMBLEMS): " .. line)
	end
end

table.sort(findings)
table.insert(
	findings,
	1,
	`[AuditShopArt] {pairsChecked} weapon looks, {bundlesChecked} active bundles, {linesChecked} lines, {#findings} findings`
)
local output = table.concat(findings, "\n")
print(output)
return output
