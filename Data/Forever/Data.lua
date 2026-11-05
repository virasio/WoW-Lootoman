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
	BagFamilies = {},
}
