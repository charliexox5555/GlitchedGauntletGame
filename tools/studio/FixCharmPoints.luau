--!strict
-- Repositions Charm, CharmPoint, and CharmLoop* parts/joints on Classic,
-- Shorty, Odin, and Judge across stock ReplicatedStorage.Weapons and every
-- ServerStorage.WeaponSkins variant. Idempotent: safe to re-run.
-- Paste / run in Studio Edit command bar or via Roblox Studio MCP execute_luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

type TargetCfg = {
	bone: string,
	pos: Vector3,
	skinX: { [string]: number },
}

local TARGETS: { [string]: TargetCfg } = {
	Classic = {
		bone = "Root",
		pos = Vector3.new(-0.078, 0.205, -0.740),
		skinX = {
			Arcade = -0.100,
			Giltfold = -0.120,
			Payload = -0.120,
			Playback = -0.120,
			Slipframe = -0.120,
		},
	},
	Shorty = {
		bone = "Barrels",
		pos = Vector3.new(-0.110, 0.215, -0.740),
		skinX = {
			Arcade = -0.114,
			Sealwork = -0.117,
			Inkshift = -0.121,
			Breakwater = -0.114,
			Riftforge = -0.114,
		},
	},
	Odin = {
		bone = "Root",
		pos = Vector3.new(-0.116, 0.435, -1.180),
		skinX = {
			Arcade = -0.148,
			Breakwater = -0.119,
		},
	},
	Judge = {
		bone = "Root",
		pos = Vector3.new(-0.112, 0.445, -1.270),
		skinX = {
			Moltframe = -0.130,
			Breakwater = -0.116,
		},
	},
}

local function findBone(model: Model, handle: BasePart, boneName: string): BasePart?
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local motor = motors and motors:FindFirstChild(boneName)
	if motor and motor:IsA("Motor6D") and motor.Part1 and motor.Part1:IsA("BasePart") then
		return motor.Part1
	end
	local b = model:FindFirstChild(boneName, true)
	if b and b:IsA("BasePart") then
		return b
	end
	if boneName == "Root" then
		return handle
	end
	return nil
end

local function fixModel(model: Model, skinName: string?, cfg: TargetCfg): (boolean, string)
	local handle = model.PrimaryPart
	if not handle then
		return false, "no PrimaryPart"
	end
	local charm = model:FindFirstChild("Charm", true)
	if not (charm and charm:IsA("BasePart")) then
		return false, "no Charm part"
	end
	local cp = model:FindFirstChild("CharmPoint", true)
	if not (cp and cp:IsA("Attachment")) then
		return false, "no CharmPoint"
	end
	local targetBone = findBone(model, handle, cfg.bone)
	if not targetBone then
		return false, "missing bone " .. cfg.bone
	end

	local targetX = if skinName and cfg.skinX[skinName] then cfg.skinX[skinName] else cfg.pos.X
	local targetLocal = Vector3.new(targetX, cfg.pos.Y, cfg.pos.Z)
	local oldLocal = handle.CFrame:PointToObjectSpace(charm.Position)
	local deltaLocal = targetLocal - oldLocal
	local movedLoop = 0

	if deltaLocal.Magnitude > 1e-4 then
		local newCharmWorld = handle.CFrame * CFrame.new(targetLocal)
		charm.CFrame = newCharmWorld

		-- Move all CharmLoop* parts by the exact same Handle-local delta.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 9) == "CharmLoop" then
				local oldRel = handle.CFrame:ToObjectSpace(d.CFrame)
				local newLoopWorld = handle.CFrame
					* CFrame.new(oldRel.Position + deltaLocal)
					* oldRel.Rotation
				d.CFrame = newLoopWorld
				movedLoop += 1
			end
		end
	end

	-- Always ensure CharmPoint sits centered on Charm, and all joints target targetBone with exact C0/C1.
	cp.Parent = charm
	cp.CFrame = CFrame.new()

	for _, j in model:GetDescendants() do
		if (j:IsA("Motor6D") or j:IsA("Weld")) and j.Part1 then
			local p1 = j.Part1
			if p1 == charm or string.sub(p1.Name, 1, 9) == "CharmLoop" then
				local oldPart0 = j.Part0
				j.Part0 = targetBone
				j.C0 = targetBone.CFrame:ToObjectSpace(p1.CFrame)
				j.C1 = CFrame.new()
				if j:IsA("Motor6D") then
					j.Transform = CFrame.identity
				end
				if j:IsA("Weld") and oldPart0 and j.Parent == oldPart0 then
					j.Parent = targetBone
				end
			end
		elseif j:IsA("WeldConstraint") and j.Part1 then
			local p1 = j.Part1
			if p1 == charm or string.sub(p1.Name, 1, 9) == "CharmLoop" then
				j.Part0 = targetBone
			end
		end
	end

	local finalLocal = handle.CFrame:PointToObjectSpace(cp.WorldPosition)
	local err = (finalLocal - targetLocal).Magnitude
	if err > 0.001 then
		return false, string.format("err=%.4f", err)
	end
	return true,
		string.format(
			"ok (loops=%d pos=%.3f,%.3f,%.3f)",
			movedLoop,
			finalLocal.X,
			finalLocal.Y,
			finalLocal.Z
		)
end

local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
local skinsFolder = ServerStorage:FindFirstChild("WeaponSkins")

local updated = 0
local failed = 0
local perGun: { [string]: number } = {}
local errors: { string } = {}

for gunId, cfg in TARGETS do
	perGun[gunId] = 0
	if weaponsFolder then
		local stock = weaponsFolder:FindFirstChild(gunId)
		if stock and stock:IsA("Model") then
			local ok, msg = fixModel(stock, nil, cfg)
			if ok then
				updated += 1
				perGun[gunId] += 1
			else
				failed += 1
				table.insert(errors, gunId .. " STOCK: " .. msg)
			end
		else
			failed += 1
			table.insert(errors, gunId .. " STOCK missing")
		end
	end

	if skinsFolder then
		for _, line in skinsFolder:GetChildren() do
			local sm = line:FindFirstChild(gunId)
			if sm and sm:IsA("Model") then
				local ok, msg = fixModel(sm, line.Name, cfg)
				if ok then
					updated += 1
					perGun[gunId] += 1
				else
					failed += 1
					table.insert(errors, string.format("%s/%s: %s", line.Name, gunId, msg))
				end
			end
		end
	end
end

return string.format(
	"Updated=%d Failed=%d (Classic=%d, Shorty=%d, Odin=%d, Judge=%d) Errors=[%s]",
	updated,
	failed,
	perGun.Classic or 0,
	perGun.Shorty or 0,
	perGun.Odin or 0,
	perGun.Judge or 0,
	table.concat(errors, "; ")
)
