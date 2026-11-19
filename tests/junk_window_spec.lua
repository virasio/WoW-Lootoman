local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The one junk window: its modes, where it opens and when it closes.
describe("junk window", function()
	local ns, Junk, Window, Test, LootFrame, MerchantFrame

	local function item(itemID, quality, count)
		return { itemID = itemID, link = "item:" .. itemID, name = "Item " .. itemID, quality = quality, count = count or 1 }
	end

	local function frame()
		return Window.Grid().frame
	end

	before_each(function()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		LootFrame = UI.NewFake(Loader.ui.UIParent, "HIGH")
		LootFrame.shown = false
		LootFrame.ClosePanelButton = UI.NewFake(LootFrame)
		rawset(_G, "LootFrame", LootFrame)
		MerchantFrame = UI.NewFake(Loader.ui.UIParent)
		rawset(_G, "MerchantFrame", MerchantFrame)
		Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		Window = Junk.Window
		Test.SetItems({ [1] = { name = "Item 1", sellPrice = 1 }, [2] = { name = "Item 2", sellPrice = 2 } })
		Test.SetBags({ [0] = { size = 4, items = { [1] = item(1, 0, 3), [2] = item(2, 1) } } })
	end)

	after_each(function()
		rawset(_G, "LootFrame", nil)
		rawset(_G, "MerchantFrame", nil)
	end)

	it("is one window with one name, of one size in every mode, its title saying the mode", function()
		local sizes = {}
		for _, open in ipairs({ function() Window.Open("auto") end, function() ns.JunkList.Open() end }) do
			open()
			sizes[#sizes + 1] = { frame():GetWidth(), frame():GetHeight() }
		end
		Test.SetInteracting("Merchant", true)
		Window.Open("merchant")
		sizes[#sizes + 1] = { frame():GetWidth(), frame():GetHeight() }
		assert.same({ sizes[1], sizes[1] }, { sizes[2], sizes[3] })
		assert.same({ "LootomanJunkWindow", "Sell Junk" }, { frame().name, frame().title })
		ns.JunkList.Open()
		assert.equals("Junk List", frame().title)
		Test.SetInteracting("Merchant", false)
		Window.Open("auto")
		assert.equals("Throw Away Junk", frame().title)
	end)

	it("opens away from a merchant to throw away, in the middle; at one to sell, beside it", function()
		assert.is_true(Window.Open("auto"))
		assert.same({ "toss", { "CENTER" }, "HIGH" }, { Window.Mode(), frame().points[1], frame().strata })
		frame():Hide()
		Test.SetInteracting("Merchant", true)
		Window.Open("auto")
		assert.same({ "sell", { "TOPLEFT", MerchantFrame, "TOPRIGHT", 4, 0 } }, { Window.Mode(), frame().points[1] })
		-- /ltm junk, the bag button and the loot feed's warning open it so.
		frame():Hide()
		Test.RunSlashCommand("LOOTOMAN", "junk")
		assert.same({ true, "sell" }, { frame():IsShown(), Window.Mode() })
		frame():Hide()
		ns.Bus:Send("OpenJunkWindow")
		assert.same({ true, "sell" }, { frame():IsShown(), Window.Mode() })
	end)

	it("opens from the loot window's button to throw away beside it, also at a merchant, and closes with the loot", function()
		Test.SetInteracting("Merchant", true)
		LootFrame:Show()
		Junk.Toss.Toggle(true)
		assert.same({ "toss", { "TOPLEFT", LootFrame, "TOPRIGHT", 4, 0 } }, { Window.Mode(), frame().points[1] })
		Test.FireEvent("LOOT_CLOSED")
		assert.is_false(frame():IsShown())
	end)

	it("opens from the sell button only at a merchant, and closes with the merchant in whatever mode", function()
		assert.is_false(Window.Open("merchant"))
		Test.SetInteracting("Merchant", true)
		assert.is_true(Junk.SellWindow.Open())
		Window.SwitchLists()
		assert.equals("lists", Window.Mode())
		Test.SetInteracting("Merchant", false)
		assert.is_false(frame():IsShown())
	end)

	it("switches to selling when a merchant opens while it throws away, and back when the merchant closes", function()
		Window.Open("auto")
		Test.SetInteracting("Merchant", true)
		assert.same({ true, "sell", "Sell Junk", { "CENTER" } }, { frame():IsShown(), Window.Mode(), frame().title, frame().points[1] })
		Test.SetInteracting("Merchant", false)
		assert.same({ true, "toss" }, { frame():IsShown(), Window.Mode() })
	end)

	it("deletes only while it throws away; selling, a move is for this sale only", function()
		Window.Open("auto")
		Test.SetInteracting("Merchant", true)
		local grid = Window.Grid()
		assert.is_nil(grid.options.onDropOutside)
		local entry = grid.built.junk.entries[1]
		grid:MoveTo(entry, "rest", grid:ForGood())
		assert.same({ nil, true }, { ns.Marks.Get(1), grid.thisSale.keep[1] })
		-- Throwing away: no sale's decisions, dropping outside deletes, every move is for good.
		Test.SetInteracting("Merchant", false)
		assert.same({ "toss", {}, true }, { Window.Mode(), grid.thisSale.keep, grid.options.onDropOutside ~= nil })
		grid:MoveTo(grid.built.junk.entries[1], "rest", grid:ForGood())
		assert.equals("notJunk", ns.Marks.Get(1))
	end)

	it("has the Sell Junk button only while it sells", function()
		Window.Open("auto")
		local grid = Window.Grid()
		assert.is_false(grid.sellButton:IsShown())
		Test.SetInteracting("Merchant", true)
		assert.is_true(grid.sellButton:IsShown())
		Window.SwitchLists()
		assert.same({ false, true }, { grid.sellButton:IsShown(), ns.JunkList.Window().clear:IsShown() })
	end)

	describe("gear", function()
		it("is the game's own, left of the close button, a fallback where the client lacks it", function()
			local gear = Window.Grid().gear
			assert.same({ "questlog-icon-setting", { "RIGHT", Window.Grid().close, "LEFT", -2, 0 } }, { gear.normalAtlas, gear.points[1] })
			Test.state.missingAtlases["questlog-icon-setting"] = true
			local fresh = Loader.LoadAddon({ skip = {} })
			fresh.Compat.Test.state.missingAtlases["questlog-icon-setting"] = true
			Loader.Start(fresh)
			assert.equals([[Interface\Buttons\UI-OptionsButton]], fresh.Modules:Get("Junk").Window.Grid().gear.normalTexture)
		end)

		it("switches to the lists and back to the bags, throwing away, where the window is", function()
			Window.Open("auto")
			frame():ClearAllPoints()
			frame():SetPoint("TOPLEFT", Loader.ui.UIParent, "BOTTOMLEFT", 300, 700)
			local gear = Window.Grid().gear
			gear.scripts.OnClick(gear)
			local lists = ns.JunkList.Window()
			assert.same({ "lists", true, false, true, true }, { Window.Mode(), lists.list:IsShown(),
				Window.Grid().sections.junk.frame:IsShown(), lists.frame.Tabs[1]:IsShown(), lists.share:IsShown() })
			gear.scripts.OnClick(gear)
			assert.same({ "toss", false, true, false }, { Window.Mode(), lists.list:IsShown(),
				Window.Grid().sections.junk.frame:IsShown(), lists.frame.Tabs[1]:IsShown() })
			assert.same({ { "TOPLEFT", Loader.ui.UIParent, "BOTTOMLEFT", 300, 700 } }, frame().points)
		end)

		it("goes back to selling at a merchant", function()
			Test.SetInteracting("Merchant", true)
			ns.JunkList.Open()
			Window.SwitchLists()
			assert.equals("sell", Window.Mode())
		end)

		it("tells where it goes", function()
			Window.Open("auto")
			local gear = Window.Grid().gear
			gear.scripts.OnEnter(gear)
			assert.equals("The junk list", Loader.ui.tooltip.lines[1])
			gear.scripts.OnClick(gear)
			gear.scripts.OnEnter(gear)
			assert.equals("Back to the bags", Loader.ui.tooltip.lines[#Loader.ui.tooltip.lines])
		end)
	end)
end)
