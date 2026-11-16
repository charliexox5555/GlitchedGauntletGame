--!strict
-- Keeps a body's skinned limb meshes inside its character Model for as long
-- as something needs the whole body to be ONE Instance: a Highlight adorns
-- one Instance and its descendants, and the limbs (arms, legs, torso) live
-- outside the character in Workspace.GGBodyLimbs (shared/MatchBody), so an
-- outline on the character alone drew only the head, the hair and the gun
-- (Recon's reveal, found 2026-11-15).
--
-- The limbs go into a Model named Config/Avatar LIMB_HOLD inside the
-- character that has its own AnimationController + Animator. That Animator
-- claims the Bones under it, so the character's Animator leaves them alone
-- and Controllers/BodySkinController's bend is what is drawn (measured in
-- Studio 2026-11-15, 30 frames each: bones reset in 30 / 30 frames as plain
-- descendants of the character or in a Folder there, 0 / 30 in this Model).
-- Only the parent changes, on this client: the meshes keep their weld, tag,
-- owner link and clothing, so they still bend, follow the body and hide with
-- it (LocalTransparencyModifier).
--
-- Counted: `take` and `release` come in pairs, and the limbs go back where
-- they were with the last release. Limbs that arrive later (streamed in, or
-- the body rebuilt) are picked up while it's held.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local MatchBody = require(ReplicatedStorage.Shared.MatchBody)

local LimbHold = {}

type Hold = {
	count: number,
	box: Model,
	homes: { [MeshPart]: Instance }, -- where each limb was taken from
	nextScan: number,
	since: number,
}

local holds: { [Model]: Hold } = {}
local connection: RBXScriptConnection? = nil

-- Studio only: says so once if the character's Animator starts resetting the
-- held limbs' bones after all (an engine change would draw them unbent).
local STUDIO = RunService:IsStudio()
local CHECK_AFTER = 0.5 -- seconds a body is held before it's checked
local warned = false

local function boxOf(body: Model): Model
	local existing = body:FindFirstChild(Avatar.LIMB_HOLD)
	if existing and existing:IsA("Model") then
		return existing
	end
	local box = Instance.new("Model")
	box.Name = Avatar.LIMB_HOLD
	local controller = Instance.new("AnimationController")
	controller.Parent = box
	local animator = Instance.new("Animator")
	animator.Parent = controller
	box.Parent = body
	return box
end

-- The body's limb meshes that aren't in its box yet.
local function adopt(body: Model, hold: Hold)
	for _, part in body:GetChildren() do
		local link = part:FindFirstChild(Avatar.LIMB_LINK)
		local made = if link and link:IsA("ObjectValue") then link.Value else nil
		local from = made and made.Parent
		if made and made:IsA("MeshPart") and from and from ~= hold.box then
			hold.homes[made] = from
			made.Parent = hold.box
		end
	end
end

local function bent(box: Model): boolean
	for _, made in box:GetChildren() do
		for _, bone in made:GetChildren() do
			if bone:IsA("Bone") and bone.Transform ~= CFrame.identity then
				return true
			end
		end
	end
	return false
end

-- After the physics step, which is where a character's Animator writes.
local function step()
	local now = os.clock()
	for body, hold in holds do
		if now < hold.nextScan or not body:IsDescendantOf(Workspace) then
			continue
		end
		hold.nextScan = now + Avatar.LIMB_HOLD_RESCAN
		adopt(body, hold)
		if
			STUDIO
			and not warned
			and now - hold.since > CHECK_AFTER
			and hold.box:FindFirstChildWhichIsA("MeshPart")
			and not bent(hold.box)
		then
			warned = true
			warn("[LimbHold] held limbs are unbent: is the Animator resetting their bones?", body)
		end
	end
end

function LimbHold.take(body: Model)
	local hold = holds[body]
	if hold then
		hold.count += 1
		return
	end
	local now = os.clock()
	local made: Hold = {
		count = 1,
		box = boxOf(body),
		homes = {},
		nextScan = now + Avatar.LIMB_HOLD_RESCAN,
		since = now,
	}
	holds[body] = made
	adopt(body, made)
	if not connection then
		connection = RunService.PostSimulation:Connect(step)
	end
end

function LimbHold.release(body: Model)
	local hold = holds[body]
	if not hold then
		return
	end
	hold.count -= 1
	if hold.count > 0 then
		return
	end
	holds[body] = nil
	if next(holds) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
	-- A body that has left the world (destroyed, streamed out) keeps what is
	-- in it: its limbs went with it, and putting them back in the Workspace
	-- would leave them standing there without a body.
	if not body:IsDescendantOf(Workspace) then
		return
	end
	for _, made in hold.box:GetChildren() do
		if made:IsA("MeshPart") then
			local home = hold.homes[made]
			made.Parent = if home and home.Parent then home else MatchBody.limbFolder()
		end
	end
	hold.box:Destroy()
end

return LimbHold
