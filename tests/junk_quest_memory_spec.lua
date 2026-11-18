local Loader = require("tests.helpers.loader")

describe("junk's quest memory", function()
	local ns, Test, Memory

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		Test.state.questItemObjectives = { [101] = { "Waterlogged Saw: 0/1" }, [202] = { "Murloc Fin: 2/8" } }
		Test.state.questObjectives = { "Waterlogged Saw: 0/1", "Murloc Fin: 2/8" }
		Loader.Start(ns)
		Memory = ns.Modules:Get("Junk").QuestMemory
	end)

	it("knows what the quests in the log still want, regardless of case", function()
		assert.same({ true, true, false }, { Memory.Wanted("Waterlogged Saw"), Memory.Wanted("murloc fin"), Memory.Wanted("Linen Cloth") })
	end)

	it("learns the items of a quest turned in, also once it has left the log, and keeps them for the character", function()
		-- The log changes before the turn-in comes: the quest is gone from it.
		Test.state.questItemObjectives = { [202] = { "Murloc Fin: 2/8" } }
		Test.state.questObjectives = { "Murloc Fin: 2/8" }
		Test.FireEvent("QUEST_LOG_UPDATE")
		Test.FireEvent("QUEST_TURNED_IN", 101, 450, 0)
		assert.same({ true, false, false }, { Memory.Done("Waterlogged Saw"), Memory.Done("Murloc Fin"), Memory.Wanted("Waterlogged Saw") })
		assert.same({ schema = 1, done = { ["waterlogged saw"] = true } }, Test.state.saved.LootomanCharDB.sections.questItems)
	end)

	it("learns nothing from a quest abandoned, nor from a quest it never saw", function()
		Test.state.questItemObjectives, Test.state.questObjectives = {}, {}
		Test.FireEvent("QUEST_LOG_UPDATE")
		Test.FireEvent("QUEST_TURNED_IN", 999, 0, 0)
		assert.same({ false, false }, { Memory.Done("Waterlogged Saw"), Memory.Done("Murloc Fin") })
	end)

	it("drops QuestieDB's answers when a quest is turned in", function()
		local forgot = false
		ns.Integrations.QuestieDB.Forget = function() forgot = true end
		Test.FireEvent("QUEST_TURNED_IN", 202, 0, 0)
		assert.is_true(forgot)
	end)
end)
