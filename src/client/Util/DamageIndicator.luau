--!strict
-- The damage direction indicator on the combat HUD (numbers in
-- Config/DamageIndicator; HudController owns when it fires). A red arc with
-- an arrowhead sits on a circle round the crosshair, on the side the hit came
-- from. It follows that shooter's position every frame, so it turns as you
-- turn and move, and its size follows how far away the shot came from
-- (closer: bigger). One arc per shooter, up to a small pool.
-- Animated by hand from step(dt) (no tweens), so an arc always ends hidden
-- and a new hit just restarts it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DamageIndicator)

local DamageIndicator = {}

type Arc = {
	root: Frame,
	scale: UIScale,
	image: ImageLabel,
	source: Vector3,
	age: number,
	active: boolean,
	popFrom: number, -- this pop's start scale
	fadeIn: boolean, -- false on a renewed arc: it is already showing
	size: number, -- the distance scale, eased
	sized: boolean, -- `size` has been set once for this arc
}

local arcs: { Arc } = {}
local studio = RunService:IsStudio()

local function newArc(parent: Instance): Arc
	local art = Config.ART
	local root = Instance.new("Frame")
	root.Name = "DamageArc"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.ZIndex = 2
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0)
	-- The image's top edge: the arrowhead's tip side. Its band's centre line
	-- lands `radius` from the root (the crosshair).
	image.Position = UDim2.fromOffset(0, -(art.radius + art.thick / 2 + art.triHeight + art.margin))
	image.Size = UDim2.fromOffset(art.width, art.height)
	image.BackgroundTransparency = 1
	image.Image = Config.IMAGE
	image.ImageColor3 = Config.COLOR
	image.ImageTransparency = 1
	image.ZIndex = 2
	image.Parent = root
	return {
		root = root,
		scale = scale,
		image = image,
		source = Vector3.zero,
		age = 0,
		active = false,
		popFrom = 1,
		fadeIn = true,
		size = 1,
		sized = false,
	}
end

function DamageIndicator.build(gui: ScreenGui)
	for i = 1, Config.POOL do
		arcs[i] = newArc(gui)
	end
end

-- A hit from `source` (world position of whoever dealt it).
function DamageIndicator.hit(source: Vector3)
	if source ~= source then
		return
	end
	local pick: Arc? = nil
	for _, arc in arcs do
		if arc.active and (arc.source - source).Magnitude <= Config.SAME_SOURCE then
			pick = arc
			break
		end
	end
	if pick then
		-- The same shooter again: it follows them and pulses.
		local fading = pick.age > Config.TIME.pop + Config.TIME.hold
		pick.source = source
		pick.age = 0
		pick.popFrom = Config.POP.again
		pick.fadeIn = fading
		return
	end
	for _, arc in arcs do
		if not arc.active then
			pick = arc
			break
		elseif not pick or arc.age > pick.age then
			pick = arc
		end
	end
	if pick then
		pick.source = source
		pick.age = 0
		pick.active = true
		pick.popFrom = Config.POP.from
		pick.fadeIn = true
		pick.sized = false
		pick.root.Visible = true
	end
end

local function stepArc(arc: Arc, dt: number, cam: Camera, px: number)
	local t = Config.TIME
	arc.age += dt
	local out = (arc.age - t.pop - t.hold) / t.fade
	if out >= 1 then
		arc.active = false
		arc.root.Visible = false
		arc.image.ImageTransparency = 1
		return
	end
	-- Where the shot came from, round the crosshair (0 = ahead, at the top).
	local to = arc.source - cam.CFrame.Position
	local flat = to * Vector3.new(1, 0, 1)
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.1 and look.Magnitude > 0.1 then
		local f, l = flat.Unit, look.Unit
		-- Clockwise from ahead (GUI rotation is clockwise): a shooter on your
		-- right puts the arc on the right. The old indicator had this sign
		-- flipped, so it showed the mirror side (found 2026-11-15).
		arc.root.Rotation = math.deg(math.atan2(f:Cross(l).Y, f:Dot(l)))
	end
	-- Its size follows the distance, live.
	local d = Config.DISTANCE
	local k = math.clamp((to.Magnitude - d.near) / (d.far - d.near), 0, 1)
	local goal = d.nearScale + (d.farScale - d.nearScale) * k
	if arc.sized then
		arc.size += (goal - arc.size) * (1 - math.exp(-d.rate * dt))
	else
		arc.size = goal
		arc.sized = true
	end
	-- The pop: big, then shrinking onto its size (a cubic ease-out).
	local inv = 1 - math.clamp(arc.age / t.pop, 0, 1)
	arc.scale.Scale = px * arc.size * (1 + (arc.popFrom - 1) * inv * inv * inv)
	local alpha = 1
	if arc.fadeIn then
		alpha = math.clamp(arc.age / t.fadeIn, 0, 1)
	end
	if out > 0 then
		alpha *= 1 - out * out
	end
	arc.image.ImageTransparency = 1 - (1 - Config.TRANSPARENCY) * alpha
end

function DamageIndicator.step(frameDt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local dt = frameDt
	if studio then
		-- Studio only: Workspace VfxTimeScale slows or freezes it (captures).
		local scale = Workspace:GetAttribute("VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	local s = Config.SCREEN
	local px = math.clamp(cam.ViewportSize.Y / s.designHeight, s.min, s.max)
	for _, arc in arcs do
		if arc.active then
			stepArc(arc, dt, cam, px)
		end
	end
end

return DamageIndicator
