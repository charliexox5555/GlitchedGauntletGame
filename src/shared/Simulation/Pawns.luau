--!strict
-- Characters the server simulates that no Player owns: AI bots
-- (vault/01 Design/Bots.md). Each has an `owner` instance standing in for
-- the Player: it holds the same attributes the simulations read from a
-- Player (MoveMult, Mod<n>Id, WeaponId, ReloadAt...) and a PlayContext whose
-- InputActions are the bot's inputs. Movement, Abilities and Poses step
-- these on the server exactly like players' characters.
--
-- Only server code adds pawns; on clients the list is always empty.

local Pawns = {}

export type Pawn = { owner: Instance, character: Model }

local list: { Pawn } = {}

function Pawns.add(owner: Instance, character: Model)
	Pawns.remove(character)
	table.insert(list, { owner = owner, character = character })
end

function Pawns.remove(character: Model)
	for i = #list, 1, -1 do
		if list[i].character == character then
			table.remove(list, i)
		end
	end
end

-- The live list (don't keep or change it).
function Pawns.list(): { Pawn }
	return list
end

-- The owner of a pawn character, if it is one.
function Pawns.ownerOf(character: Model): Instance?
	for _, pawn in list do
		if pawn.character == character then
			return pawn.owner
		end
	end
	return nil
end

return Pawns
