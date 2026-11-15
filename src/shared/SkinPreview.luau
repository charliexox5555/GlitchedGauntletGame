--!strict
-- Surface substitution from immutable stock/skin templates. Structural
-- templates are selected before cloning so their parts join the stock rig.
-- Each player picks their own line (Config/SkinPreview): a server-set Player
-- attribute. Camera guns follow their viewer (or the spectated player), world
-- guns follow the character that holds them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Config.SkinPreview)

local SkinPreview = {}

-- Camera guns carry their owner's UserId in this attribute (ViewmodelController).
SkinPreview.OWNER_ATTRIBUTE = "SkinOwnerId"

-- Whether the preview runs in this server at all (match place; Studio or LIVE).
function SkinPreview.allowed(): boolean
	return game.PlaceId == Config.PLACE_ID and (RunService:IsStudio() or Config.LIVE)
end

-- Whether `player` may pick a line (Config.USER_IDS limits live servers).
function SkinPreview.canUse(player: Player): boolean
	if not SkinPreview.allowed() then
		return false
	end
	if RunService:IsStudio() or #Config.USER_IDS == 0 then
		return true
	end
	return table.find(Config.USER_IDS, player.UserId) ~= nil
end

function SkinPreview.valid(value: any): boolean
	return typeof(value) == "string" and table.find(Config.LINES, value) ~= nil
end

-- The line `player`'s gun `id` wears; on the client, nil means the local
-- player. A line picked with the in-match preview (F7) wins while it isn't
-- Stock; otherwise the skin equipped for that gun in the Lobby's Locker
-- (the server-set attribute Skin_<id>, Shared/Locker).
function SkinPreview.line(player: Player?, id: string?): string
	local who = player or (if RunService:IsClient() then Players.LocalPlayer else nil)
	if not who or not SkinPreview.allowed() then
		return "Stock"
	end
	local value = who:GetAttribute(Config.ATTRIBUTE)
	if SkinPreview.valid(value) and value ~= "Stock" then
		return value :: string
	end
	if id then
		local saved = who:GetAttribute("Skin_" .. id)
		if SkinPreview.valid(saved) then
			return saved :: string
		end
	end
	return "Stock"
end

-- Whose line a gun model shows: a camera gun's SkinOwnerId (else the local
-- player), or the player whose character holds a world gun. Nil: no owner
-- (leave the model as it is).
function SkinPreview.ownerOf(model: Model): Player?
	local id = model:GetAttribute(SkinPreview.OWNER_ATTRIBUTE)
	if typeof(id) == "number" then
		return Players:GetPlayerByUserId(id)
	end
	if RunService:IsClient() then
		local camera = Workspace.CurrentCamera
		if camera and model:IsDescendantOf(camera) then
			return Players.LocalPlayer
		end
	end
	local node: Instance? = model.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") then
			local owner = Players:GetPlayerFromCharacter(node)
			if owner then
				return owner
			end
		end
		node = node.Parent
	end
	return nil
end

function SkinPreview.resolve(id: string, line: string): (Model?, string)
	local stocks = ReplicatedStorage:FindFirstChild("Weapons")
	local stock = stocks and stocks:FindFirstChild(id)
	if not stock or not stock:IsA("Model") then
		return nil, "Stock"
	end
	if SkinPreview.allowed() and SkinPreview.valid(line) and line ~= "Stock" then
		local skins = ReplicatedStorage:FindFirstChild("WeaponSkins")
		local folder = skins and skins:FindFirstChild(line)
		if id == "Knife" and line == "PopCircuit" then
			local bat = folder and folder:FindFirstChild("Bat")
			if bat and bat:IsA("Model") and bat:GetAttribute("SkinReady") == true then
				return bat, line
			end
		end
		local variant = folder and folder:FindFirstChild(id)
		if variant and variant:IsA("Model") and variant:GetAttribute("SkinReady") == true then
			return variant, line
		end
	end
	return stock, "Stock"
end

function SkinPreview.geometry(templateId: string, player: Player?): Model?
	local variant = SkinPreview.resolve(templateId, SkinPreview.line(player, templateId))
	if
		variant
		and (variant:GetAttribute("PreviewGeometry") or variant:GetAttribute("PreviewMeleeModel"))
	then
		return variant
	end
	return nil
end

function SkinPreview.geometryChanged(model: Model, templateId: string, player: Player?): boolean
	local variant = SkinPreview.geometry(templateId, player)
	return model:GetAttribute("PreviewGeometry")
			~= (variant and variant:GetAttribute("PreviewGeometry"))
		or model:GetAttribute("PreviewMeleeModel")
			~= (variant and variant:GetAttribute("PreviewMeleeModel"))
end

function SkinPreview.apply(model: Model)
	if not SkinPreview.allowed() then
		return
	end
	local id = model:GetAttribute("WeaponId")
	if typeof(id) ~= "string" then
		return
	end
	local owner = SkinPreview.ownerOf(model)
	if not owner then
		return
	end
	local template, resolved = SkinPreview.resolve(id, SkinPreview.line(owner, id))
	if not template then
		return
	end
	local geometry = template:GetAttribute("PreviewGeometry")
	if geometry or model:GetAttribute("PreviewGeometry") then
		if model:GetAttribute("PreviewGeometry") == geometry then
			model:SetAttribute("PreviewResolvedLine", resolved)
		end
		return
	end
	-- Melee swaps own their geometry and never copy surfaces onto a different mesh.
	local custom = template:GetAttribute("PreviewMeleeModel")
	if model:GetAttribute("PreviewMeleeModel") ~= custom then
		return
	end
	if custom then
		model:SetAttribute("PreviewResolvedLine", resolved)
		return
	end
	for _, part in model:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end
		local source = template:FindFirstChild(part.Name)
		if not source or not source:IsA("MeshPart") then
			continue
		end
		part.Color = source.Color
		part.Material = source.Material
		part.MaterialVariant = source.MaterialVariant
		part.Reflectance = source.Reflectance
		part.TextureID = source.TextureID
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		local surface = source:FindFirstChildOfClass("SurfaceAppearance")
		if surface then
			surface:Clone().Parent = part
		end
	end
	model:SetAttribute("PreviewResolvedLine", resolved)
end

-- Workspace includes camera WorldModels, held world guns, and future pickup
-- models (no owner: left alone). Late streamed parts and reparenting are covered by DescendantAdded.
-- Coalesce model/part events; surface changes do not schedule another pass.
function SkinPreview.watch(): () -> ()
	if not SkinPreview.allowed() then
		return function() end
	end
	local stopped = false
	local pending: { [Model]: boolean } = {}
	local function queue(instance: Instance)
		if not instance:IsA("Model") and not instance:IsA("MeshPart") then
			return
		end
		local model = if instance:IsA("Model") then instance else instance.Parent
		if
			not model
			or not model:IsA("Model")
			or typeof(model:GetAttribute("WeaponId")) ~= "string"
		then
			return
		end
		-- Only the server writes replicated world surfaces. Clients own camera guns.
		if RunService:IsClient() then
			local camera = Workspace.CurrentCamera
			if not camera or not model:IsDescendantOf(camera) then
				return
			end
		end
		if pending[model] then
			return
		end
		pending[model] = true
		task.defer(function()
			pending[model] = nil
			if not stopped and model:IsDescendantOf(Workspace) then
				SkinPreview.apply(model)
			end
		end)
	end
	local function refresh()
		for _, instance in Workspace:GetDescendants() do
			if instance:IsA("Model") then
				queue(instance)
			end
		end
	end
	local connections = { Workspace.DescendantAdded:Connect(queue) }
	-- A player's pick re-skins only their own guns: on the server their
	-- character (world guns), on a client the camera (camera guns). No full
	-- Workspace scan per request (live servers: a spammed pick stays cheap).
	local function refreshFor(p: Player)
		local root: Instance? = if RunService:IsServer()
			then p.Character
			else Workspace.CurrentCamera
		if not root then
			return
		end
		for _, instance in root:GetDescendants() do
			if instance:IsA("Model") then
				queue(instance)
			end
		end
	end
	local perPlayer: { [Player]: RBXScriptConnection } = {}
	local function watchPlayer(p: Player)
		perPlayer[p] = p:GetAttributeChangedSignal(Config.ATTRIBUTE):Connect(function()
			refreshFor(p)
		end)
	end
	if RunService:IsServer() then
		for _, p in Players:GetPlayers() do
			watchPlayer(p)
		end
		table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
		table.insert(
			connections,
			Players.PlayerRemoving:Connect(function(p)
				local c = perPlayer[p]
				if c then
					c:Disconnect()
					perPlayer[p] = nil
				end
			end)
		)
	else
		watchPlayer(Players.LocalPlayer)
	end
	refresh()
	return function()
		stopped = true
		for _, c in connections do
			c:Disconnect()
		end
		for _, c in perPlayer do
			c:Disconnect()
		end
		table.clear(perPlayer)
		table.clear(pending)
	end
end

return SkinPreview
