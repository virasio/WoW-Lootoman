local _, ns = ...

-- The loot rolls' data for retail: the classes, what each can equip, and what
-- counts as its own by default when it needs an item (its own armor type, the
-- primary stats of its specializations). The player changes the defaults in
-- the Ninja Rules window (Core/NeedRules.lua).
--
-- Subclasses are the game's (Enum.ItemArmorSubclass, Enum.ItemWeaponSubclass):
-- armor 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield; weapons 0 one-handed
-- axe, 1 two-handed axe, 2 bow, 3 gun, 4 one-handed mace, 5 two-handed mace,
-- 6 polearm, 7 one-handed sword, 8 two-handed sword, 9 warglaive, 10 staff,
-- 13 fist weapon, 15 dagger, 18 crossbow, 19 wand.
ns.Data.rolls = {
	-- The classes, in the game's order: the class file and the class ID.
	classes = {
		{ "WARRIOR", 1 }, { "PALADIN", 2 }, { "HUNTER", 3 }, { "ROGUE", 4 }, { "PRIEST", 5 }, { "DEATHKNIGHT", 6 },
		{ "SHAMAN", 7 }, { "MAGE", 8 }, { "WARLOCK", 9 }, { "MONK", 10 }, { "DRUID", 11 }, { "DEMONHUNTER", 12 },
		{ "EVOKER", 13 },
	},
	-- The primary stats, as the item's stats name them (ITEM_MOD_<STAT>_SHORT).
	stats = { "STRENGTH", "AGILITY", "INTELLECT" },
	-- The armor types and weapon types the rules show, in this order.
	armor = { 1, 2, 3, 4, 6 },
	weapons = { 0, 1, 4, 5, 7, 8, 6, 10, 15, 13, 9, 2, 18, 3, 19 },
	-- The highest level a character reaches: the end of an armor type's level box.
	maxLevel = 90,
	-- What each class can equip at all.
	canEquip = {
		WARRIOR = { armor = { 1, 2, 3, 4, 6 }, weapons = { 0, 1, 4, 5, 6, 7, 8, 10, 13, 15 } },
		PALADIN = { armor = { 1, 2, 3, 4, 6 }, weapons = { 0, 1, 4, 5, 6, 7, 8 } },
		HUNTER = { armor = { 1, 2, 3 }, weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 } },
		ROGUE = { armor = { 1, 2 }, weapons = { 0, 4, 7, 13, 15 } },
		PRIEST = { armor = { 1 }, weapons = { 4, 10, 15, 19 } },
		DEATHKNIGHT = { armor = { 1, 2, 3, 4 }, weapons = { 0, 1, 4, 5, 6, 7, 8 } },
		SHAMAN = { armor = { 1, 2, 3, 6 }, weapons = { 0, 1, 4, 5, 10, 13, 15 } },
		MAGE = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
		WARLOCK = { armor = { 1 }, weapons = { 7, 10, 15, 19 } },
		MONK = { armor = { 1, 2 }, weapons = { 0, 4, 6, 7, 10, 13 } },
		DRUID = { armor = { 1, 2 }, weapons = { 4, 5, 6, 10, 13, 15 } },
		DEMONHUNTER = { armor = { 1, 2 }, weapons = { 0, 7, 9, 13 } },
		EVOKER = { armor = { 1, 2, 3 }, weapons = { 0, 1, 4, 5, 7, 8, 10, 13, 15 } },
	},
	-- What counts as a class's own by default: its own armor type (and
	-- shields), the primary stats of its specializations. Weapons: every type
	-- the class can equip.
	defaults = {
		WARRIOR = { armor = { [4] = true, [6] = true }, stats = { "STRENGTH" } },
		PALADIN = { armor = { [4] = true, [6] = true }, stats = { "STRENGTH", "INTELLECT" } },
		HUNTER = { armor = { [3] = true }, stats = { "AGILITY" } },
		ROGUE = { armor = { [2] = true }, stats = { "AGILITY" } },
		PRIEST = { armor = { [1] = true }, stats = { "INTELLECT" } },
		DEATHKNIGHT = { armor = { [4] = true }, stats = { "STRENGTH" } },
		SHAMAN = { armor = { [3] = true, [6] = true }, stats = { "AGILITY", "INTELLECT" } },
		MAGE = { armor = { [1] = true }, stats = { "INTELLECT" } },
		WARLOCK = { armor = { [1] = true }, stats = { "INTELLECT" } },
		MONK = { armor = { [2] = true }, stats = { "AGILITY", "INTELLECT" } },
		DRUID = { armor = { [2] = true }, stats = { "AGILITY", "INTELLECT" } },
		DEMONHUNTER = { armor = { [2] = true }, stats = { "AGILITY" } },
		EVOKER = { armor = { [3] = true }, stats = { "INTELLECT" } },
	},
	-- The demo's items: a blue dagger for the group roll (Gutwrencher, BoE),
	-- a purple staff for the raid roll (Glowing Brightwood Staff).
	demoItems = { group = 5616, raid = 812 },
}
