--!strict
-- Every sound the game plays, in one place so they're easy to swap.
-- Sources are licensed Creator Store libraries (Audioscape "AS_" and
-- ProSoundEffects). These are placeholders until the game gets its own pass.

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

return table.freeze({
	-- Gunshots
	ShotPistol = id(77455268208044), -- AS_gun_shot-01
	ShotRifle = id(128598607431847), -- AS_gun_shot-02
	ShotSmg = id(86036041526253), -- AS_gun_shot-03
	ShotHeavyPistol = id(124764074117990), -- AS_gun_shot-04
	ShotShotgun = id(109431560870225), -- AS_gun_punch-01
	ShotSniper = id(88251528094896), -- AS_gun_punch-02
	ShotMachineGun = id(73585186939835), -- AS_gun_punch-03
	ShotRail = id(9116227010), -- ProSoundEffects: Laser Blasts Transporter Elements 4
	RailCharge = id(9116226996), -- ProSoundEffects: Laser Blasts Transporter Elements 2

	-- Handling
	MagOut = id(101803348893194), -- AS_gun_foley-01
	MagIn = id(92321876028160), -- AS_gun_foley-02
	Cycle = id(135901981148051), -- AS_gun_foley-03 (bolt / pump / charging handle)
	Equip = id(73599108833500), -- AS_gun_foley-04
	Swing = id(9125620110), -- ProSoundEffects: Knife Swoosh Thick

	-- Feedback (pitched variants of the energy blast until UI sounds are chosen)
	HitBody = id(9116227010),
	HitHead = id(9116227010),
	Kill = id(9116226996),
	DryFire = id(135901981148051),
})
