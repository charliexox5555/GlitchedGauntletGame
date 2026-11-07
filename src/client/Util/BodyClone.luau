--!strict
-- A client-only copy of a fighter's body that nothing treats as a fighter:
-- no scripts, sounds, particles, trails, beams, highlights, labels or force
-- fields, no attributes (team, health, state: the enemy outline reads
-- TeamId), no name or health bar, nothing that collides, queries or touches.
-- Used by the death fall (DeathFxController), the final-kill replay
-- (ReplayController) and the victory scene (MatchEndController).
--
-- `anchor`:
--   "root"  only the HumanoidRootPart is anchored; the rest hangs off it by
--           its joints (a fall or an animation can move it)
--   "own"   every part of the body itself is anchored and its body joints are
--           switched off (returned, so they can be switched back on): each part
--           is placed by hand (the replay)

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
	for attribute in copy:GetAttributes() do
		copy:SetAttribute(attribute, nil)
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		for attribute in humanoid:GetAttributes() do
			humanoid:SetAttribute(attribute, nil)
		end
	end
	copy.Name = name or body.Name
	return copy, joints
end

return BodyClone
