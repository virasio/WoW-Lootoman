local Loader = require("tests.helpers.loader")

-- Selling junk, against the fake client's merchant: a sold stack locks until
-- the server takes it (Test.FinishSale).
describe("sale queue", function()
	local ns, Junk, SellQueue, Test

	local function gray(itemID, count)
		-- A link the fake client finds the item by.
		return { itemID = itemID, link = ("item:%d[Junk %d]"):format(itemID, itemID), name = "Junk " .. itemID, quality = 0, count = count or 1 }
	end

	local function uses()
		local list = {}
		for _, action in ipairs(Test.state.bagActions) do
			if action[1] == "use" then
				list[#list + 1] = ("%d:%d%s"):format(action[2], action[3], action.merchant and "" or " without a merchant")
			end
		end
		return list
	end

	-- The server takes the stack sold last.
	local function serve()
		local actions = Test.state.bagActions
		local last = actions[#actions]
		Test.FinishSale(last[2], last[3])
	end

	local function printed()
		return Test.state.printed[#Test.state.printed]
	end

	local function stacks(count)
		local items = {}
		for slot = 1, count do
			items[slot] = gray(slot, 2)
		end
		return items
	end

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon())
		Junk, Test = ns.Modules:Get("Junk"), ns.Compat.Test
		SellQueue = Junk.SellQueue
		local items = {}
		for itemID = 1, 20 do
			items[itemID] = { name = "Junk " .. itemID, sellPrice = itemID }
		end
		Test.SetItems(items)
		Test.SetBags({ [0] = { size = 20, items = stacks(3) } })
		Test.SetInteracting("Merchant", true)
	end)

	local function start()
		return SellQueue.Start(Junk.Sections.SaleList())
	end

	it("sells one stack at a time, the next one after the server took the last and the pace passed", function()
		assert.is_true(start())
		assert.same({ "0:1" }, uses())
		assert.equals("waiting", SellQueue.State())
		Test.Advance(1)
		assert.same({ "0:1" }, uses())
		serve()
		Test.Advance(SellQueue.PACE)
		assert.same({ "0:1" }, uses())
		Test.Advance(SellQueue.PACE)
		assert.same({ "0:1", "0:2" }, uses())
		serve()
		Test.Advance(SellQueue.PACE * 3)
		serve()
		Test.Advance(SellQueue.PACE * 3)
		assert.same({ "done" }, { SellQueue.State() })
		assert.equals("Sold 3 items for 12 copper.", printed():match("Sold.*"))
		assert.same({ count = 3, money = 12 }, { count = SellQueue.LastResult().count, money = SellQueue.LastResult().money })
		assert.equals(12, Test.state.money)
	end)

	it("counts a sale whichever of the server's answers comes first", function()
		start()
		-- The bags update before the slot empties; then the slot empties with no event.
		Test.FireEvent("BAG_UPDATE_DELAYED")
		Test.Advance(SellQueue.PACE)
		assert.equals("waiting", SellQueue.State())
		Test.state.bags[0].items[1] = nil
		Test.Advance(SellQueue.PACE * 3)
		assert.same({ "0:1", "0:2" }, uses())
	end)

	it("stops when the merchant's window closes between two stacks, and uses nothing without a merchant", function()
		start()
		serve()
		Test.SetInteracting("Merchant", false)
		Test.Advance(1)
		assert.same({ "stopped", "closed" }, { SellQueue.State() })
		assert.same({ "0:1" }, uses())
		assert.matches("closed", printed())
		assert.matches("Sold 1 items", Test.state.printed[#Test.state.printed - 1])
	end)

	it("stops when no merchant is open any more, even without the event", function()
		start()
		serve()
		Test.state.interacting.Merchant = nil
		Test.Advance(1)
		assert.same({ "stopped", "closed" }, { SellQueue.State() })
		assert.same({ "0:1" }, uses())
	end)

	it("stops at the game's trade-timer question and leaves the question to the player", function()
		start()
		Test.FireEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL", "[Junk 1]")
		serve()
		Test.Advance(1)
		assert.same({ "stopped", "tradeTimer" }, { SellQueue.State() })
		assert.same({ "0:1" }, uses())
	end)

	it("stops when a slot no longer holds its item", function()
		start()
		Test.state.bags[0].items[2].guid = "another"
		serve()
		Test.Advance(1)
		assert.same({ "stopped", "changed" }, { SellQueue.State() })
		assert.same({ "0:1" }, uses())
	end)

	it("skips a stack that stopped being junk for sale while the sale went on", function()
		start()
		-- The player moves the second stack out of the junk, protects the third.
		ns.Marks.Set(2, "notJunk")
		Test.state.bags[0].protections = { [3] = { equipmentSet = true } }
		Test.state.bags[0].items[4] = gray(4, 2)
		Test.FireEvent("BAG_UPDATE_DELAYED")
		serve()
		Test.Advance(1)
		assert.same({ "0:1" }, uses())
		assert.equals("done", SellQueue.State())
	end)

	it("skips junk whose bag was left out of junk selling during the sale", function()
		start()
		Test.state.bags[0].keptFromJunkSale = true
		serve()
		Test.Advance(1)
		assert.same({ { "0:1" }, "done" }, { uses(), SellQueue.State() })
	end)

	it("stops when the merchant does not take a stack, or the server does not answer", function()
		start()
		Test.state.bags[0].items[1].locked = false
		Test.Advance(SellQueue.PACE)
		assert.same({ "stopped", "refused" }, { SellQueue.State() })
		assert.same({ 0 }, { SellQueue.LastResult().count })
		Test.state.bags[0].items[1].locked = false
		start()
		Test.Advance(SellQueue.TIMEOUT + SellQueue.PACE)
		assert.same({ "stopped", "noAnswer" }, { SellQueue.State() })
	end)

	it("starts only at a merchant, with something to sell, and not twice", function()
		assert.is_false(SellQueue.Start({}))
		Test.SetInteracting("Merchant", false)
		assert.is_false(start())
		Test.SetInteracting("Merchant", true)
		assert.is_true(start())
		assert.is_false(start())
		assert.same({ "0:1" }, uses())
	end)

	it("warns once a visit when more stacks are sold than the merchant can buy back", function()
		Test.SetBags({ [0] = { size = 20, items = stacks(13) } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		start()
		for _ = 1, 13 do
			serve()
			Test.Advance(SellQueue.PACE * 3)
		end
		assert.equals("done", SellQueue.State())
		assert.matches("last 12", printed())
		Test.SetBags({ [0] = { size = 20, items = stacks(1) } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		start()
		serve()
		Test.Advance(SellQueue.PACE * 3)
		assert.matches("Sold 1 items", printed())
		Test.SetInteracting("Merchant", false)
		Test.SetInteracting("Merchant", true)
		Test.SetBags({ [0] = { size = 20, items = stacks(1) } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		start()
		serve()
		Test.Advance(SellQueue.PACE * 3)
		assert.matches("Sold 1 items", printed())
	end)

	it("keeps the session's log over a reload, clears it at login, and lists it", function()
		start()
		serve()
		Test.Advance(SellQueue.PACE * 3)
		SellQueue.Stop("closed")
		Test.FireEvent("PLAYER_ENTERING_WORLD", false, true)
		assert.equals(1, #SellQueue.Log())
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "sales")
		assert.same({ "[Junk 1] ×2: 2 copper", "This session: 1 items for 2 copper." }, {
			Test.state.printed[1]:match("%[.*"), Test.state.printed[2]:match("This.*") })
		Test.FireEvent("PLAYER_ENTERING_WORLD", true, false)
		assert.same({}, SellQueue.Log())
		Test.RunSlashCommand("LOOTOMAN", "sales")
		assert.matches("Nothing was sold", printed())
	end)

	it("reports the last sale in the self-test", function()
		start()
		serve()
		Test.Advance(SellQueue.PACE)
		Test.SetInteracting("Merchant", false)
		Test.state.printed = {}
		ns.SelfTest.Run()
		local found
		for _, line in ipairs(Test.state.printed) do
			found = found or line:match("Last sale: .*")
		end
		assert.equals("Last sale: 1 stacks, 2 copper, closed", found)
	end)
end)
