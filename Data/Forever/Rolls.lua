local _, ns = ...

-- The loot rolls' data for WoW Forever: the classes of Classic, what each can
-- equip, and what counts as its own by default when it needs an item. The
-- player changes the defaults in the Ninja Rules window (Core/NeedRules.lua).
--
-- Subclasses are the game's (Enum.ItemArmorSubclass, Enum.ItemWeaponSubclass):
-- armor 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol,
-- 9 totem; weapons 0 one-handed axe, 1 two-handed axe, 2 bow, 3 gun,
-- 4 one-handed mace, 5 two-handed mace, 6 polearm, 7 one-handed sword,
-- 8 two-handed sword, 10 staff, 13 fist weapon, 15 dagger, 16 thrown,
-- 18 crossbow, 19 wand.
ns.Data.rolls = {
	-- The classes, in the game's order: the class file and the class ID.
	classes = {
		{ "WARRIOR", 1 }, { "PALADIN", 2 }, { "HUNTER", 3 }, { "ROGUE", 4 }, { "PRIEST", 5 },
		{ "SHAMAN", 7 }, { "MAGE", 8 }, { "WARLOCK", 9 }, { "DRUID", 11 },
	},
	-- The primary stats, as the item's stats name them (ITEM_MOD_<STAT>_SHORT).
	stats = { "STRENGTH", "AGILITY", "INTELLECT", "SPIRIT" },
	-- The armor types and weapon types the rules show, in this order.
	armor = { 1, 2, 3, 4, 6, 7, 8, 9 },
	weapons = { 0, 1, 4, 5, 7, 8, 6, 10, 15, 13, 2, 18, 3, 16, 19 },
	-- The highest level a character reaches: the end of an armor type's level box.
	maxLevel = 60,
	-- What each class can equip at all, at any level.
	canEquip = {
		WARRIOR = { armor = { 1, 2, 3, 4, 6 }, weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 } },
		PALADIN = { armor = { 1, 2, 3, 4, 6, 7 }, weapons = { 0, 1, 4, 5, 6, 7, 8 } },
		HUNTER = { armor = { 1, 2, 3 }, weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 } },
		ROGUE = { armor = { 1, 2 }, weapons = { 2, 3, 4, 7, 13, 15, 16, 18 } },
		PRIEST = { armor = { 1 }, weapons = { 4, 10, 15, 19 } },
		SHAMAN = { armor = { 1, 2, 3, 6, 9 }, weapons = { 0, 1, 4, 5, 10, 13, 15 } },
		MAGE = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
		WARLOCK = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
		DRUID = { armor = { 1, 2, 8 }, weapons = { 4, 5, 10, 13, 15 } },
	},
	-- What counts as a class's own by default: armor types (true, or the level
	-- up to which it counts: Classic changes armor at 40) and the primary stats.
	-- Weapons: every type the class can equip.
	defaults = {
		WARRIOR = { armor = { [4] = true, [3] = 40, [2] = 40, [6] = true }, stats = { "STRENGTH", "AGILITY" } },
		PALADIN = { armor = { [4] = true, [3] = 40, [2] = 40, [1] = true, [6] = true, [7] = true }, stats = { "STRENGTH", "INTELLECT", "SPIRIT" } },
		HUNTER = { armor = { [3] = true, [2] = 40 }, stats = { "AGILITY", "INTELLECT" } },
		ROGUE = { armor = { [2] = true }, stats = { "AGILITY", "STRENGTH" } },
		PRIEST = { armor = { [1] = true }, stats = { "INTELLECT", "SPIRIT" } },
		SHAMAN = { armor = { [3] = true, [2] = 40, [6] = true, [9] = true }, stats = { "STRENGTH", "AGILITY", "INTELLECT", "SPIRIT" } },
		MAGE = { armor = { [1] = true }, stats = { "INTELLECT", "SPIRIT" } },
		WARLOCK = { armor = { [1] = true }, stats = { "INTELLECT", "SPIRIT" } },
		DRUID = { armor = { [2] = true, [1] = true, [8] = true }, stats = { "STRENGTH", "AGILITY", "INTELLECT", "SPIRIT" } },
	},
	-- The demo's items: a purple ring from a dungeon for the group roll (Band
	-- of the Better Half, WoW Forever's own), a sword of Onyxia's for the raid
	-- roll of forty (Vis'kag the Bloodletter).
	demoItems = { group = 284716, raid = 17075 },
	-- The made-up roll history's drops, besides those two: dungeon items of
	-- the first dungeons (The Deadmines, Wailing Caverns, Shadowfang Keep),
	-- which the client knows by these IDs. One the client cannot load is left out.
	demoHistoryItems = { 5191, 1937, 5199, 5192, 6460, 6473, 6220, 6318, 6321, 5616 },
	-- The raid demo's five, of Onyxia's: Vis'kag the Bloodletter, Deathbringer,
	-- Ring of Binding, Netherwind Crown (a mage's) and Helm of Wrath (a
	-- warrior's).
	demoRaidItems = { 17075, 17068, 18813, 16914, 16963 },
}
