local Loader = require("tests.helpers.loader")

local HERBS, ORE = 32, 512

describe("Bags provider", function()
	local ns, Bags, Test

	-- A slot table with the given number of filled slots, all with one item.
	local function filled(count, itemID)
		local items = {}
		for slot = 1, count do
			items[slot] = { itemID = itemID or 1, count = 1 }
		end
		return items
	end

	-- Whether a stack fits now, on its own: a plan for one item.
	local function fits(item, count)
		return Bags.Plan():Take(item, count)
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Bags, Test = ns.Bags, ns.Compat.Test
		Test.SetItems({
			[1] = { name = "Filler", stackSize = 1 },
			[2589] = { name = "Linen Cloth", stackSize = 200, isCraftingReagent = true },
			[765] = { name = "Silverleaf", stackSize = 1000, family = HERBS, isCraftingReagent = true },
			[2770] = { name = "Copper Ore", stackSize = 1000, family = ORE, isCraftingReagent = true },
			[6948] = { name = "Hearthstone", stackSize = 1 },
			[3820] = { name = "Stranglekelp", stackSize = 20, family = HERBS, isCraftingReagent = true },
		})
	end)

	describe("fits", function()
		it("an item in a free general slot", function()
			Test.SetBags({ [0] = { size = 16, items = filled(15) } })
			assert.is_true(fits(6948))
		end)

		it("nothing when every bag is full", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36, items = filled(36) } })
			assert.is_false(fits(6948))
			assert.is_false(fits(2589))
		end)

		it("a stack into partial stacks of the same item, up to their room", function()
			local items = filled(14)
			items[15] = { itemID = 2589, count = 197 }
			items[16] = { itemID = 2589, count = 198 }
			Test.SetBags({ [0] = { size = 16, items = items } })
			assert.is_true(fits(2589, 5))
			assert.is_false(fits(2589, 6))
		end)

		it("herbs into a free herb bag when the general bags are full, but not ore or other items", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(fits(765, 3))
			assert.is_false(fits(2770))
			assert.is_false(fits(6948))
		end)

		it("crafting reagents into the reagent bag, but no other items", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36 } })
			assert.is_true(fits(2589, 20))
			assert.is_false(fits(6948))
		end)

		it("nothing into a reagent bag on a client without one", function()
			Test.state.reagentBag = nil
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36 } })
			assert.is_false(fits(2589))
		end)

		it("an item given by its link", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(fits("|cffffffff|Hitem:765::::::::80:::::|h[Silverleaf]|h|r"))
		end)

		it("a stack that fills a partial stack only with what does not fit there in a free slot", function()
			local items = filled(15)
			items[16] = { itemID = 3820, count = 18 }
			Test.SetBags({ [0] = { size = 16, items = items } })
			assert.is_true(fits(3820, 2))
			assert.is_false(fits(3820, 3))
			Test.SetBags({ [0] = { size = 17, items = items } })
			Test.FireEvent("BAG_UPDATE_DELAYED")
			assert.is_true(fits(3820, 3))
			assert.is_true(fits(3820, 22))
			assert.is_false(fits(3820, 23))
		end)

		it("a stack bigger than the item's stack size only with a free slot for each stack", function()
			Test.SetBags({ [0] = { size = 16, items = filled(14) } })
			assert.is_true(fits(2589, 400))
			assert.is_false(fits(2589, 401))
		end)

		it("an item the client has not loaded only into a general slot", function()
			Test.SetBags({ [0] = { size = 16, items = filled(15, 999) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(fits(999))
			Test.SetBags({ [0] = { size = 16, items = filled(16, 999) }, [1] = { size = 20, family = HERBS } })
			Test.FireEvent("BAG_UPDATE_DELAYED")
			assert.is_false(fits(999))
		end)
	end)

	describe("plan for one loot", function()
		it("reserves a free slot, so the next item does not count on it", function()
			Test.SetBags({ [0] = { size = 16, items = filled(15) } })
			local plan = Bags.Plan()
			assert.is_true(plan:Take(6948))
			assert.is_false(plan:Take(6948))
			assert.is_true(fits(6948))
		end)

		it("reserves the room in partial stacks and the stacks it starts", function()
			local items = filled(14)
			items[15] = { itemID = 3820, count = 18 }
			Test.SetBags({ [0] = { size = 16, items = items } })
			local plan = Bags.Plan()
			assert.is_true(plan:Take(3820, 3))
			assert.is_true(plan:Take(3820, 19))
			assert.is_false(plan:Take(3820, 1))
		end)

		it("puts items into the most specific bag first, leaving general slots to other items", function()
			Test.SetBags({
				[0] = { size = 16, items = filled(15) },
				[1] = { size = 1, family = HERBS },
				[5] = { size = 1 },
			})
			local plan = Bags.Plan()
			assert.is_true(plan:Take(3820))
			assert.is_true(plan:Take(2589))
			assert.is_true(plan:Take(6948))
			assert.is_false(plan:Take(3820, 21))
		end)
	end)

	it("reads the bags on first use and again after they change", function()
		assert.same({}, ns.Bus:GetEvents("Bags"))
		Test.SetBags({ [0] = { size = 16, items = filled(15) } })
		assert.is_true(fits(6948))
		assert.same({ "BAG_UPDATE_DELAYED" }, ns.Bus:GetEvents("Bags"))
		Test.SetBags({ [0] = { size = 16, items = filled(16) } })
		assert.is_true(fits(6948))
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.is_false(fits(6948))
	end)
end)
