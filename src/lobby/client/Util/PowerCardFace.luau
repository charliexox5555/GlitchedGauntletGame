--!strict
-- The 3D power card (ReplicatedStorage.LockerV3Stage.PowerCard: a thin card with the draft card's face on a
-- SurfaceGui, the logo on the back and a coloured edge; tools/studio/BuildLockerV3.luau). Shared by the Locker
-- (Controllers/LockerV3Controller) and the power case opening (Util/CaseOpening).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mods = require(ReplicatedStorage.Shared.Mods)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local PowerCardFace = {}

local WHITE = Color3.new(1, 1, 1)

-- A fresh copy of the card model, or nil when the stage isn't in this place.
function PowerCardFace.clone(): Model?
	local stage = ReplicatedStorage:FindFirstChild("LockerV3Stage")
	local src = stage and stage:FindFirstChild("PowerCard")
	if src and src:IsA("Model") then
		return src:Clone()
	end
	return nil
end

-- The card's front frame (Face.Front.Card) and its shine sweep, when present.
function PowerCardFace.front(card: Model): (Frame?, UIGradient?)
	local face = card:FindFirstChild("Face")
	local surface = face and face:FindFirstChild("Front")
	local f = surface and surface:FindFirstChild("Card")
	local shine = f and f:FindFirstChild("Shine")
	local sweep = shine and shine:FindFirstChild("Sweep")
	return if f and f:IsA("Frame") then f else nil,
		if sweep and sweep:IsA("UIGradient") then sweep else nil
end

local function setText(parent: Instance, name: string, text: string)
	local l = parent:FindFirstChild(name)
	if l and l:IsA("TextLabel") then
		l.Text = text
	end
end

-- Fills the card for power `id`; `foot` is the bottom-right word ("" for none, "POWER PACK", "NEW").
function PowerCardFace.fill(card: Model, id: string, foot: string)
	local def = Mods.def(id)
	local f = PowerCardFace.front(card)
	if not (def and f) then
		return
	end
	local roleColor = Theme.ROLE[def.role] or WHITE
	local art = f:FindFirstChild("Art")
	if art and art:IsA("ImageLabel") then
		art.Image = Theme.CARD_ART[id] or ""
	end
	local band = f:FindFirstChild("Band")
	if band and band:IsA("Frame") then
		band.BackgroundColor3 = roleColor
	end
	setText(f, "Title", string.upper(def.name))
	setText(f, "Role", string.upper(def.role))
	setText(f, "Note", ((def.levels.L1 :: any).note or "") .. ".")
	setText(f, "Level", foot)
	local back = card:FindFirstChild("Back", true)
	local backCard = back and back:FindFirstChild("Card")
	local backBand = backCard and backCard:FindFirstChild("Band")
	if backBand and backBand:IsA("Frame") then
		backBand.BackgroundColor3 = roleColor
	end
	local edge = card:FindFirstChild("Edge")
	if edge and edge:IsA("BasePart") then
		edge.Color = roleColor
	end
end

-- A thumbnail of power `id` on `img`: the middle of its card art (Config/Theme CARD_ART, 760 x 600), where the
-- power's picture sits (owner 2026-11-26: the icons in the case should look better). The crop takes the label's
-- own shape around that middle square, so a wide or tall label never stretches the picture (owner 2026-11-27:
-- "the images in the collect screen at the end are stretched"). `id` nil clears it back to a plain image (the same
-- label shows skins too).
local ART_SIZE = Vector2.new(760, 600)
local THUMB_OFFSET, THUMB_SIZE = Vector2.new(230, 110), Vector2.new(300, 300)
function PowerCardFace.thumb(img: ImageLabel, id: string?)
	if id then
		img.Image = Theme.CARD_ART[id] or ""
		local size = img.AbsoluteSize
		if size.X < 2 or size.Y < 2 then
			-- not laid out yet: keep the square and crop it to the label
			img.ImageRectOffset = THUMB_OFFSET
			img.ImageRectSize = THUMB_SIZE
			img.ScaleType = Enum.ScaleType.Crop
			return
		end
		local aspect = size.X / size.Y
		local w, h = THUMB_SIZE.X, THUMB_SIZE.Y
		if aspect >= 1 then
			w = math.min(ART_SIZE.X, h * aspect)
			h = w / aspect
		else
			h = math.min(ART_SIZE.Y, w / aspect)
			w = h * aspect
		end
		local centre = THUMB_OFFSET + THUMB_SIZE / 2
		img.ImageRectOffset = Vector2.new(
			math.clamp(centre.X - w / 2, 0, ART_SIZE.X - w),
			math.clamp(centre.Y - h / 2, 0, ART_SIZE.Y - h)
		)
		img.ImageRectSize = Vector2.new(w, h)
		img.ScaleType = Enum.ScaleType.Stretch
	else
		img.ImageRectOffset = Vector2.zero
		img.ImageRectSize = Vector2.zero
		img.ScaleType = Enum.ScaleType.Fit
	end
end

-- The power's role colour (cards, effects), white for an unknown id.
function PowerCardFace.color(id: string): Color3
	local def = Mods.def(id)
	return if def then Theme.ROLE[def.role] or WHITE else WHITE
end

return PowerCardFace
