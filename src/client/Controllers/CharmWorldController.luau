--!strict
-- Renders and gently animates equipped charms on third-person WorldWeapon /
-- WorldWeaponLeft models for remote fighters (culled beyond RANGE studs,
-- and hidden for the local player when inside first person).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StateValues = require(ReplicatedStorage.Shared.StateValues)
local CharmRig = require(ReplicatedStorage.Shared.CharmRig)

local CharmWorldController = {}

local MAX_RANGE = 64

type Entry = {
	weapon: Model,
	owner: Player?,
	rig: CharmRig.State?,
	charmId: string,
	kills: number,
	connAttr: RBXScriptConnection,
	connKills: RBXScriptConnection?,
}

local entries: { [Model]: Entry } = {}
local localPlayer = Players.LocalPlayer

local function ownerOfWeapon(model: Model): Player?
	local char = model.Parent
	return if char and char:IsA("Model") then Players:GetPlayerFromCharacter(char) else nil
end

local function isFirstPerson(): boolean
	local cam = Workspace.CurrentCamera
	local char = localPlayer and localPlayer.Character
	local head = char and char:FindFirstChild("Head")
	if cam and head and head:IsA("BasePart") then
		return (cam.CFrame.Position - head.Position).Magnitude < 2.2
	end
	return false
end

local function rebuildEntry(entry: Entry)
	if entry.rig then
		CharmRig.destroy(entry.rig)
		entry.rig = nil
	end
	local id = StateValues.get(entry.weapon, "CharmId")
	if typeof(id) ~= "string" or id == "" then
		entry.charmId = ""
		return
	end
	entry.charmId = id
	local weaponId = StateValues.get(entry.weapon, "WeaponId")
	local k = if entry.owner then StateValues.get(entry.owner, "MatchKills") else 0
	entry.kills = if typeof(k) == "number" then k else 0
	entry.rig = CharmRig.attach(entry.weapon, id, 1.0, {
		mode = "world",
		kills = entry.kills,
		castShadow = false,
		gunId = if typeof(weaponId) == "string" then weaponId else nil,
	})
end

local function untrack(weapon: Model)
	local e = entries[weapon]
	if not e then
		return
	end
	entries[weapon] = nil
	e.connAttr:Disconnect()
	if e.connKills then
		e.connKills:Disconnect()
	end
	CharmRig.destroy(e.rig)
end

local function track(inst: Instance)
	if
		not inst:IsA("Model")
		or (inst.Name ~= "WorldWeapon" and inst.Name ~= "WorldWeaponLeft")
		or entries[inst]
	then
		return
	end
	local weapon = inst
	local owner = ownerOfWeapon(weapon)
	local e: Entry = {
		weapon = weapon,
		owner = owner,
		rig = nil,
		charmId = "",
		kills = 0,
		connAttr = StateValues.changed(weapon, "CharmId"):Connect(function()
			local current = entries[weapon]
			if current then
				rebuildEntry(current)
			end
		end),
		connKills = if owner
			then StateValues.changed(owner, "MatchKills"):Connect(function(v)
				local current = entries[weapon]
				if current and current.rig and typeof(v) == "number" then
					if v > current.kills then
						CharmRig.onKill(current.rig, v, false)
					else
						CharmRig.setKills(current.rig, v)
					end
					current.kills = v
				end
			end)
			else nil,
	}
	entries[weapon] = e
	rebuildEntry(e)
end

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local fp = isFirstPerson()

	for weapon, e in entries do
		if not weapon.Parent then
			untrack(weapon)
			continue
		end
		local rig = e.rig
		if not rig then
			continue
		end
		local isLocalFp = fp and e.owner == localPlayer
		local handle = weapon.PrimaryPart
		local dist = if handle then (handle.Position - camPos).Magnitude else 999
		local hide = isLocalFp or dist > MAX_RANGE
		if not hide then
			CharmRig.step(rig, dt, nil, false, 0)
		elseif not rig.hiddenNow then
			CharmRig.step(rig, dt, nil, true, 0)
		end
	end
end

function CharmWorldController.init() end

function CharmWorldController.start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and (d.Name == "WorldWeapon" or d.Name == "WorldWeaponLeft") then
			track(d)
		end
	end
	Workspace.DescendantAdded:Connect(track)
	Workspace.DescendantRemoving:Connect(function(inst)
		if inst:IsA("Model") and entries[inst] then
			untrack(inst)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return CharmWorldController
