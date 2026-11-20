local Loader = require("tests.helpers.loader")

-- The player's changes to the classes' rules (Core/NeedRules.lua), kept for
-- the whole account and only where they differ from the defaults.

describe("saved need rules", function()
	local ns, NeedRules, changed

	local function start(saved)
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Loader.Start(ns, saved)
		NeedRules = ns.NeedRules
		changed = {}
		ns.Bus:On("NeedRulesChanged", "test", function(_, classFile)
			changed[#changed + 1] = classFile or "all"
		end)
	end

	local function saved()
		return ns.Compat.Test.state.saved.LootomanDB.sections.needRules
	end

	before_each(function()
		start()
	end)

	it("keeps only what differs from the defaults, levels included, and tells who listens", function()
		assert.is_true(NeedRules.Set("WARRIOR", "armor", 1, true))
		assert.is_true(NeedRules.Set("WARRIOR", "armor", 3, 50))
		assert.is_true(NeedRules.Set("WARRIOR", "stats", "INTELLECT", true))
		assert.is_true(NeedRules.Set("WARRIOR", "weapons", 15, false))
		assert.same({ armor = { [1] = true, [3] = 50 }, stats = { INTELLECT = true }, weapons = { [15] = false } }, saved().classes.WARRIOR)
		assert.equals(1, saved().schema)
		assert.same({ "WARRIOR", "WARRIOR", "WARRIOR", "WARRIOR" }, changed)
		local rules = NeedRules.Get("WARRIOR")
		assert.same({ [1] = true, [2] = 40, [3] = 50, [4] = true, [6] = true }, rules.armor)
		assert.is_nil(rules.weapons[15])
		assert.same({ 50, false, true }, { NeedRules.Value("WARRIOR", "armor", 3), NeedRules.Value("WARRIOR", "weapons", 15),
			NeedRules.Value("WARRIOR", "stats", "INTELLECT") })
		-- Set back to the default, a change is forgotten; with nothing left, the class.
		NeedRules.Set("WARRIOR", "armor", 3, 40)
		NeedRules.Set("WARRIOR", "armor", 1, false)
		NeedRules.Set("WARRIOR", "stats", "INTELLECT", false)
		NeedRules.Set("WARRIOR", "weapons", 15, true)
		assert.is_nil(saved().classes.WARRIOR)
		assert.is_false(NeedRules.IsChanged("WARRIOR"))
	end)

	it("refuses what a class cannot have, a level out of range, and a class the client lacks", function()
		assert.is_false(NeedRules.Set("MAGE", "armor", 4, true))
		assert.is_false(NeedRules.Set("WARRIOR", "weapons", 19, true))
		assert.is_false(NeedRules.Set("WARRIOR", "armor", 3, 61))
		assert.is_false(NeedRules.Set("WARRIOR", "armor", 3, 0))
		assert.is_false(NeedRules.Set("WARRIOR", "armor", 3, 39.5))
		assert.is_false(NeedRules.Set("WARRIOR", "weapons", 15, 30))
		assert.is_false(NeedRules.Set("MONK", "armor", 2, true))
		assert.is_nil(NeedRules.Get("MONK"))
		assert.same({}, changed)
	end)

	it("resets a class, and every class", function()
		NeedRules.Set("WARRIOR", "armor", 1, true)
		NeedRules.Set("MAGE", "stats", "AGILITY", true)
		assert.equals(2, NeedRules.ChangedCount())
		NeedRules.Reset("WARRIOR")
		assert.same({ false, true }, { NeedRules.IsChanged("WARRIOR"), NeedRules.IsChanged("MAGE") })
		NeedRules.ResetAll()
		assert.equals(0, NeedRules.ChangedCount())
		assert.same({ "WARRIOR", "MAGE", "WARRIOR", "all" }, changed)
	end)

	it("keeps the rules for every character, and ignores saved values a class cannot have", function()
		NeedRules.Set("HUNTER", "armor", 2, true)
		local account = ns.Compat.Test.state.saved.LootomanDB
		account.sections.needRules.classes.MAGE = { armor = { [4] = true, [1] = "x" }, stats = "nonsense", weapons = { [7] = false } }
		account.sections.needRules.classes.NOBODY = { armor = { [1] = true } }
		start({ LootomanDB = account })
		assert.is_true(NeedRules.Get("HUNTER").armor[2])
		local mage = NeedRules.Get("MAGE")
		assert.same({ [1] = true }, mage.armor)
		assert.is_nil(mage.weapons[7])
		assert.is_true(mage.stats.INTELLECT)
	end)

	it("writes nothing into saved data it must leave alone", function()
		local newer = { schema = 999, profiles = {}, sections = { needRules = { schema = 1, classes = {} } } }
		start({ LootomanDB = newer })
		assert.is_true(ns.Storage:IsReadOnly())
		NeedRules.Set("WARRIOR", "armor", 1, true)
		assert.same({}, newer.sections.needRules.classes)
	end)
end)
