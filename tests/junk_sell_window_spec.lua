local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The sell window next to a fake merchant frame.
describe("sell window", function()
	local ns, Junk, SellWindow, Test, MerchantFrame

	local function item(itemID, quality, count)
		return { itemID = itemID, link = "item:" .. itemID, name = "Item " .. itemID, quality = quality, count = count or 1 }
	end

	local function used()
		local list = {}
		for _, action in ipairs(Test.state.bagActions) do
			if action[1] == "use" then
				list[#list + 1] = ("%d:%d"):format(action[2], action[3])
			end
		end
		return list
	end

	local function grid()
		return SellWindow.Grid()
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		MerchantFrame = UI.NewFake(Loader.ui.UIParent)
		rawset(_G, "MerchantFrame", MerchantFrame)
		Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		SellWindow = Junk.SellWindow
		local items = {}
		for itemID = 1, 20 do
			items[itemID] = { name = "Item " .. itemID, sellPrice = itemID }
		end
		Test.SetItems(items)
		Test.SetBags({
			[0] = { size = 4, items = { [1] = item(1, 0), [2] = item(2, 0), [3] = item(3, 1, 5) } },
			[1] = { size = 2, items = { [1] = item(4, 0) }, keptFromJunkSale = true },
		})
		Test.SetInteracting("Merchant", true)
		SellWindow.Open()
	end)

	after_each(function()
		rawset(_G, "MerchantFrame", nil)
	end)

	it("opens to the right of the merchant's window and closes with it", function()
		assert.is_true(grid().frame:IsShown())
		assert.same({ { "TOPLEFT", MerchantFrame, "TOPRIGHT", 4, 0 } }, grid().frame.points)
		Test.SetInteracting("Merchant", false)
		assert.is_false(grid().frame:IsShown())
		SellWindow.Open()
		assert.is_false(grid().frame:IsShown())
	end)

	it("sells the upper section with Sell junk, less the bags kept from junk selling, and closes", function()
		grid().sellButton.scripts.OnClick(grid().sellButton)
		assert.is_false(grid().frame:IsShown())
		assert.is_false(grid().sellButton:IsEnabled())
		for _ = 1, 2 do
			local last = Test.state.bagActions[#Test.state.bagActions]
			Test.FinishSale(last[2], last[3])
			Test.Advance(Junk.SellQueue.PACE * 3)
		end
		assert.same({ "0:1", "0:2" }, used())
		assert.equals("done", Junk.SellQueue.State())
		-- Opened again: nothing left to sell.
		SellWindow.Open()
		assert.is_false(grid().sellButton:IsEnabled())
	end)

	it("moves an item between the sections with a right click, and sells nothing that way", function()
		local rest = grid().sections.rest.buttons[1]
		rest.scripts.OnClick(rest, "RightButton")
		assert.equals("junk", ns.Marks.Get(3))
		assert.same({}, used())
	end)

	it("does nothing with an item dropped outside it", function()
		local junk = grid().sections.junk.buttons[1]
		junk.scripts.OnDragStart(junk)
		grid().frame.mouseOver = false
		junk.scripts.OnDragStop(junk)
		assert.same({ {}, {} }, { used(), ns.Marks.List() })
		assert.is_not_nil(Test.state.bags[0].items[1])
	end)

	it("warns when there is more junk than the merchant can buy back", function()
		assert.is_false(grid().warning:IsShown())
		local items = {}
		for slot = 1, 13 do
			items[slot] = item(slot, 0)
		end
		Test.SetBags({ [0] = { size = 16, items = items } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.is_true(grid().warning:IsShown())
	end)
end)
