local Loader = require("tests.helpers.loader")

-- The toss and sell windows' two sections.
describe("junk sections", function()
	local ns, Sections, Test

	local function names(section)
		local list = {}
		for index, entry in ipairs(section.entries) do
			list[index] = ("%s %d"):format(entry.item.name, entry.price)
		end
		return list
	end

	local function item(itemID, name, quality, count, extra)
		local entry = { itemID = itemID, link = "item:" .. itemID, name = name, quality = quality, count = count or 1 }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	before_each(function()
		rawset(_G, "Auctionator", nil)
		ns = Loader.Start(Loader.LoadAddon())
		Sections, Test = ns.Modules:Get("Junk").Sections, ns.Compat.Test
		Test.SetItems({
			[1] = { name = "Broken Tooth", sellPrice = 7 },
			[2] = { name = "Cracked Bone", sellPrice = 3 },
			[3] = { name = "Linen Cloth", sellPrice = 13 },
			[4] = { name = "Sword", sellPrice = 5000 },
			[5] = { name = "Letter", sellPrice = 0 },
			[6] = { name = "Tank Helm", sellPrice = 900 },
			[7] = { name = "Vendor Pet", sellPrice = 100 },
			[8] = { name = "Ancient Coin", sellPrice = 50 },
		})
		Test.SetBags({
			[0] = { size = 8, items = {
				[1] = item(1, "Broken Tooth", 0, 3),
				[2] = item(2, "Cracked Bone", 0, 1),
				[3] = item(3, "Linen Cloth", 1, 20),
				[4] = item(4, "Sword", 2, 1),
				[5] = item(5, "Letter", 1, 1, { noValue = true }),
				[6] = item(6, "Tank Helm", 3, 1),
				[7] = item(7, "Vendor Pet", 1, 1),
				[8] = item(8, "Ancient Coin", 0, 1),
			}, protections = { [5] = { quest = true }, [6] = { equipmentSet = true }, [7] = { refundable = true } } },
			[1] = { size = 2, items = { [1] = item(2, "Cracked Bone", 0, 1) }, keptFromJunkSale = true },
		})
	end)

	after_each(function()
		rawset(_G, "Auctionator", nil)
	end)

	it("put the junk on top and everything else below, each cheapest first, with totals", function()
		local sections = Sections.Build("toss")
		assert.same({ "Cracked Bone 3", "Cracked Bone 3", "Broken Tooth 21", "Ancient Coin 50" }, names(sections.junk))
		assert.same({ "Vendor Pet 100", "Linen Cloth 260", "Sword 5000" }, names(sections.rest))
		assert.same({ 77, 5360 }, { sections.junk.total, sections.rest.total })
	end)

	it("never list quest items and items in equipment sets", function()
		for _, kind in ipairs({ "toss", "sell" }) do
			for _, section in ipairs({ "junk", "rest" }) do
				for _, entry in ipairs(Sections.Build(kind)[section].entries) do
					assert.is_false(entry.item.name == "Letter" or entry.item.name == "Tank Helm", entry.item.name)
				end
			end
		end
	end)

	it("for selling leave out refundable items and what no merchant buys, and price by the merchant", function()
		rawset(_G, "Auctionator", { API = { v1 = { GetAuctionPriceByItemLink = function() return 1000 end } } })
		Test.state.addons.Auctionator = true
		local sell = Sections.Build("sell")
		assert.same({ "Linen Cloth 260", "Sword 5000" }, names(sell.rest))
		assert.same({ "Cracked Bone 3", "Cracked Bone 3", "Broken Tooth 21", "Ancient Coin 50" }, names(sell.junk))
		-- The toss window prices what deleting loses: the auction price after its cut.
		assert.same({ "Ancient Coin 950", "Cracked Bone 950", "Cracked Bone 950", "Broken Tooth 2850" }, names(Sections.Build("toss").junk))
	end)

	it("follow the marks", function()
		ns.Marks.Set(3, "junk")
		ns.Marks.Set(8, "notJunk")
		local sections = Sections.Build("toss")
		assert.same({ "Cracked Bone 3", "Cracked Bone 3", "Broken Tooth 21", "Linen Cloth 260" }, names(sections.junk))
		assert.same({ "Ancient Coin 50", "Vendor Pet 100", "Sword 5000" }, names(sections.rest))
		assert.same({ "marked", "gray" }, { sections.junk.entries[4].decision.reason, sections.junk.entries[1].decision.reason })
	end)

	it("sort equal prices by name, then by bag and slot", function()
		local junk = Sections.Build("toss").junk.entries
		assert.same({ 0, 2, 1, 1 }, { junk[1].item.bag, junk[1].item.slot, junk[2].item.bag, junk[2].item.slot })
	end)

	it("sell only junk outside the bags left out of junk selling", function()
		local sale = Sections.SaleList()
		local list = {}
		for index, entry in ipairs(sale) do
			list[index] = ("%d:%d"):format(entry.item.bag, entry.item.slot)
		end
		assert.same({ "0:2", "0:1", "0:8" }, list)
		assert.is_true(Sections.Build("sell").junk.entries[2].kept)
	end)

	it("are summed up in the self-test", function()
		ns.Marks.Set(3, "junk")
		ns.Marks.Set(8, "notJunk")
		Test.state.printed = {}
		ns.SelfTest.Run()
		local found
		for _, line in ipairs(Test.state.printed) do
			found = found or line:match("Junk: .*")
		end
		assert.equals("Junk: 3 stacks to sell for 284 copper (1 in bags kept from junk selling); marks: 1 junk, 1 not junk", found)
	end)
end)
