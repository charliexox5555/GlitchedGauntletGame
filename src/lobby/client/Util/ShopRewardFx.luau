--!strict
-- Temporary effects for the Studio RewardPanel. The panel and its controls stay in Studio.

local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS.Shared.Config.ShopFx).reward
local UiMotion = require(RS.Shared.UiMotion)
local UiSfx = require(RS.Shared.UiSfx)

local ShopRewardFx = {}
local rng = Random.new()
local CENTER = Vector2.new(0.5, 0.5)

export type Item = { image: string, coins: boolean? }
export type Reveal = {
	name: string,
	image: string?,
	tier: string?,
	color: Color3,
	items: { Item }?,
	coins: number?,
}
export type Session = {
	destroy: () -> (),
	collect: (GuiObject, GuiObject?) -> (),
}

local function center(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

local function layer(parent: GuiObject, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

local function copyArt(image: string, parent: GuiObject, z: number): ImageLabel
	local picture = Instance.new("ImageLabel")
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = CENTER
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Image = image
	picture.ZIndex = z
	picture.Parent = parent
	return picture
end

function ShopRewardFx.play(panel: Frame, reward: Reveal, formatCoins: (number) -> string): Session
	local picture = panel:WaitForChild("Art") :: ImageLabel
	local name = panel:WaitForChild("ItemName") :: TextLabel
	local collect = panel:WaitForChild("Collect") :: GuiButton
	local scale = collect:FindFirstChild("Pop") :: UIScale?
	local effects = layer(panel, "RewardEffects", picture.ZIndex - 1)
	local row = layer(panel, "RewardItemEffects", picture.ZIndex + 1)
	local revealed: { { picture: ImageLabel, coins: boolean? } } = {}
	local running, ready = true, false
	local shownAt, playedTicks = 0, 0
	local wheel: Frame? = nil
	local heartbeat: RBXScriptConnection? = nil
	local whoosh, stinger, detail: Sound? = nil, nil, nil
	local pending: { thread } = {}
	local revealTween: Tween? = nil

	local function schedule(seconds: number, callback: () -> ())
		table.insert(
			pending,
			task.delay(seconds, function()
				if running then
					callback()
				end
			end)
		)
	end
	local function stopSounds()
		for _, sound in { whoosh, stinger, detail } do
			sound:Stop()
		end
		whoosh, stinger, detail = nil, nil, nil
	end
	local function tickSound(cue: string)
		if detail then
			detail:Stop()
		end
		detail = UiSfx.play(cue)
	end

	picture.Image = reward.image or ""
	picture.Visible = false
	name.Visible = false
	name.Text = if reward.coins then string.format(reward.name, formatCoins(0)) else reward.name
	if scale then
		scale.Scale = 1
	end

	local function radiate()
		local relative = picture.Position
			+ UDim2.new(
				picture.Size.X.Scale * (0.5 - picture.AnchorPoint.X),
				picture.Size.X.Offset * (0.5 - picture.AnchorPoint.X),
				picture.Size.Y.Scale * (0.5 - picture.AnchorPoint.Y),
				picture.Size.Y.Offset * (0.5 - picture.AnchorPoint.Y)
			)
		local flash = Instance.new("Frame")
		flash.AnchorPoint = CENTER
		flash.Position = relative
		flash.Size = UDim2.fromScale(1 - C.flashInset * 2, 1 - C.flashInset * 2)
		flash.BackgroundColor3 = reward.color
		flash.BackgroundTransparency = C.flashTransparency
		flash.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = flash
		flash.Parent = effects
		UiMotion.tween(flash, C.flashTime, { BackgroundTransparency = 1 })
		Debris:AddItem(flash, C.flashTime)
		if UiMotion.reduced() then
			return
		end
		local rays = layer(effects, "Rays", effects.ZIndex)
		rays.AnchorPoint = CENTER
		rays.Position = relative
		rays.Size = UDim2.fromOffset(C.rayLength * 2, C.rayLength * 2)
		wheel = rays
		for i = 1, C.rays do
			local angle = (i - 1) * math.pi * 2 / C.rays
			local ray = Instance.new("Frame")
			ray.AnchorPoint = CENTER
			ray.Position = UDim2.fromScale(0.5 + math.sin(angle) / 4, 0.5 - math.cos(angle) / 4)
			ray.Size = UDim2.fromOffset(C.rayWidth, C.rayLength)
			ray.Rotation = math.deg(angle)
			ray.BorderSizePixel = 0
			ray.BackgroundColor3 = reward.color
			ray.BackgroundTransparency = C.rayTransparency
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new(1, 0)
			fade.Parent = ray
			ray.Parent = rays
		end
		for i = 1, C.sparkles do
			local angle = (i - 1) * math.pi * 2 / C.sparkles
			local radius = rng:NextNumber(C.sparkleRadiusMin, C.sparkleRadiusMax)
			local size = rng:NextInteger(C.sparkleSizeMin, C.sparkleSizeMax)
			local sparkle = Instance.new("Frame")
			sparkle.AnchorPoint = CENTER
			sparkle.Position = relative
			sparkle.Size = UDim2.fromOffset(size, size)
			sparkle.BorderSizePixel = 0
			sparkle.Rotation = 45
			sparkle.BackgroundColor3 = reward.color
			sparkle.Parent = effects
			local seconds = rng:NextNumber(C.sparkleTimeMin, C.sparkleTimeMax)
			UiMotion.tween(sparkle, seconds, {
				Position = relative
					+ UDim2.fromOffset(math.cos(angle) * radius, math.sin(angle) * radius),
				Rotation = sparkle.Rotation + rng:NextNumber(-C.sparkleRotation, C.sparkleRotation),
				BackgroundTransparency = 1,
			})
			Debris:AddItem(sparkle, seconds)
		end
	end

	local function fanItems()
		local items = reward.items
		if not items or #items == 0 then
			return
		end
		local width = math.min(C.itemMaxWidth, (C.rowWidth - C.rowGap * (#items - 1)) / #items)
		local step = width + C.rowGap
		for i, item in items do
			schedule((if reward.coins then C.countTime else 0) + (i - 1) * C.itemStagger, function()
				local tile = copyArt(item.image, row, row.ZIndex)
				table.insert(revealed, { picture = tile, coins = item.coins })
				local to = UDim2.fromScale(0.5 + (i - (#items + 1) / 2) * step, C.rowY)
				tile.ImageTransparency = 1
				tile.Position = if UiMotion.reduced() then to else picture.Position
				tile.Size =
					UDim2.fromScale(width * C.itemStartScale, C.itemHeight * C.itemStartScale)
				UiMotion.tween(tile, C.itemTime, {
					Position = to,
					Size = UDim2.fromScale(width, C.itemHeight),
					ImageTransparency = 0,
				})
				tickSound(if i == #items then "RewardFinalHit" else "RewardItemTick")
			end)
		end
	end

	local startAlpha = picture.ImageTransparency
	whoosh = UiSfx.play("RewardWhoosh")
	schedule(C.build, function()
		shownAt = os.clock()
		ready = true
		radiate()
		picture.ImageTransparency = 1
		picture.Visible = true
		name.Visible = true
		local tier = reward.tier
		stinger = UiSfx.play(
			if tier == "Legendary" or tier == "Exclusive"
				then "RewardLegendary"
				elseif tier == "Epic" then "RewardEpic"
				elseif tier == "Rare" then "RewardRare"
				else "RewardCommon"
		)
		revealTween = UiMotion.tween(picture, C.revealFade, { ImageTransparency = startAlpha })
		fanItems()
		heartbeat = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - shownAt
			local reduce = UiMotion.reduced()
			if wheel then
				wheel.Visible = not reduce
				wheel.Rotation = (elapsed * C.rayTurn) % 360
			end
			if scale then
				scale.Scale = if reduce
					then 1
					else 1 + (C.pulseScale - 1) * (1 - math.cos(
						elapsed * math.pi / C.pulseTime
					)) / 2
			end
			local amount = reward.coins
			if amount and playedTicks < C.countTicks then
				local alpha = math.clamp(elapsed / C.countTime, 0, 1)
				name.Text = string.format(
					reward.name,
					formatCoins(math.round(amount * (1 - (1 - alpha) ^ 2)))
				)
				local beat = math.floor(alpha * C.countTicks)
				if beat > playedTicks then
					playedTicks = beat
					tickSound("RewardCoinTick")
				end
			end
		end)
	end)

	return {
		destroy = function()
			running = false
			for _, taskThread in pending do
				if coroutine.status(taskThread) == "suspended" then
					task.cancel(taskThread)
				end
			end
			if heartbeat then
				heartbeat:Disconnect()
			end
			stopSounds()
			if revealTween then
				revealTween:Cancel()
			end
			effects:Destroy()
			row:Destroy()
			name.Visible, picture.Visible = true, true
			picture.ImageTransparency = startAlpha
			if scale then
				scale.Scale = 1
			end
		end,
		collect = function(canvas: GuiObject, coinCounter: GuiObject?)
			stopSounds()
			UiSfx.cue("RewardCollect")
			if not ready or UiMotion.reduced() then
				return
			end
			if #revealed == 0 and reward.image then
				table.insert(revealed, { picture = picture, coins = reward.coins ~= nil })
			end
			local flight = layer(canvas, "CollectEffects", panel.ZIndex)
			local bounds, top = canvas.AbsoluteSize, canvas.AbsolutePosition
			if bounds.X <= 0 or bounds.Y <= 0 then
				flight:Destroy()
				return
			end
			for _, item in revealed do
				local source = item.picture
				local copy = copyArt(source.Image, flight, flight.ZIndex)
				local p, size = center(source) - top, source.AbsoluteSize
				copy.Position = UDim2.fromScale(p.X / bounds.X, p.Y / bounds.Y)
				copy.Size = UDim2.fromScale(size.X / bounds.X, size.Y / bounds.Y)
				local goal = C.collectTarget
				if item.coins and coinCounter then
					local target = center(coinCounter) - top
					goal = Vector2.new(target.X / bounds.X, target.Y / bounds.Y)
				end
				UiMotion.out(copy, {
					Position = UDim2.fromScale(goal.X, goal.Y),
					Size = UDim2.fromScale(
						size.X / bounds.X * C.collectScale,
						size.Y / bounds.Y * C.collectScale
					),
					ImageTransparency = 1,
				}, C.collectTime)
			end
			Debris:AddItem(flight, C.collectTime)
		end,
	}
end

return ShopRewardFx
