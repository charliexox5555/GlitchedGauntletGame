--!strict
-- Weapon model validator. Checks every gun in ReplicatedStorage.Weapons
-- against the model standard (vault/02 Art/Art Direction.md) and prints
-- what's missing. Read-only: it never changes anything.
--
-- Run it any time: paste this whole file into Studio's Command Bar (or ask
-- Claude to run it through the Studio MCP). The last line printed is a summary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REQUIRED_ATTACHMENTS =
	{ "Muzzle", "RightGrip", "LeftGrip", "AimPoint", "Eject", "CharmPoint" }

local folder = ReplicatedStorage:FindFirstChild("Weapons")
if not folder then
	warn("[ValidateWeapons] ReplicatedStorage.Weapons is missing")
	return "missing folder"
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local weaponsConfig = nil
local animations = shared and shared:FindFirstChild("WeaponAnimations")
if shared then
	local ok, mod = pcall(function()
		return require(
				shared:FindFirstChild("Config"):FindFirstChild("Weapons") :: ModuleScript
			) :: any
	end)
	if ok then
		weaponsConfig = mod
	end
end

local function check(model: Model): ({ string }, { string })
	local problems: { string } = {}
	local notes: { string } = {}
	local function fail(msg: string)
		table.insert(problems, msg)
	end

	-- Handle / PrimaryPart.
	local handle = model.PrimaryPart
	if not handle or handle.Name ~= "Handle" then
		fail("PrimaryPart must be a part named Handle")
	elseif handle.Transparency < 1 then
		fail("Handle should be invisible (Transparency 1)")
	end

	-- Attachments.
	local config = weaponsConfig and weaponsConfig.get(model.Name)
	for _, name in REQUIRED_ATTACHMENTS do
		local att = model:FindFirstChild(name, true)
		-- Guns with no ADS (sidearms, shotguns) don't need a sight point; a
		-- melee weapon only needs its grip (and BladeBase / BladeTip).
		local optional = (name == "AimPoint" and config ~= nil and config.noAds == true)
			or (config ~= nil and config.melee ~= nil and name ~= "RightGrip")
		if (not att or not att:IsA("Attachment")) and not optional then
			fail("missing Attachment " .. name)
		end
	end
	local rightGrip = model:FindFirstChild("RightGrip", true)
	if handle and rightGrip and rightGrip.Parent ~= handle then
		fail("RightGrip should be on Handle")
	end

	-- Muzzle points forward (Handle -Z).
	local muzzle = model:FindFirstChild("Muzzle", true)
	if handle and muzzle and muzzle:IsA("Attachment") then
		if
			handle.CFrame:PointToObjectSpace(muzzle.WorldPosition).Z >= 0
			and not (
				weaponsConfig
				and weaponsConfig.get(model.Name)
				and weaponsConfig.get(model.Name).melee
			)
		then
			fail("Muzzle is not in front of the grip (barrel must run along Handle -Z)")
		end
	end

	-- Rig: Motor6D "Root" from Handle.
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local rootMotor = motors and motors:FindFirstChild("Root")
	if not rootMotor or not rootMotor:IsA("Motor6D") then
		fail("missing Rig.Motors.Root (Motor6D)")
	elseif rootMotor.Part0 ~= handle then
		fail("Rig.Motors.Root should start at Handle")
	end
	if motors then
		for _, m in motors:GetChildren() do
			if m:IsA("Motor6D") and (not m.Part0 or not m.Part1) then
				fail("Motor6D " .. m.Name .. " is not connected")
			end
		end
	end

	-- Parts: physics flags, joints, meshes, neon. (GetJoints() only works in
	-- Workspace, so collect joints from the model itself.)
	local jointed: { [Instance]: boolean } = {}
	for _, j in model:GetDescendants() do
		if j:IsA("JointInstance") then
			local jt = j :: JointInstance
			if jt.Part0 then
				jointed[jt.Part0] = true
			end
			if jt.Part1 then
				jointed[jt.Part1] = true
			end
		end
	end
	local hasBody = false
	local meshCount = 0
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then
			fail(
				"uses WeldConstraint ("
					.. d:GetFullName()
					.. "); use a Weld so clients keep the offset"
			)
		end
		if d:IsA("BasePart") then
			if d.Anchored then
				fail(d.Name .. " is Anchored")
			end
			if d.CanCollide or d.CanQuery or d.CanTouch then
				fail(d.Name .. " must have CanCollide/CanQuery/CanTouch off")
			end
			if not d.Massless then
				fail(d.Name .. " should be Massless")
			end
			if d ~= handle and not jointed[d] then
				fail(d.Name .. " is not welded to the gun")
			end
		end
		if d:IsA("MeshPart") then
			meshCount += 1
			if d.MeshId == "" then
				fail(d.Name .. " has no MeshId")
			end
			-- The main shell: Body_* (first roster) or Receiver_* (new direction).
			for _, main in { "Body", "Receiver" } do
				if d.Name == main or string.sub(d.Name, 1, #main + 1) == main .. "_" then
					hasBody = true
				end
			end
			if string.find(d.Name, "Neon") and d.Material ~= Enum.Material.Neon then
				fail(d.Name .. " should use the Neon material")
			end
		end
	end
	if meshCount == 0 then
		fail("no MeshParts")
	end
	if not hasBody then
		fail("no Body_* / Receiver_* part")
	end

	-- Code-side pieces (notes, not failures: a gun can be built before its stats).
	if weaponsConfig and not weaponsConfig.get(model.Name) then
		table.insert(notes, "no Config/Weapons entry yet")
	end
	if animations and not animations:FindFirstChild(model.Name) then
		table.insert(notes, "no WeaponAnimations module")
	end
	local _, size = model:GetBoundingBox()
	table.insert(notes, string.format("length %.2f studs", size.Z))
	return problems, notes
end

local names = {}
for _, m in folder:GetChildren() do
	if m:IsA("Model") then
		table.insert(names, m.Name)
	end
end
table.sort(names)

local bad = 0
for _, name in names do
	local problems, notes = check(folder:FindFirstChild(name) :: Model)
	if #problems == 0 then
		print(string.format("[ValidateWeapons] OK   %-12s %s", name, table.concat(notes, "; ")))
	else
		bad += 1
		warn(string.format("[ValidateWeapons] FAIL %-12s %s", name, table.concat(problems, "; ")))
	end
end
local summary = string.format("[ValidateWeapons] %d guns checked, %d with problems", #names, bad)
print(summary)
return summary
