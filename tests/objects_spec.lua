local Loader = require("tests.helpers.loader")

describe("objects for gathering highlights", function()
	local Objects, known

	-- Made-up cursor file IDs, plain and "Unable".
	local FILES = { Mine = 1, UnableMine = 2, GatherHerbs = 3, UnableGatherHerbs = 4, PickLock = 5, UnablePickLock = 6,
		Quest = 7, Fishing = 8, Mail = 9, Interact = 10, Skin = 11, UnableSkin = 12, SkinHorde = 13 }

	local function object(facts)
		facts.isObject = true
		return facts
	end

	before_each(function()
		Objects = Loader.LoadAddon().Rules.Objects
		known = { cursors = Objects.CursorFiles(function(name) return FILES[name] end), chests = {} }
	end)

	it("knows herbs, ore, chests and quest objects by their cursor, and an Unable cursor as not usable yet", function()
		local function kind(cursor)
			return { Objects.Classify(object({ cursor = cursor }), known) }
		end
		assert.same({ "ore", false }, kind(1))
		assert.same({ "ore", true }, kind(2))
		assert.same({ "herbs", true }, kind(4))
		assert.same({ "chests", true }, kind(6))
		assert.same({ "quest", false, "cursor" }, kind(7))
		-- The fishing bobber, a mailbox, an unknown cursor: not highlighted.
		assert.same({ nil, "bobber" }, kind(8))
		assert.same({ nil, "service" }, kind(9))
		assert.same({ nil, "other" }, kind(10))
	end)

	it("reads a cursor given as a path or an atlas name", function()
		assert.same({ "ore", true }, { Objects.Classify(object({ cursor = "Cursor_Crosshair_UnableMine_64" }), known) })
		assert.same({ "herbs", false }, { Objects.Classify(object({ cursor = "Interface\\Cursor\\GatherHerbs" }), known) })
		assert.same({ "quest", false, "cursor" }, { Objects.Classify(object({ cursor = "Interface\\Cursor\\QuestInteract" }), known) })
	end)

	it("makes an object a quest wants a quest object, but a herb or a vein stays one", function()
		assert.same({ "quest", false, "game" }, { Objects.Classify(object({ cursor = 10, questRelated = true }), known) })
		assert.same({ "quest", false, "tooltip" }, { Objects.Classify(object({ questObjective = true }), known) })
		assert.same({ "herbs", false }, { Objects.Classify(object({ cursor = 3, questRelated = true }), known) })
	end)

	it("knows a chest by a word its name starts or ends with, in English and Russian, or by an earlier loot", function()
		local function kind(name, id)
			return (Objects.Classify(object({ cursor = 10, name = name, objectID = id }), known))
		end
		assert.equals("chests", kind("Battered Chest"))
		assert.equals("chests", kind("Waterlogged Footlocker"))
		assert.equals("chests", kind("Сундук с припасами"))
		assert.equals("chests", kind("Побитый СУНДУК"))
		-- A word inside another one, or no name, is not enough.
		assert.is_nil(kind("Chestnut Tree"))
		assert.is_nil(kind(nil))
		-- A barrel looted before.
		assert.is_nil(kind("Barrel of Milk", 3658))
		known.chests[3658] = true
		assert.equals("chests", kind("Barrel of Milk", 3658))
	end)

	it("never highlights creatures, players or corpses, nor without a target", function()
		assert.same({ nil, "unit" }, { Objects.Classify({ isObject = false, isDead = false, cursor = 7 }, known) })
		assert.same({ nil, "unit" }, { Objects.Classify({ isObject = false, isDead = true }, known) })
		-- A secret identity leaves isObject unknown: not an object.
		assert.same({ nil, "unit" }, { Objects.Classify({ cursor = 1 }, known) })
		assert.same({ nil, "none" }, { Objects.Classify(nil, known) })
	end)

	it("learns every looted object as a chest, which changes only objects that are none of the other kinds", function()
		local chests = {}
		assert.equals(2, Objects.Learn(chests, { 3658, 1617 }))
		assert.same({ [3658] = true, [1617] = true }, chests)
		assert.equals(0, Objects.Learn(chests, { 3658 }))
		known.chests = chests
		-- A herb looted stays a herb, a quest object a quest object; a Windstone becomes a chest.
		assert.equals("herbs", (Objects.Classify(object({ cursor = 3, objectID = 1617 }), known)))
		assert.equals("quest", (Objects.Classify(object({ questRelated = true, objectID = 1617 }), known)))
		assert.equals("chests", (Objects.Classify(object({ cursor = 10, name = "Windstone", objectID = 3658 }), known)))
	end)

	describe("quest objects by their quests' objectives", function()
		local function classify(name, objectives, cursor)
			known.objectives = Objects.ObjectiveTexts(objectives)
			return { Objects.Classify(object({ name = name, cursor = cursor or 10 }), known) }
		end

		it("know an object an unfinished objective names, with the generic cursor", function()
			assert.same({ "quest", false, "objective" }, classify("Waterlogged Saw", { "Waterlogged Saw: 0/1" }))
			assert.same({ "quest", false, "objective" }, classify("Waterlogged Saw", { "0/1 Waterlogged Saw" }))
			-- The name holds the objective.
			assert.same({ "quest", false, "objective" }, classify("Crate of Supplies", { "Supplies: 0/4" }))
		end)

		it("compare regardless of case, Cyrillic too, without the counter", function()
			assert.same({ "quest", false, "objective" }, classify("РАЗМОКШАЯ ПИЛА", { "Размокшая пила: 0/1" }))
			assert.same({ "quest", false, "objective" }, classify("Shiny junk", { "Shiny Junk: 3 / 8" }))
		end)

		it("match no short name, nor a name no objective holds", function()
			assert.same({ nil, "other" }, classify("Saw", { "Waterlogged Saw: 0/1" }))
			assert.same({ nil, "other" }, classify("Signpost", { "Waterlogged Saw: 0/1" }))
			-- An objective of four letters is in no name.
			assert.same({ nil, "other" }, classify("Wooden Box", { "Box: 0/1" }))
			assert.same({ nil, "other" }, classify(nil, { "Waterlogged Saw: 0/1" }))
			assert.same({ nil, "other" }, classify("Waterlogged Saw", {}))
		end)

		it("never make a mailbox, a vendor or the bobber a quest object, and leave a herb a herb", function()
			assert.same({ nil, "service" }, classify("Mailbox", { "Mailbox Key: 0/1" }, 9))
			assert.same({ nil, "bobber" }, classify("Fishing Bobber", { "Fishing Bobber: 0/1" }, 8))
			assert.same({ "herbs", false }, classify("Peacebloom", { "Peacebloom: 0/5" }, 3))
		end)

		it("come before a chest's cursor, the learned chests and the chest words", function()
			assert.same({ "quest", true, "objective" }, classify("Supply Crate", { "Supply Crate: 0/3" }, 6))
			known.chests[77] = true
			known.objectives = Objects.ObjectiveTexts({ "Strange Idol: 0/1" })
			assert.same({ "quest", false, "objective" }, { Objects.Classify(object({ name = "Strange Idol", objectID = 77, cursor = 10 }), known) })
		end)

		it("leave out short objectives and keep the others plain", function()
			assert.same({ "waterlogged saw", "shiny junk" }, Objects.ObjectiveTexts({ "Waterlogged Saw: 0/1", "- Shiny Junk 0/8", "Box: 0/1", 42 }))
		end)

		it("are not learned as chests when looted", function()
			local chests = {}
			assert.equals(1, Objects.Learn(chests, { 5, 6 }, { [6] = true }))
			assert.same({ [5] = true }, chests)
		end)
	end)

	describe("corpses to skin", function()
		local function corpse(cursor)
			return { Objects.Classify({ isObject = false, isDead = true, cursor = cursor, name = "Plainstrider" }, known) }
		end

		it("know a corpse that can be skinned now by the skinning cursor, and too little skill by the Unable one", function()
			assert.same({ "skinning", false }, corpse(11))
			assert.same({ "skinning", true }, corpse(12))
			assert.same({ "skinning", true }, corpse("Cursor Crosshair_UnableSkin_64"))
			assert.same({ "skinning", false }, corpse("Cursor Crosshair_Skin_64"))
		end)

		it("leave every other unit out: a corpse with loot, a dead player in PvP, a living one with the cursor", function()
			assert.same({ nil, "unit" }, corpse(5))
			assert.same({ nil, "unit" }, corpse(nil))
			assert.same({ nil, "unit" }, corpse(13))
			assert.same({ nil, "unit" }, corpse("Cursor Crosshair_SkinAlliance_64"))
			assert.same({ nil, "unit" }, { Objects.Classify({ isObject = false, isDead = false, cursor = 11 }, known) })
		end)

		it("make no game object a corpse", function()
			assert.same({ nil, "other" }, { Objects.Classify(object({ cursor = 11 }), known) })
		end)
	end)
end)
