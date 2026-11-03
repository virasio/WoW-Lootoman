local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- Lootoman's sell-junk button over a fake of Blizzard's.
describe("sell-junk button", function()
	local ns, Junk, Test, MerchantFrame, Blizzard, shift, opened

	local function gray(itemID)
		return { itemID = itemID, link = "item:" .. itemID, name = "Junk " .. itemID, quality = 0, count = 1 }
	end

	local function button()
		return Junk.SellButton.Button()
	end

	local function uses()
		local count = 0
		for _, action in ipairs(Test.state.bagActions) do
			count = count + (action[1] == "use" and 1 or 0)
		end
		return count
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		MerchantFrame = UI.NewFake(Loader.ui.UIParent)
		Blizzard = UI.NewFake(MerchantFrame)
		Blizzard.level = 5
		rawset(_G, "MerchantFrame", MerchantFrame)
		rawset(_G, "MerchantSellAllJunkButton", Blizzard)
		shift = false
		rawset(_G, "IsShiftKeyDown", function() return shift end)
		Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		opened = 0
		Junk.SellWindow = { Open = function() opened = opened + 1 end }
		Test.SetItems({ [1] = { name = "Junk 1", sellPrice = 3 }, [2] = { name = "Junk 2", sellPrice = 4 } })
		Test.SetBags({ [0] = { size = 4, items = { [1] = gray(1), [2] = gray(2) } } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
	end)

	after_each(function()
		for _, name in ipairs({ "MerchantFrame", "MerchantSellAllJunkButton", "IsShiftKeyDown" }) do
			rawset(_G, name, nil)
		end
	end)

	it("lies over Blizzard's button and shows and hides with it, which it never touches", function()
		local frame = button()
		assert.same({ MerchantFrame, Blizzard, 6 }, { frame.parent, frame.allPoints, frame.level })
		Blizzard:Hide()
		assert.is_false(frame:IsShown())
		Blizzard:Show()
		assert.is_true(frame:IsShown())
		assert.same({}, Blizzard.scripts)
	end)

	it("sells the junk on a click, and opens the sell window too on Shift-click", function()
		Junk:Set("sellOnOpen", false)
		Test.SetInteracting("Merchant", true)
		Test.Advance(1)
		assert.equals(0, uses())
		button().scripts.OnClick(button())
		assert.same({ 1, 0 }, { uses(), opened })
		Junk.SellQueue.Stop("closed")
		shift = true
		button().scripts.OnClick(button())
		assert.equals(1, opened)
	end)

	it("swaps click and Shift-click by the setting", function()
		Junk:Set("swapClicks", true)
		button().scripts.OnClick(button())
		assert.equals(1, opened)
		shift = true
		button().scripts.OnClick(button())
		assert.equals(1, opened)
	end)

	it("sells the junk when a merchant's window opens, unless that is off", function()
		Test.SetInteracting("Merchant", true)
		Test.Advance(0)
		assert.equals(1, uses())
		Junk.SellQueue.Stop("closed")
		Test.SetInteracting("Merchant", false)
		Junk:Set("sellOnOpen", false)
		Test.SetInteracting("Merchant", true)
		Test.Advance(0)
		assert.equals(1, uses())
	end)

	it("greys its icon when there is no junk to sell", function()
		assert.is_false(button().icon.desaturated)
		Test.SetBags({ [0] = { size = 4 } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.is_true(button().icon.desaturated)
	end)

	it("hides with the module, leaving Blizzard's button as it was", function()
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(button():IsShown())
		Blizzard:Hide()
		Blizzard:Show()
		assert.is_false(button():IsShown())
		assert.is_true(Blizzard:IsShown())
	end)

	it("is not made on a client without Blizzard's button", function()
		rawset(_G, "MerchantSellAllJunkButton", nil)
		ns = Loader.Start(Loader.LoadAddon())
		assert.is_nil(ns.Modules:Get("Junk").SellButton.Button())
		assert.same({}, ns.Compat.Test.state.errors)
	end)
end)
