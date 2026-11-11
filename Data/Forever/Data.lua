local _, ns = ...

-- Data for WoW Forever: disenchant tables, categories and default
-- rules arrive with their releases. The TOC loads this file only for game type
-- "camelot", so code never checks the client; the name is for the self-test.
ns.Data = {
	set = "Forever",
	-- Bag families with a free-slot token each: { token, bit, bag }, bag being
	-- the item ID of one such bag, whose kind names the family in the client
	-- language. Only bits checked in game (/lootoman families in a debug
	-- build): the client gives the bits, but Blizzard does not name them.
	-- Checked in game with /lootoman families on Nov 11, 2026; the other kinds
	-- of bag (mining, gems, tackle boxes and the like) are not on this client.
	BagFamilies = {
		{ token = "herb", bit = 0x20, bag = 22250 }, -- Herb Pouch
		{ token = "enchanting", bit = 0x40, bag = 22246 }, -- Enchanted Mageweave Pouch
		{ token = "soul", bit = 0x4, bag = 22243 }, -- Small Soul Pouch
		{ token = "quiver", bit = 0x1, bag = 2101 }, -- Light Quiver
		{ token = "ammo", bit = 0x2, bag = 2102 }, -- Small Ammo Pouch
	},
}
