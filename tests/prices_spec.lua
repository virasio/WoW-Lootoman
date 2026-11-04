local Loader = require("tests.helpers.loader")

-- Prices, and Auctionator in the four states an integration can be in.
describe("prices", function()
	local ns, Prices, Test, calls

	local CLOTH = { itemID = 2589, link = "item:2589", count = 20 }
	local SWORD = { itemID = 1000, link = "item:1000", count = 1 }
	local JUNK = { itemID = 2000, link = "item:2000", count = 3 }
	local QUEST = { itemID = 3000, link = "item:3000", count = 1, noValue = true }

	-- Auctionator's API v1 as Auctionator 341 has it: prices by link, and the
	-- same checks of its arguments.
	local function installAuctionator(prices)
		calls = {}
		rawset(_G, "Auctionator", { API = { v1 = {
			GetAuctionPriceByItemLink = function(callerID, itemLink)
				if type(callerID) ~= "string" or callerID == "" then
					error("Invalid callerID. Use the name of your add-on.")
				end
				if type(itemLink) ~= "string" then
					error("Usage Auctionator.API.v1.GetAuctionPriceByItemLink(string, string)")
				end
				calls[#calls + 1] = { callerID, itemLink }
				return prices[itemLink]
			end,
		} } })
		Test.state.addons.Auctionator = true
	end

	local function report()
		Test.state.printed = {}
		ns.SelfTest.Run()
		for _, line in ipairs(Test.state.printed) do
			local found = line:match("Auctionator: .*")
			if found then
				return found
			end
		end
	end

	before_each(function()
		rawset(_G, "Auctionator", nil)
		ns = Loader.Start(Loader.LoadAddon())
		Prices, Test = ns.Prices, ns.Compat.Test
		Test.SetItems({
			[2589] = { name = "Linen Cloth", sellPrice = 13 },
			[1000] = { name = "Sword", sellPrice = 5000 },
			[2000] = { name = "Broken Tooth", sellPrice = 7 },
			[3000] = { name = "Letter", sellPrice = 0 },
		})
	end)

	after_each(function()
		rawset(_G, "Auctionator", nil)
	end)

	it("from a merchant are the stack's price, and none for an item no merchant buys", function()
		assert.same({ 260, 5000, 21 }, { Prices.Vendor(CLOTH), Prices.Vendor(SWORD), Prices.Vendor(JUNK) })
		assert.is_nil(Prices.Vendor(QUEST))
		assert.is_nil(Prices.Vendor({ itemID = 4000, link = "item:4000", count = 1 }))
	end)

	describe("with Auctionator", function()
		it("not installed come from merchants", function()
			assert.same({ nil, 260 }, { Prices.Auction(CLOTH), Prices.Worth(CLOTH) })
			assert.equals("Auctionator: not installed", report())
		end)

		it("loaded without its API come from merchants", function()
			Test.state.addons.Auctionator = true
			rawset(_G, "Auctionator", { API = {} })
			assert.same({ nil, 260 }, { Prices.Auction(CLOTH), Prices.Worth(CLOTH) })
			assert.matches("without API v1", report())
		end)

		it("working are the better of the merchant's and the auction's after its cut", function()
			installAuctionator({ ["item:2589"] = 100, ["item:1000"] = 4000 })
			assert.same({ 2000, 1900, 5000, 21 }, { Prices.Auction(CLOTH), Prices.Worth(CLOTH), Prices.Worth(SWORD), Prices.Worth(JUNK) })
			assert.same({ "Lootoman", "item:2589" }, calls[1])
			assert.equals("Auctionator: working", report())
		end)

		it("working give a bound item no auction price, as it cannot be sold there", function()
			installAuctionator({ ["item:1000"] = 900000 })
			local bound = { itemID = 1000, link = "item:1000", count = 1, bound = true }
			assert.same({ nil, 5000 }, { Prices.Auction(bound), Prices.Worth(bound) })
			assert.same({}, calls)
		end)

		it("raising an error come from merchants until the next login, and the self-test says why", function()
			installAuctionator({})
			rawget(_G, "Auctionator").API.v1.GetAuctionPriceByItemLink = function()
				error("database is broken")
			end
			assert.same({ nil, 260 }, { Prices.Auction(CLOTH), Prices.Worth(CLOTH) })
			assert.matches("off after an error: .*database is broken", report())
			-- No more calls after the error.
			rawget(_G, "Auctionator").API.v1.GetAuctionPriceByItemLink = function()
				calls[#calls + 1] = "called"
				return 1
			end
			assert.is_nil(Prices.Auction(CLOTH))
			assert.same({}, calls)
			assert.same({}, Test.state.errors)
		end)
	end)

	it("may change after the auction house closes", function()
		local changed = 0
		ns.Bus:On("PricesChanged", "test", function() changed = changed + 1 end)
		Prices.Auction(CLOTH)
		Test.FireEvent("AUCTION_HOUSE_CLOSED")
		assert.equals(1, changed)
	end)
end)
