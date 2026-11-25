--!strict
-- The Market's Studio-authored bays and rear feature screen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local PlayZone = require(RS.Shared.PlayZone)
local PlayerData = require(RS.Shared.PlayerData)
local Release = require(RS.Shared.Config.Release)
local Products = require(RS.Shared.Config.Products)
local SkinArt = require(RS.Shared.SkinArt)
local UiMotion = require(RS.Shared.UiMotion)
local ShopFx = require(RS.Shared.Config.ShopFx)
local ShopCatalog = require(RS.Lobby.ShopCatalog)
local ShopController = require(script.Parent.ShopController)
local Router = require(script.Parent.Parent.Util.Router)
local WeaponShowcase = require(script.Parent.Parent.Util.WeaponShowcase)

local ShopDisplays = {}
local player = Players.LocalPlayer
local ZONE = "LobbyShopDisplayZone"
local DAILY = "LobbyShopDailyDisplay"
local FEATURE = "LobbyShopFeatureDisplay"

local function available(): boolean
	return PlayZone.get(player) == "Lobby" and not player:GetAttribute("LoadingScreen")
end

local function watchWeapons()
	local effects: { [Model]: WeaponShowcase.Effect } = {}
	local function clear(model: Model)
		local effect = effects[model]
		if effect then
			effects[model] = nil
			effect.destroy()
		end
	end
	CollectionService:GetInstanceRemovedSignal(WeaponShowcase.TAG):Connect(function(model)
		if model:IsA("Model") then
			clear(model)
		end
	end)

	while true do
		local camera = workspace.CurrentCamera
		local position = if available()
				and not Router.current()
				and camera
			then camera.CFrame.Position
			else nil
		for _, model in CollectionService:GetTagged(WeaponShowcase.TAG) do
			if not model:IsA("Model") then
				continue
			end
			if position and (model:GetPivot().Position - position).Magnitude < 44 then
				local effect = effects[model]
				if not effect then
					local line = model:GetAttribute("ShowcaseLine")
					effect =
						WeaponShowcase.mount(model, if type(line) == "string" then line else nil)
					effects[model] = effect
				end
				if effect then
					effect.step(os.clock())
				end
			else
				clear(model)
			end
		end
		task.wait(if position then 0.05 else 0.20)
	end
end

local function contains(zone: BasePart, position: Vector3, margin: number): boolean
	local point = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(point.X) <= half.X + margin
		and math.abs(point.Y) <= half.Y
		and math.abs(point.Z) <= half.Z + margin
end

local function watchBays()
	local inside: BasePart? = nil
	while true do
		local character = player.Character
		local root = if available() and character
			then character:FindFirstChild("HumanoidRootPart")
			else nil
		local position = if root and root:IsA("BasePart") then root.Position else nil
		local previous = inside
		if
			previous
			and (
				not position
				or not previous:IsDescendantOf(workspace)
				or not contains(previous, position, 0.8)
			)
		then
			ShopController.closeDisplay(previous)
			inside = nil
		end
		if position and not inside then
			for _, zone in CollectionService:GetTagged(ZONE) do
				if
					zone:IsA("BasePart")
					and zone:IsDescendantOf(workspace)
					and contains(zone, position, 0)
				then
					local destination = zone:GetAttribute("ShopDestination")
					if type(destination) == "string" then
						inside = zone
						ShopController.openDisplay(destination, zone)
						break
					end
				end
			end
		end
		task.wait(0.1)
	end
end

local function drawDaily()
	local daily = PlayerData.daily(player)
	for _, screen in CollectionService:GetTagged(DAILY) do
		for i = 1, 3 do
			local art = screen:FindFirstChild("Skin" .. i, true)
			local pick = daily.picks[i]
			if art and art:IsA("ImageLabel") then
				art.Image = if pick then SkinArt.portrait(pick.gun, pick.line) or "" else ""
			end
		end
	end
end

local function watchDaily()
	CollectionService:GetInstanceAddedSignal(DAILY):Connect(function()
		task.defer(drawDaily)
	end)
	local value = player:WaitForChild(PlayerData.DAILY, 60)
	if value and value:IsA("StringValue") then
		value.Changed:Connect(drawDaily)
	end
	drawDaily()
end

local function watchFeature()
	local featured = ShopCatalog.featuredBundles(Products.STARTER ~= nil, Release.SHOP_FULL_LAYOUT)
	if #featured == 0 then
		return
	end
	local mounted: { [Instance]: () -> () } = {}
	local playerGui = player:WaitForChild("PlayerGui")

	local function mount(screen: Instance)
		if not screen:IsA("BasePart") or mounted[screen] then
			return
		end
		local source = screen:WaitForChild("ShopBoard", 5)
		if not source or not source:IsA("SurfaceGui") then
			return
		end
		if mounted[screen] or not screen:IsDescendantOf(workspace) then
			return
		end
		local gui = source:Clone()
		gui.Adornee = screen
		gui.Active = true
		local card = gui:FindFirstChild("FeatureCard") :: TextButton
		local art = card:FindFirstChild("Art") :: ImageLabel
		local hero = card:FindFirstChild("Hero") :: ImageLabel
		local title = card:FindFirstChild("Title") :: TextLabel
		local subtitle = card:FindFirstChild("Subtitle") :: TextLabel
		local prompt = screen:FindFirstChildWhichIsA("ProximityPrompt")
		local home = art.Position
		local index = 1
		local function draw(animate: boolean)
			local bundle = featured[index]
			art.Image = bundle.banner or ""
			hero.Image = if bundle.slot == "Starter"
				then ShopCatalog.ART.starterContents
				else bundle.hero or ""
			title.Text = bundle.name
			subtitle.Text = bundle.sub or ""
			for i = 1, #featured do
				local dot = card:FindFirstChild("Slide" .. i)
				if dot and dot:IsA("Frame") then
					dot.BackgroundTransparency = if i == index then 0 else 0.7
				end
			end
			if prompt then
				prompt.ObjectText = bundle.name
			end
			if animate then
				art.Position = if UiMotion.reduced() then home else home + UDim2.fromOffset(30, 0)
				art.ImageTransparency = 0.65
				UiMotion.tween(
					art,
					ShopFx.carousel.transition,
					{ Position = home, ImageTransparency = 0.18 }
				)
			end
		end

		local function openSlide()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				available()
				and root
				and root:IsA("BasePart")
				and (root.Position - screen.Position).Magnitude <= 29
			then
				ShopController.openDisplay(featured[index].id, nil)
			end
		end
		card.Activated:Connect(openSlide)
		local trigger = if prompt then prompt.Triggered:Connect(openSlide) else nil
		draw(false)
		gui.Parent = playerGui
		source.Enabled = false
		local cycle = task.spawn(function()
			while true do
				task.wait(ShopFx.carousel.interval)
				if not Router.current() then
					index = index % #featured + 1
					draw(true)
				end
			end
		end)
		mounted[screen] = function()
			task.cancel(cycle)
			if trigger then
				trigger:Disconnect()
			end
			gui:Destroy()
			source.Enabled = true
		end
	end

	CollectionService:GetInstanceAddedSignal(FEATURE):Connect(mount)
	CollectionService:GetInstanceRemovedSignal(FEATURE):Connect(function(source)
		local unmount = mounted[source]
		if unmount then
			mounted[source] = nil
			unmount()
		end
	end)
	for _, source in CollectionService:GetTagged(FEATURE) do
		mount(source)
	end
end

function ShopDisplays.start()
	task.spawn(watchDaily)
	task.spawn(watchFeature)
	task.spawn(watchWeapons)
	watchBays()
end

return ShopDisplays
