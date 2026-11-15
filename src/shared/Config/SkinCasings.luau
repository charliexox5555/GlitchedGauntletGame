--!strict
-- Ejected casings for structural skin lines (owner, 2026-11-14: the shell a
-- skin throws should look like that skin's round, a colour change plus a
-- touch of the line's design). Util/ShellFx reads the gun model's SkinLine
-- attribute; lines missing here (and stock guns) keep the stock brass shell.
--
-- Geometry: ReplicatedStorage.WeaponSkins._Casing (Studio-owned, beside the
-- skins): CasingBody, an 8-sided case with rim, groove and necked mouth, and
-- CasingBand, a ring proud of the case (tools/blender/model_skin_casing.py).
-- `body` matches the round in that line's magazines; `band` is the line's
-- accent. Shotgun shells swap roles: `hull` is the plastic hull colour and the
-- band becomes the metal base. Neon colours are given already darkened (Neon
-- blows bright colours out to white).
export type Casing = {
	body: string,
	bodyMaterial: string,
	band: string,
	bandMaterial: string,
	hull: string,
	hullMaterial: string,
}

return table.freeze({
	TEMPLATE = "_Casing",
	-- Band centre along the casing, in fractions of its length (the imported
	-- mesh's +X end is the mouth). Band size relative to the case.
	BAND_OFFSET = 0.1,
	BAND_SCALE = Vector3.new(0.16, 0.994, 0.994),
	LINES = table.freeze({
		Giltfold = table.freeze({ -- smoked pewter round, ivory paper band
			body = "6E737D",
			bodyMaterial = "Metal",
			band = "E8DAC0",
			bandMaterial = "SmoothPlastic",
			hull = "E8DAC0",
			hullMaterial = "SmoothPlastic",
		}),
		Sealwork = table.freeze({ -- brass round, vermilion seal band; vermilion shotgun hull
			body = "B08A4A",
			bodyMaterial = "Metal",
			band = "8F222D",
			bandMaterial = "SmoothPlastic",
			hull = "8F222D",
			hullMaterial = "SmoothPlastic",
		}),
		Payload = table.freeze({ -- foil-gold casing, mission blue band; flight white hull
			body = "9C8A5E",
			bodyMaterial = "Metal",
			band = "2E67B2",
			bandMaterial = "SmoothPlastic",
			hull = "E2E7ED",
			hullMaterial = "SmoothPlastic",
		}),
		Inkshift = table.freeze({ -- blue-grey casing, cyan pop band; vermilion hull
			body = "6F7F98",
			bodyMaterial = "Metal",
			band = "218C99",
			bandMaterial = "Neon",
			hull = "E46C40",
			hullMaterial = "SmoothPlastic",
		}),
		Moltframe = table.freeze({ -- smoke nickel casing, violet glow band; violet hull
			body = "63637A",
			bodyMaterial = "Metal",
			band = "703B91",
			bandMaterial = "Neon",
			hull = "3A1458",
			hullMaterial = "SmoothPlastic",
		}),
	}),
})
