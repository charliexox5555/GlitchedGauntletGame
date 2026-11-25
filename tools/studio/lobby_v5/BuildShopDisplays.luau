--!nocheck
-- Draft Duels / Edit mode. Apply after BuildShopFit to the four existing bay shells and junction TV.
-- The catalogue and original skin models must be installed. Re-running replaces only this fit-out.

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Catalog = require(RS.Lobby.ShopCatalog:Clone())
local Theme = require(RS.Shared.Config.Theme)
local K = require(SS.V5Kit.LobbyKit:Clone())
local shop = workspace.LobbyV5.Shell.Shop
assert(game.PlaceId == 71551303511506, "Select the Draft Duels place")

local GOLD = Color3.fromHex("FFC83D")
local WHITE = Color3.fromHex("F6F4EF")
local MUTED = Color3.fromHex("C7C6CB")
local DARK = Color3.fromHex("14151C")
local PANEL = Color3.fromHex("22242D")
local V = Vector3.new
local P = UDim2.fromScale

local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function panel(parent, name, x, y, w, h, color)
	return make("Frame", parent, {
		Name = name,
		Position = P(x, y),
		Size = P(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
end

local function label(parent, name, words, x, y, w, h, color, font)
	return make("TextLabel", parent, {
		Name = name,
		Position = P(x, y),
		Size = P(w, h),
		Text = words,
		TextScaled = true,
		FontFace = font or Theme.TEXT.label.font,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
	})
end

local function image(parent, name, id, x, y, w, h, scaleType)
	return make("ImageLabel", parent, {
		Name = name,
		Position = P(x, y),
		Size = P(w, h),
		Image = id or "",
		ScaleType = scaleType or Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
	})
end

local function board(part, clickable)
	local previous = part:FindFirstChildOfClass("SurfaceGui")
	if previous then
		previous:Destroy()
	end
	local gui = make("SurfaceGui", part, {
		Name = "ShopBoard",
		Face = Enum.NormalId.Back,
		LightInfluence = 0,
		Brightness = 1,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		MaxDistance = if clickable then 72 else 85,
	})
	local root = make(if clickable then "TextButton" else "Frame", gui, {
		Name = if clickable then "FeatureCard" else "Board",
		Size = P(1, 1),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	if clickable then
		root.Text = ""
		root.AutoButtonColor = false
		root.Selectable = false
	end
	return gui, root
end

local function banner(root, bundle, rear)
	local art = image(root, "Art", bundle.banner, 0, 0, 1, 1, Enum.ScaleType.Crop)
	art.ImageTransparency = if rear then 0.18 else 0.28
	local shade = panel(root, "Shade", 0, 0, 1, 1, DARK)
	make("UIGradient", shade, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.45, 0.18),
			NumberSequenceKeypoint.new(1, 0.90),
		}),
	})
	local hero = if bundle.slot == "Starter" then Catalog.ART.starterContents else bundle.hero
	image(root, "Hero", hero, 0.61, 0.08, 0.36, 0.83)
	panel(root, "Rail", 0.050, 0.13, 0.038, 0.013, GOLD)
	label(
		root,
		"Category",
		if rear then "FEATURED BUNDLES" else "EXCLUSIVE BUNDLE",
		0.05,
		0.17,
		0.48,
		0.09,
		GOLD
	)
	label(root, "Title", bundle.name, 0.05, 0.30, 0.52, 0.21, WHITE, Theme.TEXT.titleCard.font)
	label(root, "Subtitle", bundle.sub or "", 0.05, 0.52, 0.53, 0.10, MUTED)
	label(
		root,
		"Action",
		if rear then "VIEW BUNDLE  »" else "STEP CLOSER TO VIEW  »",
		0.05,
		0.77,
		0.50,
		0.10,
		GOLD
	)
end

local function shelfBoard(root, destination)
	panel(root, "Rule", 0.055, 0.17, 0.040, 0.013, GOLD)
	local daily = destination == "DAILY"
	label(
		root,
		"Title",
		if daily then "DAILY SHOP" else "CASES",
		0.055,
		0.22,
		0.51,
		0.24,
		WHITE,
		Theme.TEXT.titleCard.font
	)
	label(
		root,
		"Action",
		if daily then "STEP CLOSER TO SHOP  »" else "STEP CLOSER TO BROWSE  »",
		0.055,
		0.73,
		0.49,
		0.10,
		GOLD
	)
	if daily then
		root.Title.Position = P(0.055, 0.16)
		root.Title.Size = P(0.50, 0.15)
		root.Rule.Position = P(0.055, 0.12)
		root.Action.Position = P(0.055, 0.84)
		label(root, "Subtitle", "REFRESHES DAILY", 0.64, 0.19, 0.31, 0.09, MUTED)
		for i = 1, 3 do
			local x = 0.055 + (i - 1) * 0.301
			panel(root, "Tile" .. i, x, 0.34, 0.287, 0.46, PANEL)
			image(root, "Skin" .. i, nil, x, 0.36, 0.287, 0.42)
		end
	else
		for i, case in Catalog.CASES do
			local y = 0.18 + (i - 1) * 0.16
			panel(root, "Swatch" .. i, 0.59, y, 0.012, 0.104, case.color)
			label(root, "Case" .. i, case.name, 0.63, y, 0.31, 0.104, MUTED)
		end
	end
end

local function mountSkin(parent, frame, item)
	local x, source, length, angle = table.unpack(item)
	local base = frame * CFrame.new(x, 1.1, -4.95)
	local stand = K.model(parent, source.Name .. "Stand")
	for _, tier in
		{
			{ "Foot", 0.14, 0.28, 2.75, K.L.wains },
			{ "Body", 0.49, 0.42, 2.46, K.L.dark },
			{ "Cap", 0.765, 0.13, 2.62, K.L.steel },
		}
	do
		K.mesh(
			stand,
			tier[1],
			"V5_Flange8",
			V(tier[3], tier[4], tier[4]),
			base * CFrame.new(0, tier[2], 0) * CFrame.Angles(0, 0, math.pi / 2),
			tier[5]
		)
	end
	local model = source:Clone()
	for _, object in model:GetDescendants() do
		if not object.Parent then
			continue
		elseif object:IsA("BasePart") then
			if object.Transparency == 1 and object ~= model.PrimaryPart then
				object:Destroy()
			else
				object.Anchored = true
				object.CanCollide = false
				object.CanQuery = false
				object.CanTouch = false
			end
		elseif
			object:IsA("BaseScript")
			or object:IsA("ModuleScript")
			or object:IsA("Attachment")
			or object:IsA("Sound")
			or object:IsA("ParticleEmitter")
			or object:IsA("Light")
			or object:IsA("Beam")
			or object:IsA("Trail")
		then
			object:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * length / size.Z)
	local pose = base * CFrame.Angles(0, 0, angle) * CFrame.Angles(0, -math.pi / 2, 0)
	model:PivotTo(pose)
	local cf, bounds = model:GetBoundingBox()
	local localCenter = base:PointToObjectSpace(cf.Position)
	local halfHeight = (
		math.abs(cf.RightVector.Y) * bounds.X
		+ math.abs(cf.UpVector.Y) * bounds.Y
		+ math.abs(cf.LookVector.Y) * bounds.Z
	) / 2
	-- Center the silhouette, then seat a bracket into the back of the body.
	model:PivotTo(
		pose
			+ base:VectorToWorldSpace(
				V(-localCenter.X, 1.10 + halfHeight - localCenter.Y, -localCenter.Z)
			)
	)
	local contact, nearest = nil, math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Magnitude > 0.16 then
			local localPosition = base:PointToObjectSpace(part.Position)
			local score = math.abs(localPosition.X) + math.abs(localPosition.Y - 1.55) * 0.35
			if score < nearest then
				contact, nearest = localPosition, score
			end
		end
	end
	assert(contact, "Display skin needs visible geometry")
	local back = V(contact.X, contact.Y, -0.33)
	local bottom = V(contact.X * 0.36, 0.80, -0.33)
	K.part(
		stand,
		"Upright",
		V(0.16, 0.18, (back - bottom).Magnitude + 0.08),
		base * CFrame.lookAt((back + bottom) / 2, back, Vector3.zAxis),
		K.L.dark
	)
	K.lpart(
		base,
		stand,
		"Seat",
		back - V(0.14, 0.095, 0.09),
		V(contact.X + 0.14, contact.Y + 0.095, contact.Z + 0.025),
		K.L.dark
	)
	model.Parent = stand
end

local tempest = SS.WeaponSkins.TempestStrike
local ruin = SS.WeaponSkins.RuinBlighted
local bays = {
	{
		"FEATURED",
		"TempestStrike",
		{
			{ -4.8, tempest.Knife, 3.6, -0.20 },
			{ 0, tempest.Vandal, 5.5, 0.03 },
			{ 4.8, tempest.Sheriff, 2.65, 0.12 },
		},
	},
	{
		"NEWIN",
		"RuinBlighted",
		{
			{ -4.85, ruin.Operator, 4.7, 0.02 },
			{ 0, ruin.Knife, 4.3, -0.36 },
			{ 4.8, ruin.Spectre, 3.5, 0.12 },
		},
	},
	{ "SEASON", "DAILY" },
	{ "CASES", "CASES" },
}

for _, entry in bays do
	local kind, destination, products = table.unpack(entry)
	local bay = shop.Bays["Bay_" .. kind]
	local screen = bay.Screen
	local display = shop.Fit["Display_" .. kind]
	local facing = bay.Head.CFrame
	local origin = facing:PointToWorldSpace(V(0, -bay.Head.Position.Y, -0.3))
	local frame = facing.Rotation + origin
	local previous = display:FindFirstChild("Merchandise")
	if previous then
		previous:Destroy()
	end
	local oldZone = bay:FindFirstChild("ShopZone")
	if oldZone then
		oldZone:Destroy()
	end
	local zone = make("Part", bay, {
		Name = "ShopZone",
		Size = V(15.2, 10, 12.2),
		CFrame = frame * CFrame.new(0, 4.5, -2.8),
		Anchored = true,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	zone:SetAttribute("ShopDestination", destination)
	CS:AddTag(zone, "LobbyShopDisplayZone")

	for _, object in display:GetChildren() do
		local obsolete = object.Name ~= "Dash" and object.Name:sub(1, 4) ~= "Sign"
		if (products or destination == "DAILY") and obsolete then
			object:Destroy()
		end
	end
	if destination == "DAILY" then
		screen.CFrame = frame * CFrame.new(0, 6.62, -8.60)
		screen.Size = V(13.82, 9.55, 0.06)
		bay.Bezel.CFrame = frame * CFrame.new(0, 6.62, -8.805)
		bay.Bezel.Size = V(14.51, 10.25, 0.35)
		for _, x in { -4.8, 4.8 } do
			K.lpart(
				frame,
				display,
				"ScreenFoot",
				V(x - 0.23, 1.1, -8.99),
				V(x + 0.23, 1.86, -8.46),
				K.L.dark
			)
		end
	end
	local _, root = board(screen, false)
	if products then
		banner(root, Catalog.bundle(destination), false)
		local merch = K.model(display, "Merchandise")
		for _, item in products do
			mountSkin(merch, frame, item)
		end
	else
		shelfBoard(root, destination)
		if destination == "DAILY" then
			CS:AddTag(screen, "LobbyShopDailyDisplay")
		else
			local duplicate = display:FindFirstChild("KnifeCase")
			local otherKnife = 0
			for _, prop in display:GetChildren() do
				if prop.Name == "KnifeCase" then
					otherKnife += 1
				end
			end
			if duplicate and otherKnife > 1 then
				duplicate:Destroy()
			end
			local function centerCrate(crate, xOffset, zOffset)
				local cf = crate:GetBoundingBox()
				local target = frame:PointToWorldSpace(V(xOffset, cf.Y, zOffset))
				crate:PivotTo(crate:GetPivot() + Vector3.new(target.X - cf.X, 0, target.Z - cf.Z))
			end
			centerCrate(display.ApexCase, -3.7, -6.5)
			centerCrate(display.KnifeCase, 3.7, -6.5)
			for _, object in display:GetDescendants() do
				if object:IsA("Attachment") then
					object:Destroy()
				end
			end
		end
	end
end

local feature = shop.Fit.Feature
for _, prop in feature:GetChildren() do
	if
		prop.Name ~= "Screen"
		and prop.Name ~= "Hood"
		and prop.Name ~= "Bezel"
		and prop.Name ~= "Ring"
	then
		prop:Destroy()
	end
end
local screen = feature.Screen
screen.CanQuery = true
local _, card = board(screen, true)
banner(card, Catalog.bundle("Starter"), true)
for i = 1, 3 do
	local marker = panel(card, "Slide" .. i, 0.05 + (i - 1) * 0.033, 0.92, 0.022, 0.011, GOLD)
	marker.BackgroundTransparency = if i == 1 then 0 else 0.7
end
local prompt = screen:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	make("ProximityPrompt", screen, {
		Name = "ViewBundle",
		ActionText = "View bundle",
		ObjectText = "Starter Bundle",
		MaxActivationDistance = 13,
		RequiresLineOfSight = false,
	})
end
CS:AddTag(screen, "LobbyShopFeatureDisplay")

return "Installed Tempest-Strike, Ruin-Blighted, Cases, Daily Shop, and the rear Featured Bundles screen."
