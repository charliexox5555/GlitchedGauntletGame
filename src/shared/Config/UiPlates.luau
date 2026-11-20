--!strict
-- The plate set (vault/02 Art/UI Polish Pass.md → 3): one 9-slice image per
-- shape, greyscale with its light baked in (bright top, deeper bottom, darker
-- lip), tinted by ImageColor3. Made by tools/ui/make_plates.py
-- (art-source/ui/plates/v2/, slices.json), uploaded 2026-11-20.
-- `slice` is the SliceCenter; `ends` is the px width of the fixed end columns
-- that SliceScale is measured against (a plate's end reach / ends).

export type Plate = { image: string, size: Vector2, slice: Rect, ends: number }

local function plate(
	id: number,
	w: number,
	h: number,
	l: number,
	t: number,
	r: number,
	b: number,
	ends: number
): Plate
	return table.freeze({
		image = "rbxassetid://" .. tostring(id),
		size = Vector2.new(w, h),
		slice = Rect.new(l, t, r, b),
		ends = ends,
	})
end

return table.freeze({
	slant = plate(126358774182782, 128, 96, 32, 0, 96, 96, 32), -- both ends slanted (the lobby plate)
	slantR = plate(79321781380250, 128, 96, 8, 0, 96, 96, 32), -- square left, slanted right
	cut1 = plate(129601412125296, 128, 96, 8, 20, 108, 86, 20), -- one cut corner, top right
	cut2 = plate(131426917946532, 128, 96, 20, 20, 108, 76, 20), -- cut top left + bottom right
	cell = plate(94287691931985, 128, 96, 8, 8, 120, 86, 8), -- small chamfers all round
	shadow = plate(120049214308831, 160, 128, 40, 40, 120, 88, 40), -- soft lift shadow (black)
})
