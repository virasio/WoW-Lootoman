local Loader = require("tests.helpers.loader")

describe("objects for gathering highlights", function()
	local Objects, known

	-- Made-up cursor file IDs, plain and "Unable".
	local FILES = { Mine = 1, UnableMine = 2, GatherHerbs = 3, UnableGatherHerbs = 4, PickLock = 5, UnablePickLock = 6,
		Quest = 7, Fishing = 8, Mail = 9, Interact = 10 }

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
		assert.same({ "quest", false }, kind(7))
		-- The fishing bobber, a mailbox, an unknown cursor: not highlighted.
		assert.same({ nil, "bobber" }, kind(8))
		assert.same({ nil, "service" }, kind(9))
		assert.same({ nil, "other" }, kind(10))
	end)

	it("reads a cursor given as a path or an atlas name", function()
		assert.same({ "ore", true }, { Objects.Classify(object({ cursor = "Cursor_Crosshair_UnableMine_64" }), known) })
		assert.same({ "herbs", false }, { Objects.Classify(object({ cursor = "Interface\\Cursor\\GatherHerbs" }), known) })
		assert.same({ "quest", false }, { Objects.Classify(object({ cursor = "Interface\\Cursor\\QuestInteract" }), known) })
	end)

	it("makes an object a quest wants a quest object, but a herb or a vein stays one", function()
		assert.same({ "quest", false }, { Objects.Classify(object({ cursor = 10, questRelated = true }), known) })
		assert.same({ "quest", false }, { Objects.Classify(object({ questObjective = true }), known) })
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

	it("learns the looted objects the soft target showed as other objects as chests, and nothing else", function()
		local chests = {}
		assert.equals(1, Objects.Learn(chests, { 3658, 1617 }, { [3658] = true }))
		assert.same({ [3658] = true }, chests)
		assert.equals(0, Objects.Learn(chests, { 3658 }, { [3658] = true }))
	end)
end)
