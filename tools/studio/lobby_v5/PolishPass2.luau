--!nocheck
-- Lobby V5 hub 9/10 pass, 2026-11-21 (vault/02 Art/Lobby V5 Plan.md, "Hub 9/10 pass"). ONE-TIME record of the
-- in-place edits made through the Studio MCP that have no build script of their own. Needs V5Kit.LobbyProps.
-- Other parts of this pass: BuildProps.luau (decor props + hub clusters), BuildSeasonClosed.luau, BuildLockerV2.luau,
-- BuildRangeV2.luau, FlickerFix.luau (run on Shop, Hub, Duels, Locker, Range).

local P = require(game.ServerStorage.V5Kit.LobbyProps:Clone())
local S = workspace.LobbyV5.Shell
local O = CFrame.new(0, 0, -1600)

-- 1. hub: the kiosks, benches and part-built stacks go; Blender prop clusters in the four corners
S.Hub.Dressing.Decor:ClearAllChildren()
S.Hub.Dressing.Props:ClearAllChildren()
P.hubClusters(S.Hub.Dressing.Props) -- then pushed toward the centre until clear of the rock (NE moved 1.5-3)

-- 2. shop
local W = S.Shop.Wing_ItemShop
for _, c in W.Fit:GetChildren() do -- declutter the Item Shop: no case table in the middle, no crate racks
	if table.find({ "CaseTable", "Pendant", "Line", "Racking", "Shelves", "BundlesBoard" }, c.Name) then
		c:Destroy()
	end
end
local F = W:GetAttribute("FrameCF")
local D = Instance.new("Model")
D.Name = "Dressing"
D.Parent = W.Fit
local function put(name, scheme, x, z, yaw, y)
	P.place(D, name, scheme, O:Inverse() * F * CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0)).Name =
		name
end
put("Pallet", "Charcoal", -12.3, -26.5, 0) -- a delivery by the STOCKROOM shutter
put("CargoBox", "Olive", -12.3, -26.5, 8, 0.52)
put("AmmoCan", "Charcoal", -12.5, -26.4, 20, 0.52 + 3.68)
put("Drum", "Charcoal", -11.0, -23.3, 0)
put("Drum", "Charcoal", 11.4, -27.3, 0)
put("Drum", "Hazard", 13.8, -26.7, 30)
put("FlatCase", "Olive", 12.6, -23.6, 180)
put("ToolChest", "Charcoal", 14.5, -6.2, 90)
-- + CounterMat (15 x 0.08 x 4.4 Fabric 38,40,44 at F(0, 0.04, -16.8)) with a yellow MatEdge, and a clone of the hall's
--   StandardCase on the counter's right end (F(6.2, 3.8 + h/2, -21.4), turned 168°)
-- display bays: drape (Back, Side) 62,61,59; a warm SurfaceLight "Wash" under every bay ceiling (75°, 14, 1.1);
-- truss spots 3.2 / 40° / 18 with shadows; display spots 2.0 / 12; plinth caps 168,170,174; the cases in the SEASON
-- and CASES bays scaled 1.35 about their bottoms (attribute Enlarged)
-- the Season Pass wing is closed: BuildSeasonClosed.luau

-- 3. fewer labels: the Caution/Notice/GateId plates on every gateway and the range frame, the bay number signs over the
--    hall bays, both junction WayBoards, the hanging ITEM SHOP / SEASON PASS signs, the shutter signs
--    (STOCKROOM, NEXT SEASON). Kept: area signs, queue-bay signs, screens, the Duels how-to boards, MARKET.

-- 4. floating and gaps: Duels Deck.UnderPlate top raised to -1.5 (the front row of deck panels hung 0.1 over it), lift
--    counterweight blocks 2.1 tall (they stood 0.1 apart), both shutter Handles seated on the BottomBar front.

-- 5. Duels: Props model, a crate with two ammo cans at x ±92, a power cabinet and drum at x ±28 against the bulkhead,
--    two drums at each deck end (pushed clear of the walls).
