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
		})
	end)

	it("counts free slots per bag type", function()
		Test.SetBags({
			[0] = { size = 16, items = filled(5) },
			[1] = { size = 12, items = filled(12) },
			[2] = { size = 20, family = HERBS, items = filled(2, 765) },
			[3] = { size = 10, family = HERBS },
			[5] = { size = 36, items = filled(10, 2589) },
		})
		assert.same({ total = 11 + 0 + 18 + 10 + 26, general = 11, reagent = 26, families = { [HERBS] = 28 } }, Bags.FreeSlots())
	end)

	describe("fits", function()
		it("an item in a free general slot", function()
			Test.SetBags({ [0] = { size = 16, items = filled(15) } })
			assert.is_true(Bags.Fits(6948))
		end)

		it("nothing when every bag is full", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36, items = filled(36) } })
			assert.is_false(Bags.Fits(6948))
			assert.is_false(Bags.Fits(2589))
		end)

		it("a stack into partial stacks of the same item, up to their room", function()
			local items = filled(14)
			items[15] = { itemID = 2589, count = 197 }
			items[16] = { itemID = 2589, count = 198 }
			Test.SetBags({ [0] = { size = 16, items = items } })
			assert.is_true(Bags.Fits(2589, 5))
			assert.is_false(Bags.Fits(2589, 6))
		end)

		it("herbs into a free herb bag when the general bags are full, but not ore or other items", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(Bags.Fits(765, 3))
			assert.is_false(Bags.Fits(2770))
			assert.is_false(Bags.Fits(6948))
		end)

		it("crafting reagents into the reagent bag, but no other items", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36 } })
			assert.is_true(Bags.Fits(2589, 20))
			assert.is_false(Bags.Fits(6948))
		end)

		it("nothing into a reagent bag on a client without one", function()
			Test.state.reagentBag = nil
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [5] = { size = 36 } })
			assert.is_false(Bags.Fits(2589))
			assert.equals(0, Bags.FreeSlots().reagent)
		end)

		it("an item given by its link", function()
			Test.SetBags({ [0] = { size = 16, items = filled(16) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(Bags.Fits("|cffffffff|Hitem:765::::::::80:::::|h[Silverleaf]|h|r"))
		end)

		it("an item the client has not loaded only into a general slot", function()
			Test.SetBags({ [0] = { size = 16, items = filled(15, 999) }, [1] = { size = 20, family = HERBS } })
			assert.is_true(Bags.Fits(999))
			Test.SetBags({ [0] = { size = 16, items = filled(16, 999) }, [1] = { size = 20, family = HERBS } })
			Test.FireEvent("BAG_UPDATE_DELAYED")
			assert.is_false(Bags.Fits(999))
		end)
	end)

	it("reads the bags on first use and again after they change", function()
		assert.same({}, ns.Bus:GetEvents("Bags"))
		Test.SetBags({ [0] = { size = 16 } })
		assert.equals(16, Bags.FreeSlots().general)
		assert.same({ "BAG_UPDATE_DELAYED" }, ns.Bus:GetEvents("Bags"))
		Test.SetBags({ [0] = { size = 16, items = filled(16) } })
		assert.equals(16, Bags.FreeSlots().general)
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.equals(0, Bags.FreeSlots().general)
	end)
end)
