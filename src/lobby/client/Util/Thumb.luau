--!strict
-- Item art for shop cells (vault/02 Art/UI Lobby Overhaul.md → Shop): RIVALS'
-- shop shows the real items in every cell, ours showed flat colour squares
-- with words ("looks AI" = missing art). Thumb.item(parent, item) puts the
-- item's picture in a cell:
--   * a skin: a live 3D render of that skinned gun (Shared/Locker.skinModel),
--     side-on, framed to fit, the line's emblem if the model isn't synced;
--   * coins: the coin art;
--   * anything else: nothing (the cell keeps its words).
-- The render is static (one ViewportFrame, no per-frame cost).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locker = require(ReplicatedStorage.Shared.Locker)
local ItemStage = require(script.Parent.ItemStage)

local Thumb = {}

local COIN = "rbxassetid://126250416946442"

export type Item = { kind: string, gun: string?, line: string?, amount: number? }

local function image(parent: GuiObject, id: string, inset: number, color: Color3?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = "Art"
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.44)
	i.Size = UDim2.fromScale(inset, inset)
	i.BackgroundTransparency = 1
	i.Image = id
	i.ImageColor3 = color or Color3.new(1, 1, 1)
	i.ScaleType = Enum.ScaleType.Fit
	i.ZIndex = parent.ZIndex + 1
	i.Parent = parent
	return i
end

-- A side view of `model`, fitted to the frame's width.
function Thumb.model(parent: GuiObject, model: Model): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Art"
	vf.AnchorPoint = Vector2.new(0.5, 0.5)
	vf.Position = UDim2.fromScale(0.5, 0.42)
	vf.Size = UDim2.fromScale(1, 0.78)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(205, 205, 212)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.4)
	vf.ZIndex = parent.ZIndex + 1
	local m = ItemStage.presentable(model)
	local _, size = m:GetBoundingBox()
	m.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 20
	-- the long axis is Z (ItemStage.presentable): look from the side (+X)
	-- frame the gun's length across the cell (a little tighter than its box)
	local reach = math.max(size.Z * 0.42, size.Y * 0.75)
	local dist = reach / math.tan(math.rad(cam.FieldOfView / 2))
	cam.CFrame = CFrame.lookAt(Vector3.new(dist, size.Y * 0.08, 0), Vector3.zero)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf
end

function Thumb.item(parent: GuiObject, item: Item)
	local old = parent:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	if item.kind == "Skin" and item.gun and item.line then
		local m = Locker.skinModel(item.gun, item.line)
		if m then
			Thumb.model(parent, m)
		elseif Locker.EMBLEMS[item.line] then
			image(parent, Locker.EMBLEMS[item.line], 0.5, Locker.COLORS[item.line])
		end
	elseif item.kind == "Coins" then
		image(parent, COIN, 0.55)
	end
	-- the cell's words stay readable over the art
	local art = parent:FindFirstChild("Art")
	if art and art:IsA("GuiObject") then
		for _, c in parent:GetChildren() do
			if c:IsA("TextLabel") then
				c.ZIndex = math.max(c.ZIndex, art.ZIndex + 1)
				-- an outline on the item's name only (tiny kind words go muddy)
				if c.Name == "Name" and not c:FindFirstChildOfClass("UIStroke") then
					local s = Instance.new("UIStroke")
					s.Color = Color3.new(0, 0, 0)
					s.Transparency = 0.45
					s.Thickness = 1.5
					s.Parent = c
				end
			end
		end
	end
end

return Thumb
