--!strict
-- A client-only copy of a fighter's body that nothing treats as a fighter:
-- no scripts, sounds, particles, trails, beams, highlights, labels, IK or
-- force fields, no attributes (team, health, state: the enemy outline reads
-- TeamId), no name or health bar, nothing that collides, queries or touches.
-- Used by the death fall (DeathFxController), the final-kill replay
-- (ReplayController), the victory scene (MatchEndController) and Dash's
-- decoy (UpgradeFx/DashDecoy, with `kinematic`).
--
-- `anchor`:
--   "root"  only the HumanoidRootPart is anchored; the rest hangs off it by
--           its joints (a fall or an animation can move it)
--   "own"   every part of the body itself is anchored and its body joints are
--           switched off (returned, so they can be switched back on): each part
--           is placed by hand (the replay)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local MatchBody = require(ReplicatedStorage.Shared.MatchBody)

local BodyClone = {}

local STRIP = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Sound = true,
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Highlight = true,
	BillboardGui = true,
	ForceField = true,
	-- The support hand's IK (Controllers/GripController) would come along
	-- still switched on, and pin the copy's left hand to its gun through a
	-- death fall, the replay or the victory pose (found 2026-11-12).
	IKControl = true,
}

export type Anchor = "root" | "own"

function BodyClone.copy(body: Model, anchor: Anchor, name: string?): (Model?, { Instance })
	local joints: { Instance } = {}
	local was = body.Archivable
	body.Archivable = true
	local ok, made = pcall(function()
		return body:Clone()
	end)
	body.Archivable = was
	if not ok or not made then
		return nil, joints
	end
	local copy = made :: Model
	local own: { [Instance]: boolean } = {}
	for _, child in copy:GetChildren() do
		if child:IsA("BasePart") then
			own[child] = true
		end
	end
	for _, d in copy:GetDescendants() do
		if STRIP[d.ClassName] then
			d:Destroy()
		elseif anchor == "own" and d:IsA("JointInstance") then
			if d.Part0 and d.Part1 and own[d.Part0] and own[d.Part1] then
				d.Enabled = false
				table.insert(joints, d)
			end
		elseif anchor == "own" and d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent and own[a0.Parent] and own[a1.Parent] then
				d.Enabled = false
				table.insert(joints, d)
			end
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = if anchor == "own" then own[d] == true else d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Motor6D") and anchor == "root" then
			d.Transform = CFrame.identity -- from rest, not the live pose
		end
	end
	StateValues.clear(copy)
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		StateValues.clear(humanoid)
	end
	-- Skinned limbs live outside the body (shared/MatchBody limbFolder):
	-- give the copy its own, on this client.
	for _, d in copy:GetDescendants() do
		local part = d.Parent
		if
			d.Name == Avatar.LIMB_LINK
			and d:IsA("ObjectValue")
			and d.Value
			and part
			and part:IsA("BasePart")
		then
			MatchBody.attachLimb(d.Value, part, true)
		end
	end
	-- A body copied while its limbs were held inside it (Util/LimbHold: an
	-- outlined body) brought copies of them along: the ones made above
	-- replace those.
	local held = copy:FindFirstChild(Avatar.LIMB_HOLD)
	if held then
		held:Destroy()
	end
	copy.Name = name or body.Name
	return copy, joints
end

-- For a "root" copy that is moved about while it plays animations (Dash's
-- decoy): its animation joints (AnimationConstraint) become Motor6Ds, and
-- every other constraint but the rigid ones goes. With the root anchored the
-- copy then poses kinematically: nothing hangs on physics or lags behind.
function BodyClone.kinematic(copy: Model)
	for _, d in copy:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local m = Instance.new("Motor6D")
				m.Name = d.Name
				m.Part0 = p0
				m.Part1 = p1
				m.C0 = a0.CFrame
				m.C1 = a1.CFrame
				m.Parent = p1
			end
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Constraint") and not d:IsA("RigidConstraint") then
			d:Destroy()
		end
	end
end

return BodyClone
