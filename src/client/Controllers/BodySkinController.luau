--!strict
-- Bends every third-person block body's skinned arms and legs to match its
-- R15 parts, each frame, after the animation (vault/01 Design/Third Person
-- Overhaul.md §8). The limb meshes and their Bones are made by
-- shared/MatchBody on the server (players, bots, range dummies), or copied by
-- Util/BodyClone on this client, and tagged Config/Avatar LIMB_TAG. They live
-- outside the characters (MatchBody.limbFolder). Bone.Transform is local to
-- this client, so every client bends what it draws. No remotes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local MatchBody = require(ReplicatedStorage.Shared.MatchBody)

local BodySkinController = {}

-- Tagged meshes, and their state once every part they need has arrived
-- (StreamingEnabled: a limb can show up before its forearm or hand).
local meshes: { [MeshPart]: MatchBody.Limb | false } = {}
-- The LocalTransparencyModifier last written to each mesh and its clothing.
local shown: { [MeshPart]: number } = {}

local function add(inst: Instance)
	if inst:IsA("MeshPart") then
		meshes[inst] = false
	end
end

local function remove(inst: Instance)
	if inst:IsA("MeshPart") then
		meshes[inst] = nil
		shown[inst] = nil
	end
end

local function step()
	for made, limb in meshes do
		if not limb then
			local found = MatchBody.limb(made)
			if not found then
				continue
			end
			meshes[made] = found
			limb = found
		end
		-- A part rebuilt or streamed out: find it again next frame.
		if
			not (limb.lower.Parent and limb.tip.Parent and limb.upper.Parent)
			or (limb.root ~= nil and limb.root.Parent == nil)
		then
			meshes[made] = false
			continue
		end
		-- First person, spectating, the death fall and the replay hide a body
		-- by its parts' LocalTransparencyModifier: the limb follows its part,
		-- and so does its clothing (each Texture has its own modifier: hiding
		-- the mesh alone left your own shirt floating in first person). A limb
		-- that stays fully hidden isn't bent at all (nobody sees it); one that
		-- shows again is bent before it appears.
		local hide = limb.upper.LocalTransparencyModifier
		if hide >= 1 and shown[made] == hide then
			continue
		end
		MatchBody.skinLimb(limb)
		if hide ~= shown[made] then
			shown[made] = hide
			made.LocalTransparencyModifier = hide
			for _, child in made:GetChildren() do
				if child:IsA("Decal") then -- Texture is a Decal
					child.LocalTransparencyModifier = hide
				end
			end
		end
	end
end

function BodySkinController.start()
	for _, inst in CollectionService:GetTagged(Avatar.LIMB_TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(Avatar.LIMB_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Avatar.LIMB_TAG):Connect(remove)
	RunService.PreRender:Connect(step)
end

return BodySkinController
