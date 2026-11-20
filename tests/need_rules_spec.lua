local Loader = require("tests.helpers.loader")

-- Whether a need breaks a class's rules (Rules/Need.lua), the rules' data of
-- both clients, and how a player's choices in a group are read.

local ALL = { armor = true, weapons = true, stats = true, minQuality = 2 }

local function forever()
	local ns = Loader.LoadAddon({ gameType = "camelot" })
	return ns.Rules.Need, ns.Data.rolls
end

describe("need rules", function()
	local Need, data

	before_each(function()
		Need, data = forever()
	end)

	local function rules(classFile, changes)
		return Need.Rules(data, classFile, changes)
	end

	local function judge(item, class, level, checks)
		item.quality = item.quality or 2
		return Need.Judge(item, { class = class, level = level }, rules(class), checks or ALL)
	end

	it("marks armor of a type not the class's own", function()
		assert.same({ { kind = "armor", subclass = 3 } }, (judge({ classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", stats = {} }, "MAGE", 30)))
		assert.same({}, (judge({ classID = 4, subclassID = 1, equipLoc = "INVTYPE_HEAD", stats = {} }, "MAGE", 30)))
		-- A paladin's cloth is his own, a warrior's is not.
		assert.same({}, (judge({ classID = 4, subclassID = 1, equipLoc = "INVTYPE_CHEST", stats = {} }, "PALADIN", 55)))
		assert.same({ { kind = "armor", subclass = 1 } }, (judge({ classID = 4, subclassID = 1, equipLoc = "INVTYPE_CHEST", stats = {} }, "WARRIOR", 30)))
	end)

	it("counts an armor type up to a level: below it, at it, past it, and the level not known", function()
		local mail = { classID = 4, subclassID = 3, equipLoc = "INVTYPE_CHEST", stats = {} }
		assert.same({}, (judge(mail, "WARRIOR", 35)))
		assert.same({}, (judge(mail, "WARRIOR", 40)))
		assert.same({ { kind = "armor", subclass = 3, level = 40 } }, (judge(mail, "WARRIOR", 41)))
		assert.same({}, (judge(mail, "WARRIOR", nil)))
	end)

	it("judges cloaks, rings and other pieces anyone wears by their stats only", function()
		local cloak = { classID = 4, subclassID = 1, equipLoc = "INVTYPE_CLOAK", stats = { STRENGTH = true } }
		assert.same({}, (judge(cloak, "WARRIOR", 50)))
		assert.same({ { kind = "stats", stats = { "STRENGTH" } } }, (judge(cloak, "MAGE", 50)))
		local ring = { classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", stats = { INTELLECT = true, SPIRIT = true } }
		assert.same({ { kind = "stats", stats = { "INTELLECT", "SPIRIT" } } }, (judge(ring, "ROGUE", 50)))
		assert.same({}, (judge(ring, "PRIEST", 50)))
		-- An item without primary stats breaks nothing by its stats.
		assert.same({}, (judge({ classID = 4, subclassID = 0, equipLoc = "INVTYPE_NECK", stats = {} }, "ROGUE", 50)))
	end)

	it("judges a shield and a relic as types of their own", function()
		local shield = { classID = 4, subclassID = 6, equipLoc = "INVTYPE_SHIELD", stats = {} }
		assert.same({}, (judge(shield, "SHAMAN", 50)))
		assert.same({ { kind = "armor", subclass = 6 } }, (judge(shield, "ROGUE", 50)))
		local idol = { classID = 4, subclassID = 8, equipLoc = "INVTYPE_RELIC", stats = {} }
		assert.same({}, (judge(idol, "DRUID", 50)))
		assert.same({ { kind = "armor", subclass = 8 } }, (judge(idol, "PALADIN", 50)))
	end)

	it("judges a weapon by its type and its stats apart: a dagger is a warrior's, a dagger with Intellect is not", function()
		assert.same({}, (judge({ classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", stats = { AGILITY = true } }, "WARRIOR", 50)))
		assert.same({ { kind = "stats", stats = { "INTELLECT" } } },
			(judge({ classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", stats = { INTELLECT = true } }, "WARRIOR", 50)))
		assert.same({ { kind = "weapon", subclass = 19 } }, (judge({ classID = 2, subclassID = 19, equipLoc = "INVTYPE_RANGEDRIGHT", stats = {} }, "WARRIOR", 50)))
		-- Both at once.
		assert.same({ { kind = "weapon", subclass = 1 }, { kind = "stats", stats = { "STRENGTH" } } },
			(judge({ classID = 2, subclassID = 1, equipLoc = "INVTYPE_2HWEAPON", stats = { STRENGTH = true } }, "MAGE", 50)))
	end)

	it("waits for stats the game has not loaded, and judges the type meanwhile", function()
		local reasons, pending = judge({ classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD" }, "MAGE", 50)
		assert.same({ { kind = "armor", subclass = 3 } }, reasons)
		assert.is_true(pending)
		local _, done = judge({ classID = 4, subclassID = 1, equipLoc = "INVTYPE_HEAD", stats = {} }, "MAGE", 50)
		assert.is_false(done)
	end)

	it("leaves out each check that is off, items below the lowest quality, and what is not gear", function()
		local mailInt = { classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", stats = { STRENGTH = true } }
		assert.same({ { kind = "stats", stats = { "STRENGTH" } } }, (judge(mailInt, "MAGE", 50, { armor = false, weapons = true, stats = true })))
		assert.same({ { kind = "armor", subclass = 3 } }, (judge(mailInt, "MAGE", 50, { armor = true, weapons = true, stats = false })))
		assert.same({}, (judge({ classID = 2, subclassID = 19, stats = {} }, "WARRIOR", 50, { armor = true, weapons = false, stats = true })))
		assert.same({}, (judge({ classID = 4, subclassID = 3, quality = 2, stats = {} }, "MAGE", 50, { armor = true, weapons = true, stats = true, minQuality = 3 })))
		assert.same({}, (judge({ classID = 15, subclassID = 0, stats = {} }, "MAGE", 50)))
		assert.same({}, (judge({ classID = 2, subclassID = 20, stats = {} }, "MAGE", 50)))
	end)

	it("reads the primary stats of an item, retail's combined ones too", function()
		assert.same({ INTELLECT = true, SPIRIT = true },
			Need.PrimaryStats({ ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPIRIT_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 8 }, data.stats))
		assert.same({ AGILITY = true, INTELLECT = true }, Need.PrimaryStats({ ITEM_MOD_AGILITY_INTELLECT_SHORT = 20 }, { "STRENGTH", "AGILITY", "INTELLECT" }))
		assert.same({}, Need.PrimaryStats({ ITEM_MOD_CRIT_RATING_SHORT = 4 }, data.stats))
		assert.is_nil(Need.PrimaryStats(nil, data.stats))
		-- A retail item for agility or intellect fits a monk.
		local mainline = Loader.LoadAddon({ gameType = "standard" })
		local retail = mainline.Data.rolls
		local reasons = mainline.Rules.Need.Judge({ classID = 4, subclassID = 2, quality = 3, stats = { AGILITY = true, INTELLECT = true } },
			{ class = "MONK", level = 80 }, mainline.Rules.Need.Rules(retail, "MONK"), ALL)
		assert.same({}, reasons)
	end)

	it("applies the player's changes, but never more than the class can equip", function()
		local changed = rules("WARRIOR", { armor = { [1] = true, [3] = false, [2] = 30 }, weapons = { [19] = true, [15] = false }, stats = { INTELLECT = true } })
		assert.same({ [1] = true, [2] = 30, [4] = true, [6] = true }, changed.armor)
		assert.is_nil(changed.weapons[19])
		assert.is_nil(changed.weapons[15])
		assert.is_true(changed.stats.INTELLECT)
		assert.is_true(Need.CanEquip(data, "WARRIOR", "armor", 4))
		assert.is_false(Need.CanEquip(data, "MAGE", "armor", 4))
		assert.is_nil(rules("NOBODY"))
	end)

	it("has every part for every class of both clients, the defaults within what each can equip", function()
		for _, gameType in ipairs({ "standard", "camelot" }) do
			local ns = Loader.LoadAddon({ gameType = gameType })
			local rolls = ns.Data.rolls
			assert.is_true(#rolls.classes >= 9, gameType)
			for _, class in ipairs(rolls.classes) do
				local file = class[1]
				assert.is_number(class[2], file)
				local canEquip, defaults = rolls.canEquip[file], rolls.defaults[file]
				assert.is_table(canEquip, file)
				assert.is_table(defaults, file)
				for subclass in pairs(defaults.armor) do
					assert.is_true(ns.Rules.Need.CanEquip(rolls, file, "armor", subclass), file .. " armor " .. subclass)
				end
				for _, stat in ipairs(defaults.stats) do
					assert.is_true(ns.Rules.Need.CanEquip(rolls, file, "stats", stat), file .. " " .. stat)
				end
				assert.is_true(next(ns.Rules.Need.Rules(rolls, file).weapons) ~= nil, file)
			end
			assert.is_number(rolls.maxLevel)
			assert.is_true(#rolls.demoItems > 0)
		end
	end)
end)

describe("a player's choices in a group", function()
	local Need, preset

	before_each(function()
		Need = forever()
		preset = Need.Preset("normal")
	end)

	local function choices(states)
		local list = {}
		for index, state in ipairs(states) do
			list[index] = { state = state }
		end
		return list
	end

	it("needs nearly everything by each preset", function()
		local needy = choices({ 0, 0, 0, 3, 0, 1 })
		assert.is_true((Need.NeedsEverything(needy, Need.Preset("normal"))))
		assert.is_false((Need.NeedsEverything(needy, Need.Preset("lenient"))))
		assert.is_true((Need.NeedsEverything(choices({ 0, 0, 3, 0, 5 }), Need.Preset("strict"))))
		assert.is_false((Need.NeedsEverything(choices({ 0, 0, 0 }), Need.Preset("normal"))))
		-- Rolls not chosen yet count nowhere; an excused need neither.
		local _, needs, total = Need.NeedsEverything({ { state = 0 }, { state = 4 }, { state = 0, excused = true }, { state = 3 } }, preset)
		assert.same({ 1, 2 }, { needs, total })
		-- An unknown strictness is the normal one.
		assert.equals(Need.PRESETS.normal, Need.Preset("nonsense"))
	end)

	it("is fair again after enough choices with needs under the share", function()
		assert.is_true(Need.Fair(choices({ 3, 3, 0, 5 }), preset))
		assert.is_false(Need.Fair(choices({ 3, 0, 5 }), preset))
		assert.is_false(Need.Fair(choices({ 0, 0, 0, 3 }), preset))
	end)

	it("says what his earlier BoE choices tell about a need on a BoE item that does not fit him", function()
		local greed = { state = 3, boe = true, fits = true, link = "bracers" }
		assert.same({ kind = "greedFitting", link = "bracers" }, Need.BoEReason({ { state = 0, boe = true }, greed }, preset))
		-- A greed on one that does not fit is no sign.
		assert.is_nil(Need.BoEReason({ { state = 3, boe = true, fits = false } }, preset))
		assert.same({ kind = "everyBoE", needs = 3, total = 3 }, Need.BoEReason({ { state = 0, boe = true }, { state = 1, boe = true }, { state = 3 } }, preset))
		assert.is_nil(Need.BoEReason({ { state = 0, boe = true } }, preset))
		assert.is_nil(Need.BoEReason({ { state = 0, boe = true }, { state = 0, boe = true, excused = true } }, preset))
		assert.same({ kind = "everyBoE", needs = 2, total = 2 }, Need.BoEReason({ { state = 0, boe = true } }, Need.Preset("strict")))
	end)
end)
