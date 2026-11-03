local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The toss button on Blizzard's loot window, with a fake LootFrame.
describe("toss button", function()
	local ns, Junk, Test, LootFrame, opened

	local function start()
		ns = Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		Junk.Toss = { Toggle = function() opened = opened + 1 end }
	end

	local function button()
		return Junk.TossButton.Button()
	end

	-- The bags: free general slots, and room in a herb bag that does not count.
	local function bags(freeGeneral)
		local items = {}
		for slot = 1, 4 - freeGeneral do
			items[slot] = { itemID = 1, count = 1 }
		end
		Test.SetBags({ [0] = { size = 4, items = items }, [1] = { size = 10, family = 32 } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		LootFrame = UI.NewFake(Loader.ui.UIParent, "HIGH")
		LootFrame.shown = false
		LootFrame.ClosePanelButton = UI.NewFake(LootFrame)
		rawset(_G, "LootFrame", LootFrame)
		opened = 0
		bags(2)
	end)

	after_each(function()
		rawset(_G, "LootFrame", nil)
	end)

	it("is a child of the loot window and shows with it when the bags are full", function()
		start()
		assert.equals(LootFrame, button().parent)
		LootFrame:Show()
		assert.is_false(button():IsShown())
		LootFrame:Hide()
		bags(0)
		LootFrame:Show()
		assert.is_true(button():IsShown())
		LootFrame:Hide()
		assert.is_false(button():IsShown())
	end)

	it("shows when something of the loot did not fit, until the loot closes", function()
		start()
		ns.Bus:Send("LootSkipped", { link = "item:1" })
		LootFrame:Show()
		assert.is_true(button():IsShown())
		LootFrame:Hide()
		Test.FireEvent("LOOT_CLOSED")
		LootFrame:Show()
		assert.is_false(button():IsShown())
	end)

	it("shows always, or never, by the setting", function()
		start()
		Junk:Set("tossButton", "always")
		LootFrame:Show()
		assert.is_true(button():IsShown())
		Junk:Set("tossButton", "never")
		assert.is_false(button():IsShown())
		bags(0)
		LootFrame:Hide()
		LootFrame:Show()
		assert.is_false(button():IsShown())
	end)

	it("sits small left of the close button, or large outside on the chosen side", function()
		start()
		local frame = button()
		assert.same({ { "RIGHT", LootFrame.ClosePanelButton, "LEFT", -2, 0 } }, frame.points)
		assert.same({ 20, 20, false }, { frame.width, frame.height, frame.slot.shown })
		Junk:Set("tossStyle", "large")
		Junk:Set("tossSize", 48)
		Junk:Set("tossOffset", 10)
		assert.same({ { "TOPLEFT", LootFrame, "TOPRIGHT", 4, -10 } }, frame.points)
		assert.same({ 48, 48, true }, { frame.width, frame.height, frame.slot.shown })
		local expected = {
			left = { "TOPRIGHT", LootFrame, "TOPLEFT", -4, -10 },
			top = { "BOTTOMLEFT", LootFrame, "TOPLEFT", 10, 4 },
			bottom = { "TOPLEFT", LootFrame, "BOTTOMLEFT", 10, -4 },
		}
		for side, point in pairs(expected) do
			Junk:Set("tossSide", side)
			assert.same({ point }, frame.points, side)
		end
	end)

	it("opens the toss window, except in Edit Mode, where it only shows its place", function()
		start()
		Junk:Set("tossButton", "always")
		LootFrame:Show()
		button().scripts.OnClick(button())
		assert.equals(1, opened)
		LootFrame:Hide()
		Junk:Set("tossButton", "full")
		LootFrame.isInEditMode = true
		LootFrame:Show()
		assert.is_true(button():IsShown())
		button().scripts.OnClick(button())
		assert.equals(1, opened)
	end)

	it("hides with the module, and is not made on a client without the loot window", function()
		start()
		Junk:Set("tossButton", "always")
		LootFrame:Show()
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(button():IsShown())
		LootFrame:Hide()
		LootFrame:Show()
		assert.is_false(button():IsShown())

		rawset(_G, "LootFrame", nil)
		ns = Loader.LoadAddon()
		start()
		assert.is_nil(button())
		assert.same({}, ns.Compat.Test.state.errors)
	end)

	it("sits at the top right of a loot window without a close button", function()
		-- false, not nil: the UI fake answers an unset method name with a function.
		LootFrame.ClosePanelButton = false
		start()
		assert.same({ { "TOPRIGHT", LootFrame, "TOPRIGHT", -24, -2 } }, button().points)
		assert.same({}, ns.Compat.Test.state.errors)
	end)
end)
