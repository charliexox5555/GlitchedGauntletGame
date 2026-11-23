--!strict
-- Animates the existing Studio offer card. Only its visible Home session owns input and time.

local RS = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local UiMotion = require(RS.Shared.UiMotion)
local C = require(RS.Shared.Config.ShopFx).carousel

local OfferCarousel = {}

function OfferCarousel.new(
	card: GuiButton,
	count: number,
	draw: (number) -> (),
	activate: (number) -> (),
	blocked: () -> boolean
)
	local dots = card:WaitForChild("Dots") :: Frame
	local selected = dots:WaitForChild("Dot1") :: Frame
	local unselected = dots:WaitForChild("Dot2") :: Frame
	local onSize, offSize = selected.Size, unselected.Size
	local onAlpha, offAlpha = selected.BackgroundTransparency, unselected.BackgroundTransparency
	local markers: { Frame } = {}
	for _, dot in dots:GetChildren() do
		if dot:IsA("Frame") then
			table.insert(markers, dot)
		end
	end
	table.sort(markers, function(a, b)
		return a.Name < b.Name
	end)
	dots.Visible = count > 1

	local art = card:WaitForChild("Art") :: ImageLabel
	local hero = card:WaitForChild("Hero") :: ImageLabel
	local title = card:WaitForChild("Title") :: TextLabel
	local sub = card:WaitForChild("Sub") :: TextLabel
	local price = card:WaitForChild("Price") :: Frame
	local moving: { GuiObject } = { hero, title, sub, price }
	local homes: { UDim2 } = {}
	for i, object in moving do
		homes[i] = object.Position
	end
	local artAlpha, heroAlpha = art.ImageTransparency, hero.ImageTransparency
	local titleAlpha, subAlpha = title.TextTransparency, sub.TextTransparency
	local index, elapsed = 1, 0
	local connections: { RBXScriptConnection } = {}
	local tweens: { Tween } = {}
	local touch: InputObject? = nil
	local origin = Vector2.zero

	local function resetMotion()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		for i, object in moving do
			object.Position = homes[i]
		end
		art.ImageTransparency, hero.ImageTransparency = artAlpha, heroAlpha
		title.TextTransparency, sub.TextTransparency = titleAlpha, subAlpha
	end

	local function change(to: number, direction: number?)
		elapsed = 0
		resetMotion()
		index = to
		draw(index)
		for i, dot in markers do
			dot.Visible = i <= count
			dot.Size = if i == index then onSize else offSize
			dot.BackgroundTransparency = if i == index then onAlpha else offAlpha
		end
		if not direction then
			return
		end
		if not UiMotion.reduced() then
			for i, object in moving do
				object.Position = homes[i] + UDim2.fromOffset(C.slidePx * direction, 0)
				table.insert(tweens, UiMotion.tween(object, C.transition, { Position = homes[i] }))
			end
		end
		art.ImageTransparency, hero.ImageTransparency = C.startTransparency, C.startTransparency
		title.TextTransparency, sub.TextTransparency = C.startTransparency, C.startTransparency
		table.insert(tweens, UiMotion.tween(art, C.transition, { ImageTransparency = artAlpha }))
		table.insert(tweens, UiMotion.tween(hero, C.transition, { ImageTransparency = heroAlpha }))
		table.insert(tweens, UiMotion.tween(title, C.transition, { TextTransparency = titleAlpha }))
		table.insert(tweens, UiMotion.tween(sub, C.transition, { TextTransparency = subAlpha }))
	end

	local function step(direction: number)
		if count > 1 then
			change((index - 1 + direction) % count + 1, direction)
		end
	end

	local function inside(object: GuiObject, point: Vector2): boolean
		local lo = object.AbsolutePosition
		local hi = lo + object.AbsoluteSize
		return point.X >= lo.X and point.X <= hi.X and point.Y >= lo.Y and point.Y <= hi.Y
	end

	local function click(point: Vector2?)
		if blocked() then
			return
		end
		if point and count > 1 then
			local nearest, distance = nil, math.huge
			for i = 1, math.min(count, #markers) do
				local dot = markers[i]
				local center = dot.AbsolutePosition + dot.AbsoluteSize / 2
				if math.abs(point.Y - center.Y) <= C.dotHitYPx / 2 then
					local dx = math.abs(point.X - center.X)
					if dx <= C.dotHitYPx / 2 and dx < distance then
						nearest, distance = i, dx
					end
				end
			end
			if nearest then
				if nearest ~= index then
					change(nearest, if nearest > index then 1 else -1)
				end
				return
			end
		end
		activate(index)
	end

	return {
		refresh = function()
			draw(index)
		end,
		start = function()
			if #connections > 0 or count == 0 then
				return
			end
			change(index)
			table.insert(
				connections,
				card.Activated:Connect(function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						click(Vector2.new(input.Position.X, input.Position.Y))
					elseif input.UserInputType ~= Enum.UserInputType.Touch then
						click(nil)
					end
				end)
			)
			table.insert(
				connections,
				card.InputBegan:Connect(function(input: InputObject)
					if
						input.UserInputType == Enum.UserInputType.Touch
						and not touch
						and not blocked()
					then
						touch = input
						origin = Vector2.new(input.Position.X, input.Position.Y)
					end
				end)
			)
			table.insert(
				connections,
				Input.InputEnded:Connect(function(input: InputObject)
					if input ~= touch then
						return
					end
					touch = nil
					if blocked() or input.UserInputState == Enum.UserInputState.Cancel then
						return
					end
					local point = Vector2.new(input.Position.X, input.Position.Y)
					local delta = point - origin
					if
						math.abs(delta.X) >= C.swipePx
						and math.abs(delta.X) > math.abs(delta.Y) * C.swipeRatio
					then
						step(if delta.X < 0 then 1 else -1)
					elseif delta.Magnitude <= C.tapSlopPx and inside(card, point) then
						click(point)
					end
				end)
			)
			table.insert(
				connections,
				RunService.Heartbeat:Connect(function(dt: number)
					if
						blocked()
						or touch
						or (
							Input.MouseEnabled
							and inside(card, Input:GetMouseLocation() - GuiService:GetGuiInset())
						)
					then
						elapsed = 0
					elseif count > 1 then
						elapsed += dt
						if elapsed >= C.interval then
							step(1)
						end
					end
				end)
			)
		end,
		stop = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			touch = nil
			resetMotion()
		end,
	}
end

return OfferCarousel
