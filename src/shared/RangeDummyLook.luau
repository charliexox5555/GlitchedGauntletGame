--!strict
-- The range training bots' look (vault/01 Design/Range v5.md, numbers in Config/RangeDummies). Owner 2026-11-25,
-- after the glowing gold/blue pass: "glowing way too much. I want it to just be the regular roblox r15 blocky
-- character. And the whole thing should be the same blue." So: the bot's own blocky R15 body and head (no face:
-- owner 2026-11-26), clothing and accessories off, every body part one matte blue. Applied by the server (LobbyServer
-- Range/RangeBots) so every client sees the same bot.
--
-- Limbs are unanchored so the bot's Animator (its idle, the strafers' run) and the client's hit reactions
-- (Controllers/DummyLifeController) can move them; the root stays as the place left it.

local RangeDummies = require(script.Parent.Config.RangeDummies)

local RangeDummyLook = {}

-- The colour a body part wears (nil: leave it alone).
function RangeDummyLook.colourOf(part: BasePart): Color3?
	if part.Name == "HumanoidRootPart" then
		return nil
	end
	return RangeDummies.COLOR
end

local function strip(model: Model)
	for _, d in model:GetDescendants() do
		if
			d:IsA("Clothing")
			or d:IsA("ShirtGraphic")
			or d:IsA("Accessory")
			or d:IsA("BodyColors")
			or d:IsA("SurfaceAppearance")
		then
			d:Destroy()
		end
	end
end

-- No face (owner 2026-11-26): the head's own texture carries it on these rigs, plus any face decal or face rig.
local function blankHead(head: BasePart)
	if head:IsA("MeshPart") then
		head.TextureID = ""
	end
	for _, d in head:GetChildren() do
		if d:IsA("Decal") or d:IsA("FaceControls") then
			d:Destroy()
		end
	end
end

-- Dresses a training bot. Safe to call again (a respawned copy).
function RangeDummyLook.apply(model: Model)
	strip(model)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local colour = RangeDummyLook.colourOf(d)
			if colour then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = colour
				d.Anchored = false
			end
			if d.Name == "Head" then
				blankHead(d)
			end
		end
	end
end

return RangeDummyLook
