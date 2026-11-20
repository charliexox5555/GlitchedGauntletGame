--!strict
-- Dev tool, not shipped (2026-11-21 animation pass, round 2). Per-frame check
-- of the first-person FOREARMS against the gun in hand, skins included and in
-- the gun's live pose: a box the size of the forearm span is put where each arm
-- block is and Roblox's own collision geometry answers whether it overlaps a
-- visible gun part (WorldModel:GetPartsInPart; gun MeshParts use Default
-- collision fidelity, a convex decomposition). The box is then narrowed step
-- by step (INSETS) to say how deep the deepest overlap is.
-- (An exact triangle test needs EditableMesh, which is off for this experience
-- in Experience Settings -> Security; the owner's call. tools/studio/
-- SampleHands.luau + tools/blender/check_hand_clipping.py are exact against
-- the stock FBX but don't see skins.)
--
-- Paste into a playtest's Client (MCP execute_luau) and call, e.g.:
--   return Check.run("fire", 1.7)      -- DevAction "fire", 1.7 s of frames
--   return Check.run("reload", 3.3)    -- after a shot (a full mag won't reload)
-- Result per arm: "clear", or the deepest inset that still overlaps (studs into
-- the 0.25 half-width), the part, and how many samples were >= 0.03 deep.
--
-- The forearm span runs FROM..TO studs up the block from its hand-end tip (the
-- hand holds the gun, so its first FROM studs may overlap). Pistols wrap the
-- grip in the fist block (the RIVALS high grip), so use FROM = 1.0 for them.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Check = {}

Check.FROM = 0.55
Check.TO = 2.5
Check.INSETS = { 0, 0.03, 0.06, 0.1, 0.15, 0.2 }

type Result = { worst: number, part: string?, at: number, bad: number, n: number }

function Check.run(action: string?, seconds: number): string
	local cam = Workspace.CurrentCamera
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local StateValues = require(shared:WaitForChild("StateValues") :: ModuleScript) :: any
	local probe = Instance.new("Part")
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanTouch = false
	probe.CanQuery = false
	probe.Transparency = 1
	probe.Name = "ArmClipProbe"
	probe.Parent = cam
	local res: { [string]: Result } = {}
	if action then
		StateValues.set(Workspace, "DevAction", action)
	end
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		RunService.Heartbeat:Wait() -- after this frame's viewmodel step
		local arms = cam:FindFirstChild("ViewmodelArms")
		for _, vmName in { "Viewmodel", "ViewmodelLeft" } do
			local vm = cam:FindFirstChild(vmName)
			if vm and arms and vm:IsA("WorldModel") then
				local visible = {}
				for _, d in vm:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanQuery = true -- this client only; the viewmodel is rebuilt on the next equip
						if d.Transparency < 1 then
							table.insert(visible, d)
						end
					end
				end
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = visible
				for _, side in { "Right", "Left" } do
					local arm = arms:FindFirstChild(side .. "Arm")
					if arm and arm:IsA("BasePart") and arm.LocalTransparencyModifier < 1 then
						local cf = arm.CFrame
							* CFrame.new(0, -arm.Size.Y / 2 + (Check.FROM + Check.TO) / 2, 0)
						local depth, where = -1, nil
						for _, inset in Check.INSETS do
							probe.Size = Vector3.new(
								arm.Size.X - 2 * inset,
								Check.TO - Check.FROM,
								arm.Size.Z - 2 * inset
							)
							probe.CFrame = cf
							local hit: BasePart? = nil
							for _, p in vm:GetPartsInPart(probe, params) do
								if p.LocalTransparencyModifier < 1 then
									hit = p
									break
								end
							end
							if not hit then
								break
							end
							depth, where = inset, hit.Name
						end
						local r = res[side] or { worst = -1, part = nil, at = 0, bad = 0, n = 0 }
						r.n += 1
						if depth >= 0.03 then
							r.bad += 1
						end
						if depth > r.worst then
							r.worst, r.part, r.at = depth, where, os.clock() - t0
						end
						res[side] = r
					end
				end
			end
		end
	end
	probe:Destroy()
	local out = {}
	for side, r in res do
		table.insert(
			out,
			if r.worst < 0
				then side .. " clear (" .. r.n .. " samples)"
				else string.format(
					"%s %.2f deep at %.2fs (%s), %d/%d samples >= 0.03",
					side,
					r.worst,
					r.at,
					tostring(r.part),
					r.bad,
					r.n
				)
		)
	end
	return table.concat(out, "; ")
end

return Check
