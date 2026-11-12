local Loader = require("tests.helpers.loader")

-- Which items the character can use right now, of the kinds the loot feed keeps.
describe("usable items", function()
	local ns, Test, Usable

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test, Usable = ns.Compat.Test, ns.Rules.Usable
	end)

	-- One item in the backpack's first slot.
	local function holding(item)
		item.count = item.count or 1
		Test.SetBags({ [0] = { size = 16, items = { [1] = item } } })
		return Usable.Kind(0, 1)
	end

	it("knows an item that starts a quest not taken yet", function()
		assert.equals("quest", holding({ itemID = 1, use = { questID = 500 } }))
		assert.is_nil(holding({ itemID = 1, use = { questID = 500, questTaken = true } }))
	end)

	it("knows a recipe the character can learn and does not know", function()
		assert.equals("recipe", holding({ itemID = 2, use = { recipe = true } }))
		assert.is_nil(holding({ itemID = 2, use = { recipe = true, known = true } }))
		assert.is_nil(holding({ itemID = 2, use = { recipe = true, usable = false } }))
	end)

	it("knows a container the character can open now, a locked box only once picked", function()
		assert.equals("container", holding({ itemID = 3, use = { openable = true } }))
		assert.is_nil(holding({ itemID = 3, use = { openable = true, usable = false } }))
		assert.is_nil(holding({ itemID = 3 }))
	end)

	it("knows a pet, mount, toy, appearance set or heirloom not in the collection yet", function()
		local kinds = {}
		for index, kind in ipairs({ "pet", "mount", "toy", "set", "heirloom" }) do
			Test.SetItems({ [10 + index] = { name = kind, collectible = { kind = kind } } })
			kinds[index] = holding({ itemID = 10 + index })
		end
		assert.same({ "pet", "mount", "toy", "set", "heirloom" }, kinds)
		Test.SetItems({ [20] = { name = "Old mount", collectible = { kind = "mount", collected = true } } })
		assert.is_nil(holding({ itemID = 20 }))
	end)

	it("finds an item in the bags, or says the bags do not hold it yet", function()
		holding({ itemID = 1, use = { questID = 500 } })
		assert.same({ "quest", true }, { Usable.Find(1) })
		assert.same({ nil, false }, { Usable.Find(99) })
	end)

	it("offers only the kinds of collection the client has", function()
		assert.same({ "quest", "recipe", "container", "pet", "mount", "toy", "set", "heirloom" }, Usable.Kinds())
		Test.state.collections = { mount = true, toy = true }
		assert.same({ "quest", "recipe", "container", "mount", "toy" }, Usable.Kinds())
		Test.SetItems({ [30] = { name = "Pet", collectible = { kind = "pet" } } })
		assert.is_nil(holding({ itemID = 30 }))
	end)
end)
