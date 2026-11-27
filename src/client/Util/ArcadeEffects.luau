--!strict
-- Arcade skin line: the cabinet deck comes alive in first person. Each shot
-- presses and lights the next button and zips the pixel shot across the screen;
-- the ship bobs and the stars blink while idle; inspect runs a chase over the
-- buttons; a seated magazine flashes all three. Everything lives in the camera
-- clone (no connections, nothing outside the model), so unequip cleans it up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profiles = require(ReplicatedStorage.Shared.Config.Arcade)

local ArcadeEffects = {}

type Pulse = "Fire" | "Seat"

type Moving = {
	part: MeshPart,
	motor: Motor6D,
}

type Button = Moving & {
	color: Color3,
	material: Enum.Material,
	lit: number, -- seconds of light left
	hold: number, -- the light's full length, for the release ease
}

export type State = {
	profile: Profiles.Profile,
	scale: number,
	buttons: { Button },
	ship: Moving,
	shot: Moving,
	stars: MeshPart?,
	blip: MeshPart?,
	deckLight: MeshPart?,
	deckColor: Color3,
	flash: Color3, -- the colour the deck light shows while `flashLeft` runs
	flashLeft: number,
	starsTransparency: number,
	blipTransparency: number,
	nextButton: number,
	shotT: number, -- 0..1 while a shot crosses the screen, else 1
	clock: number,
}

local LIT_TINT = Color3.new(1, 1, 1)

-- Swap a part's installer weld for a Motor6D so it can move with the gun.
local function moving(model: Model, name: string): Moving?
	local part = model:FindFirstChild(name)
	if not part or not part:IsA("MeshPart") then
		return nil
	end
	local weld = part:FindFirstChild("SkinCosmeticWeld")
	if not weld or not weld:IsA("Weld") or not weld.Part0 or weld.Part1 ~= part then
		return nil
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "ArcadeMotion"
	motor.Part0 = weld.Part0
	motor.Part1 = part
	motor.C0 = weld.C0
	motor.C1 = weld.C1
	weld:Destroy()
	motor.Parent = part
	return { part = part, motor = motor }
end

local function meshPart(model: Model, name: string?): MeshPart?
	local part = if name then model:FindFirstChild(name) else nil
	return if part and part:IsA("MeshPart") then part else nil
end

function ArcadeEffects.new(model: Model, scale: number, gunId: string): State?
	local profile = Profiles[gunId]
	if not profile then
		return nil
	end
	local buttons: { Button } = {}
	for _, name in profile.buttons do
		local m = moving(model, name)
		if not m then
			return nil
		end
		table.insert(buttons, {
			part = m.part,
			motor = m.motor,
			color = m.part.Color,
			material = m.part.Material,
			lit = 0,
			hold = 1,
		})
	end
	local ship = moving(model, profile.ship)
	local shot = moving(model, profile.shot)
	if not ship or not shot then
		return nil
	end
	local stars = meshPart(model, profile.stars)
	local blip = meshPart(model, profile.blip)
	local deckLight = meshPart(model, profile.deckLight)
	return {
		profile = profile,
		scale = scale,
		buttons = buttons,
		ship = ship,
		shot = shot,
		stars = stars,
		blip = blip,
		deckLight = deckLight,
		deckColor = if deckLight then deckLight.Color else Color3.new(),
		flash = Color3.new(),
		flashLeft = 0,
		starsTransparency = if stars then stars.Transparency else 0,
		blipTransparency = if blip then blip.Transparency else 0,
		nextButton = 1,
		shotT = 1,
		clock = 0,
	}
end

function ArcadeEffects.pulse(state: State, kind: Pulse)
	local profile = state.profile
	if kind == "Fire" then
		local button = state.buttons[state.nextButton]
		button.lit = profile.fireTime
		button.hold = profile.fireTime
		state.nextButton = state.nextButton % #state.buttons + 1
		state.shotT = 0
		state.flash = button.color
		state.flashLeft = profile.fireTime
	else
		for _, button in state.buttons do
			button.lit = profile.seatTime
			button.hold = profile.seatTime
		end
		state.flash = LIT_TINT
		state.flashLeft = profile.seatTime
	end
end

local function light(button: Button, amount: number, depth: number)
	if amount > 0 then
		button.part.Material = Enum.Material.Neon
		button.part.Color = button.color:Lerp(LIT_TINT, 0.12)
		button.motor.Transform = CFrame.new(0, 0, -depth * amount)
	else
		button.part.Material = button.material
		button.part.Color = button.color
		button.motor.Transform = CFrame.identity
	end
end

local function blink(part: MeshPart?, base: number, on: boolean)
	if part then
		part.Transparency = if on then base else 1
	end
end

function ArcadeEffects.step(state: State, dt: number, inspect: number?, visible: boolean)
	local profile = state.profile
	local scale = state.scale
	local pixel = profile.pixel * scale
	state.clock += dt
	local clock = state.clock

	-- buttons: an inspect chase, else whatever the shots and seats lit
	local chase = if visible and inspect
		then math.floor(clock / profile.chaseStep) % #state.buttons + 1
		else nil
	for i, button in state.buttons do
		if chase then
			button.lit = 0
			light(button, if i == chase then 0.5 else 0, profile.pressDepth * scale)
		elseif button.lit > 0 and visible then
			button.lit = math.max(0, button.lit - dt)
			-- full press for most of the light, then a quick release
			local t = button.lit / button.hold
			light(button, math.clamp(t / 0.4, 0, 1), profile.pressDepth * scale)
		else
			button.lit = 0
			light(button, 0, 0)
		end
	end

	-- screen: pixel-stepped motion only, like a real low-res display
	if state.shotT < 1 then
		state.shotT = math.min(1, state.shotT + dt / profile.fireTime)
	end
	local step = math.floor(state.shotT * profile.shotTravel)
	state.shot.motor.Transform = if state.shotT < 1
		then CFrame.new(-step * pixel, 0, 0)
		else CFrame.identity

	local bob = math.floor(clock / profile.shipBob) % 2
	local cruise = if visible and inspect
		then math.floor(clock / (profile.chaseStep * 2)) % 6
		else 0
	state.ship.motor.Transform = CFrame.new(-cruise * pixel, bob * pixel, 0)

	if state.deckLight then
		state.flashLeft = math.max(0, state.flashLeft - dt)
		local chaseColor = if chase then state.buttons[chase].color else nil
		state.deckLight.Color = chaseColor
			or (if state.flashLeft > 0 and visible then state.flash else state.deckColor)
	end

	local phase = math.floor(clock / profile.starBlink) % 2 == 0
	blink(state.stars, state.starsTransparency, phase)
	blink(state.blip, state.blipTransparency, not phase)
end

return ArcadeEffects
