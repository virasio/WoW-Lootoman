local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The bag button, with fake bag windows of the game.
describe("bag button", function()
	local ns, Junk, BagButton, combined, backpack, toggles

	local function start()
		ns = Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		BagButton = Junk.BagButton
		Junk.Toss = { Toggle = function(nextToLoot) toggles[#toggles + 1] = nextToLoot end }
	end

	local function bagWindow()
		local frame = UI.NewFake(Loader.ui.UIParent)
		frame.shown = false
		frame.CloseButton = UI.NewFake(frame)
		return frame
	end

	before_each(function()
		ns = Loader.LoadAddon()
		combined, backpack = bagWindow(), bagWindow()
		rawset(_G, "ContainerFrameCombinedBags", combined)
		rawset(_G, "ContainerFrame1", backpack)
		toggles = {}
	end)

	after_each(function()
		rawset(_G, "ContainerFrameCombinedBags", nil)
		rawset(_G, "ContainerFrame1", nil)
	end)

	it("is a small button in each bag window's title, left of its close button, and shows with the window", function()
		start()
		local button = BagButton.InBag(combined)
		assert.equals(combined, button.parent)
		assert.equals(backpack, BagButton.InBag(backpack).parent)
		assert.same({ { "RIGHT", combined.CloseButton, "LEFT", -2, 0 } }, button.points)
		assert.same({ 20, 20 }, { button.width, button.height })
		assert.is_true(button:IsShown())
		assert.is_false(button:IsVisible())
		combined:Show()
		assert.is_true(button:IsVisible())
		assert.is_false(BagButton.Own():IsShown())
	end)

	it("opens the toss window in the middle of the screen", function()
		start()
		BagButton.InBag(combined).scripts.OnClick(BagButton.InBag(combined))
		assert.same({ false }, toggles)
	end)

	it("is large above the bag window, or on its own, by the setting", function()
		start()
		Junk:Set("bagButton", "large")
		local button = BagButton.InBag(backpack)
		assert.same({ { "BOTTOMRIGHT", backpack, "TOPRIGHT", -4, BagButton.RAISE } }, button.points)
		assert.same({ 37, 37 }, { button.width, button.height })
		assert.is_true(button.slot:IsShown())
		Junk:Set("bagButton", "own")
		assert.same({ false, false }, { BagButton.InBag(combined):IsShown(), button:IsShown() })
		local own = BagButton.Own()
		assert.is_true(own:IsShown())
		assert.same({ 37, 37 }, { own.width, own.height })
		Junk:Set("bagButtonSize", 50)
		assert.same({ 50, 50 }, { own.width, own.height })
		own.scripts.OnClick(own)
		assert.same({ false }, toggles)
		Junk:Set("bagButton", "never")
		assert.same({ false, false, false }, { BagButton.InBag(combined):IsShown(), button:IsShown(), own:IsShown() })
	end)

	it("hides every button while the module is off", function()
		start()
		Junk:Set("bagButton", "own")
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(BagButton.Own():IsShown())
		ns.Modules:SetEnabled("Junk", true)
		assert.is_true(BagButton.Own():IsShown())
	end)

	it("gives only the button on its own to a client without the game's bag windows", function()
		rawset(_G, "ContainerFrameCombinedBags", nil)
		rawset(_G, "ContainerFrame1", nil)
		start()
		assert.is_nil(BagButton.InBag(combined))
		Junk:Set("bagButton", "own")
		assert.is_true(BagButton.Own():IsShown())
	end)
end)
