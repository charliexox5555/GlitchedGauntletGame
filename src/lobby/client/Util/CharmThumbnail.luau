--!strict
-- Renders a stationary upright 3/4 3D thumbnail of a charm Model inside a
-- ViewportFrame parented to a UI slot (reused by LockerV3 and BattlePass).

local CharmsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Charms)

local CharmThumbnail = {}

function CharmThumbnail.mount(parent: GuiObject, charmId: string, dimmed: boolean?): ViewportFrame?
	local old = parent:FindFirstChild("CharmViewport")
	if old then
		old:Destroy()
	end
	local src = CharmsConfig.model(charmId)
	if not src then
		return nil
	end
	local vf = Instance.new("ViewportFrame")
	vf.Name = "CharmViewport"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(165, 175, 210)
	vf.LightColor = Color3.fromRGB(255, 250, 242)
	vf.LightDirection = Vector3.new(-0.5, -1, -0.75)
	vf.ImageTransparency = if dimmed then 0.48 else 0
	vf.ZIndex = parent.ZIndex + 1

	local m = src:Clone()
	m.PrimaryPart = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m:PivotTo(CFrame.new())
	local boxCf, boxSize = m:GetBoundingBox()
	local maxDim = math.max(boxSize.X, boxSize.Y, boxSize.Z, 0.2)
	m:PivotTo(CFrame.Angles(0, math.pi + math.rad(22), 0) * CFrame.new(-boxCf.Position))
	m.Parent = vf

	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local dist = (maxDim * 0.55) / math.tan(math.rad(14)) * 1.28
	cam.CFrame = CFrame.lookAt(Vector3.new(0, maxDim * 0.06, dist), Vector3.zero)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf
end

function CharmThumbnail.clear(parent: GuiObject)
	local old = parent:FindFirstChild("CharmViewport")
	if old then
		old:Destroy()
	end
end

return CharmThumbnail
