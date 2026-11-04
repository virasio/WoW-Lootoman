local Loader = require("tests.helpers.loader")

describe("Inventory provider", function()
	local ns, Inventory, Test, reads, factReads

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon())
		Inventory, Test = ns.Inventory, ns.Compat.Test
		Test.SetBags({
			[0] = { size = 4, items = {
				[1] = { itemID = 6948, count = 1, link = "item:6948", name = "Hearthstone", quality = 1 },
				[3] = { itemID = 2589, count = 20, link = "item:2589", name = "Linen Cloth", quality = 1 },
			}, protections = { [1] = { quest = true } } },
			[1] = { size = 2, family = 32, items = { [2] = { itemID = 765, count = 5, link = "item:765" } } },
			[5] = { size = 3, items = { [1] = { itemID = 2589, count = 7, link = "item:2589", locked = true } } },
		})
		-- Counts the client's answers.
		local Compat = ns.Compat
		local getItem, getFacts = Compat.GetBagItem, Compat.GetBagItemFacts
		reads, factReads = 0, 0
		Compat.GetBagItem = function(...)
			reads = reads + 1
			return getItem(...)
		end
		Compat.GetBagItemFacts = function(...)
			factReads = factReads + 1
			return getFacts(...)
		end
	end)

	local function places(items)
		local list = {}
		for index, item in ipairs(items) do
			list[index] = ("%d:%d %d x%d"):format(item.bag, item.slot, item.itemID, item.count)
		end
		return list
	end

	it("lists the items bag by bag and slot by slot, the reagent bag last", function()
		assert.same({ "0:1 6948 x1", "0:3 2589 x20", "1:2 765 x5", "5:1 2589 x7" }, places(Inventory.Items()))
		local item = Inventory.Items()[4]
		assert.same({ true, false, false }, { item.locked, item.bound, item.noValue })
	end)

	it("lists every bag slot with its size, free slots and family", function()
		local list = {}
		for index, bag in ipairs(Inventory.Bags()) do
			list[index] = ("%d: %d/%d f%d%s"):format(bag.bag, bag.free, bag.size, bag.family, bag.reagent and " reagent" or "")
		end
		assert.same({ "0: 2/4 f0", "1: 1/2 f32", "2: 0/0 f0", "3: 0/0 f0", "4: 0/0 f0", "5: 2/3 f0 reagent" }, list)
	end)

	it("reads the bags once per change, and says when they changed", function()
		local changed = 0
		ns.Bus:On("InventoryChanged", "test", function() changed = changed + 1 end)
		Inventory.Items()
		local once = reads
		Inventory.Items()
		Inventory.Bags()
		assert.same({ 9, 9, 0 }, { once, reads, changed })
		Test.SetBags({ [0] = { size = 4, items = { [2] = { itemID = 6948, count = 1 } } } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.same({ 1, 9 }, { changed, reads })
		assert.same({ "0:2 6948 x1" }, places(Inventory.Items()))
	end)

	it("reads an item's protections only when asked, once", function()
		local items = Inventory.Items()
		assert.equals(0, factReads)
		assert.same({ true, false }, { Inventory.Facts(items[1]).quest, Inventory.Facts(items[2]).quest })
		Inventory.Facts(items[1])
		assert.equals(2, factReads)
		assert.equals("0:3:2589", Inventory.Facts(items[2]).guid)
	end)

	it("tells whether a slot still holds the listed item", function()
		local items = Inventory.Items()
		local cloth = items[2]
		assert.is_true(Inventory.StillThere(cloth))
		-- Another stack of the same item moved into the slot.
		Test.state.bags[0].items[3].guid = "another"
		assert.is_false(Inventory.StillThere(cloth))
		Test.state.bags[0].items[3].guid = nil
		-- The stack grew: same item, same guid.
		Test.state.bags[0].items[3].count = 25
		assert.is_false(Inventory.StillThere(cloth))
		Test.state.bags[0].items[3].count = 20
		assert.is_true(Inventory.StillThere(cloth))
		Test.state.bags[0].items[3].locked = true
		assert.is_false(Inventory.StillThere(cloth))
		Test.state.bags[0].items[3] = nil
		assert.is_false(Inventory.StillThere(cloth))
	end)
end)
