local Loader = require("tests.helpers.loader")

describe("junk suggestions", function()
	local Suggest

	before_each(function()
		Suggest = Loader.LoadAddon().Rules.Suggest
	end)

	local function find(facts, enabled)
		local found = Suggest.Find(facts, enabled)
		return found and found.rule, found
	end

	describe("quest done", function()
		it("suggests an item that starts a quest already done", function()
			local rule, found = find({ startsQuest = 7, startsQuestDone = true })
			assert.same({ "questDone", "started" }, { rule, found.why })
			assert.is_nil((find({ startsQuest = 7, startsQuestDone = false })))
		end)

		it("suggests a quest item whose quests are all done, with QuestieDB", function()
			local rule, found = find({ questItem = true, related = { 1, 2 }, relatedDone = true })
			assert.same({ "questDone", "done" }, { rule, found.why })
			assert.is_nil((find({ questItem = true, related = { 1, 2 }, relatedDone = false })))
			assert.is_nil((find({ questItem = true, related = {} })))
		end)

		it("suggests a quest item no quest in the log wants, without QuestieDB", function()
			local rule, found = find({ questItem = true })
			assert.same({ "questDone", "notInLog" }, { rule, found.why })
			assert.is_nil((find({ questItem = true, wantedByLog = true })))
		end)
	end)

	describe("leftovers from quests", function()
		it("suggests an item whose quests are all done, when it is not worth the auction", function()
			assert.equals("leftovers", (find({ related = { 1 }, relatedDone = true, auction = 140, vendor = 100 })))
			assert.is_nil((find({ related = { 1 }, relatedDone = true, auction = 160, vendor = 100 })))
			-- Without an auction price: only an item no profession uses.
			assert.equals("leftovers", (find({ related = { 1 }, relatedDone = true, vendor = 100 })))
			assert.is_nil((find({ related = { 1 }, relatedDone = true, vendor = 100, isCraftingReagent = true })))
		end)

		it("without QuestieDB, suggests what a quest this character turned in wanted", function()
			assert.equals("leftovers", (find({ doneByMemory = true, vendor = 10 })))
			assert.is_nil((find({ doneByMemory = false, vendor = 10 })))
			-- With QuestieDB, its answer counts, not the memory's.
			assert.is_nil((find({ related = { 1 }, relatedDone = false, doneByMemory = true, vendor = 10 })))
		end)
	end)

	it("suggests soulbound gear the class can't use, once its level is reached", function()
		assert.equals("unusable", (find({ bound = true, equippable = true, canUse = false, requiredLevel = 20, level = 30 })))
		assert.is_nil((find({ bound = true, equippable = true, canUse = false, requiredLevel = 40, level = 30 })))
		assert.is_nil((find({ bound = false, equippable = true, canUse = false, requiredLevel = 20, level = 30 })))
		assert.is_nil((find({ bound = true, equippable = true, canUse = true, level = 30 })))
	end)

	it("suggests what is already known, a tradeable one only when not worth the auction", function()
		local rule, found = find({ recipeKnown = true, bound = true })
		assert.same({ "known", "recipe" }, { rule, found.why })
		rule, found = find({ collected = true, auction = 100, vendor = 100 })
		assert.same({ "known", "collected" }, { rule, found.why })
		assert.is_nil((find({ collected = true, auction = 9000, vendor = 100 })))
	end)

	it("suggests food, drink, potions and bandages far below the character's level", function()
		local food = { classID = 0, subclassID = 5, requiredLevel = 5, level = 25, vendor = 1 }
		assert.equals("outgrown", (find(food)))
		food.level = 24
		assert.is_nil((find(food)))
		assert.equals("outgrown", (find({ classID = 0, subclassID = 7, requiredLevel = 0, level = 20, bound = true })))
		-- A scroll is no food.
		assert.is_nil((find({ classID = 0, subclassID = 4, requiredLevel = 1, level = 60 })))
	end)

	it("never suggests an item with a mark, in a set, refundable, an uncollected look, or one a quest still wants", function()
		local base = { startsQuest = 7, startsQuestDone = true }
		for _, key in ipairs({ "equipmentSet", "refundable", "uncollected", "wantedByLog", "relatedActive" }) do
			local facts = { startsQuest = 7, startsQuestDone = true }
			facts[key] = true
			assert.is_nil((find(facts)), key)
		end
		base.mark = "notJunk"
		assert.is_nil((find(base)))
	end)

	it("takes the first rule that finds an item, and skips a rule switched off", function()
		local facts = { questItem = true, bound = true, equippable = true, canUse = false, level = 60 }
		assert.equals("questDone", (find(facts)))
		assert.equals("unusable", (find(facts, { questDone = false })))
		assert.is_nil((find(facts, { questDone = false, unusable = false })))
	end)

	it("warns about junk a quest in the log still wants", function()
		assert.same({ true, true, false }, { Suggest.Hint({ wantedByLog = true }), Suggest.Hint({ relatedActive = true }), Suggest.Hint({}) })
	end)
end)
