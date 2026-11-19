local Loader = require("tests.helpers.loader")

-- QuestieDB in the four states an integration can be in.
describe("QuestieDB", function()
	local ns, Test, QuestieDB, calls

	-- QuestieDB 1.1.2's public API: a contract check and the item's related quests.
	local function install(options)
		options = options or {}
		calls = 0
		rawset(_G, "LibQuestieDB", {
			RequireContract = function(required) return required <= (options.contract or 4) end,
			Item = { relatedQuests = function(itemID)
				calls = calls + 1
				if options.fails then
					error("relatedQuests: broken")
				end
				return ({ [2589] = { 101, 202, "x" } })[itemID]
			end },
		})
		Test.state.addons.QuestieDB = true
	end

	local function report()
		for _, line in ipairs((ns.SelfTest.Run())) do
			local found = line:match("QuestieDB: .*")
			if found then
				return found
			end
		end
	end

	before_each(function()
		rawset(_G, "LibQuestieDB", nil)
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		Loader.Start(ns)
		QuestieDB = ns.Integrations.QuestieDB
	end)

	after_each(function()
		rawset(_G, "LibQuestieDB", nil)
	end)

	it("is off when QuestieDB is not installed", function()
		assert.same({ "missing", nil }, { QuestieDB.State(), QuestieDB.RelatedQuests(2589) })
		assert.matches("not installed: junk suggestions use the quest log", report(), 1, true)
	end)

	it("is off when QuestieDB is loaded without its API, or with another contract", function()
		Test.state.addons.QuestieDB = true
		assert.equals("noApi", QuestieDB.State())
		install({ contract = 3 })
		assert.same({ "noApi", nil }, { QuestieDB.State(), QuestieDB.RelatedQuests(2589) })
	end)

	it("gives an item's quests, kept until a quest is turned in", function()
		install()
		assert.same({ "working", { 101, 202 }, {} }, { QuestieDB.State(), QuestieDB.RelatedQuests(2589), QuestieDB.RelatedQuests(4) })
		QuestieDB.RelatedQuests(2589)
		assert.equals(2, calls)
		QuestieDB.Forget()
		QuestieDB.RelatedQuests(2589)
		assert.equals(3, calls)
		assert.equals("QuestieDB: working", report())
	end)

	it("turns itself off after an error, and says so", function()
		install({ fails = true })
		assert.is_nil(QuestieDB.RelatedQuests(2589))
		assert.same({ "failed", nil }, { (QuestieDB.State()), QuestieDB.RelatedQuests(2589) })
		assert.matches("off after an error: .*broken", report())
	end)
end)
