local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The currency bar editor.
describe("bar editor", function()
	local ns, api, Test, Bars, Sets, Editor

	local function names(list)
		local found = {}
		for _, row in ipairs(list.rows) do
			if row.shown and row.item then
				found[#found + 1] = row.Name.text
			end
		end
		return found
	end

	local function window()
		return Editor.Window()
	end

	local function click(button)
		button.scripts.OnClick(button)
	end

	local function choose(list, name)
		for _, row in ipairs(list.rows) do
			if row.shown and row.item and row.Name.text == name then
				click(row)
				return
			end
		end
		error("no row " .. name)
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		Test.SetCurrency(3008, { name = "Valorstones", icon = 1, quantity = 500, backpack = 1 })
		Test.SetCurrency(2815, { name = "Resonance Crystals", icon = 3, quantity = 4000 })
		Test.SetCurrency(3110, { name = "Gilded Crest", icon = 2, quantity = 20 })
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 4 }, [765] = { name = "Silverleaf", icon = 5 } })
		Loader.Start(ns)
		Bars = ns.Modules:Get("Bars")
		Sets, Editor = Bars.Sets, Bars.Editor
		Editor.Open()
	end)

	it("lists what is on the bar in its order, and the other currencies by name", function()
		assert.is_true(window():IsShown())
		assert.same({ "Valorstones" }, names(window().left))
		assert.same({ "Gilded Crest", "Money", "Resonance Crystals" }, names(window().right))
	end)

	it("moves the chosen currency onto the bar and off it with the buttons between the lists", function()
		choose(window().right, "Resonance Crystals")
		click(window().toBar)
		assert.same({ "Valorstones", "Resonance Crystals" }, names(window().left))
		assert.same({ "Gilded Crest", "Money" }, names(window().right))
		choose(window().left, "Valorstones")
		click(window().offBar)
		assert.same({ "Resonance Crystals" }, names(window().left))
		assert.same({ "Gilded Crest", "Money", "Valorstones" }, names(window().right))
		choose(window().right, "Money")
		click(window().toBar)
		assert.same({ "Resonance Crystals", "Money" }, names(window().left))
		assert.same({ { kind = "currency", id = 2815 }, { kind = "money", id = 0 } }, Sets.Get("Default").bars[1].entries)
	end)

	it("adds an item by its ID, or dropped from the bags, and refuses what is not an ID", function()
		window().itemID:SetText("2589")
		click(window().addItem)
		Test.state.cursor = nil
		Test.state.cursorItem = 765
		window().left.box.scripts.OnReceiveDrag(window().left.box)
		assert.same({ "Valorstones", "Linen Cloth", "Silverleaf" }, names(window().left))
		assert.same({ "", nil }, { window().itemID.text, Test.state.cursor })
		window().itemID:SetText("cloth")
		click(window().addItem)
		assert.matches("ID", Test.state.printed[#Test.state.printed])
		assert.equals(3, #Sets.Get("Default").bars[1].entries)
	end)

	it("keeps a bag item taken off the bar in the right list only while the window is open", function()
		Editor.AddItem(Editor.Bar(), 2589)
		choose(window().left, "Linen Cloth")
		click(window().offBar)
		assert.same({ "Gilded Crest", "Linen Cloth", "Money", "Resonance Crystals" }, names(window().right))
		choose(window().right, "Linen Cloth")
		click(window().toBar)
		assert.same({ "Valorstones", "Linen Cloth" }, names(window().left))
		assert.same({}, Editor.Removed())
		-- Saved data never holds that list.
		assert.is_nil(Sets.Get("Default").removed)
		-- Closing the window forgets it.
		choose(window().left, "Linen Cloth")
		click(window().offBar)
		window():Hide()
		Editor.Open()
		assert.same({ "Gilded Crest", "Money", "Resonance Crystals" }, names(window().right))
		-- An item taken off while the window is closed is not kept either.
		Editor.AddItem(Editor.Bar(), 765)
		window():Hide()
		Editor.Remove(Editor.Bar(), 2)
		Editor.Open()
		assert.same({ "Gilded Crest", "Money", "Resonance Crystals" }, names(window().right))
	end)

	it("reorders the bar's entries", function()
		Editor.AddItem(Editor.Bar(), 2589)
		Editor.AddItem(Editor.Bar(), 765)
		Editor.Move(Editor.Bar(), 3, 1)
		assert.same({ "Silverleaf", "Valorstones", "Linen Cloth" }, names(window().left))
		Editor.Move(Editor.Bar(), 1, 4)
		assert.same({ "Valorstones", "Linen Cloth", "Silverleaf" }, names(window().left))
	end)

	local function rowOf(list, name)
		for _, row in ipairs(list.rows) do
			if row.shown and row.item and row.Name.text == name then
				return row
			end
		end
		error("no row " .. name)
	end

	-- Where the mouse is: over the bar's list, the other list, or neither, and
	-- how far below the top of the bar's list.
	local function point(over, below)
		window().left.box.mouseOver = over == "left"
		window().right.box.mouseOver = over == "right"
		Loader.ui.cursor = { 0, -(below or 0) }
		Editor.FollowDrag()
	end

	it("drags a row along the bar's list, showing what moves and where it goes", function()
		Editor.AddItem(Editor.Bar(), 2589)
		Editor.AddItem(Editor.Bar(), 765)
		local row = rowOf(window().left, "Silverleaf")
		row.scripts.OnDragStart(row)
		-- In the gap after the first row.
		point("left", 20)
		local marker = window().left.Marker
		assert.same({ 0.35, true, "Silverleaf" }, { row.alpha, Editor.Ghost().shown, Editor.Ghost().Name.text })
		assert.same({ true, { "TOPLEFT", window().left.content, "TOPLEFT", 0, -21 } }, { marker.shown, marker.points[1] })
		row.scripts.OnDragStop(row)
		assert.same({ "Valorstones", "Silverleaf", "Linen Cloth" }, names(window().left))
		assert.same({ 1, false, false }, { row.alpha, Editor.Ghost().shown, marker.shown })
	end)

	it("drags a row from one list to the other, and does nothing dropped elsewhere", function()
		local row = rowOf(window().right, "Resonance Crystals")
		row.scripts.OnDragStart(row)
		-- Over its own list: nowhere to go.
		point("right", 0)
		assert.same({ false, false }, { window().left.Marker.shown, window().right.box.Target.shown })
		point("left", 2)
		row.scripts.OnDragStop(row)
		assert.same({ "Resonance Crystals", "Valorstones" }, names(window().left))
		assert.same({ "Gilded Crest", "Money" }, names(window().right))
		row = rowOf(window().left, "Valorstones")
		row.scripts.OnDragStart(row)
		point("right", 0)
		assert.is_true(window().right.box.Target.shown)
		row.scripts.OnDragStop(row)
		assert.same({ "Resonance Crystals" }, names(window().left))
		assert.same({ "Gilded Crest", "Money", "Valorstones" }, names(window().right))
		row = rowOf(window().left, "Resonance Crystals")
		row.scripts.OnDragStart(row)
		point(nil)
		row.scripts.OnDragStop(row)
		assert.same({ "Resonance Crystals" }, names(window().left))
		-- Closing the window ends a drag.
		row.scripts.OnDragStart(row)
		window():Hide()
		assert.same({ false, 1 }, { Editor.Ghost().shown, row.alpha })
	end)

	it("sets what an item counts from its right-click menu, and shows it again counting what is not shown yet", function()
		Editor.AddItem(Editor.Bar(), 2589)
		local row = rowOf(window().left, "Linen Cloth")
		row.scripts.OnClick(row, "RightButton")
		local menu = Loader.ui.contextMenu
		assert.same({ "Count the bags", "Count the banks", "Count everything", "Show it again" },
			{ menu.entries[1].text, menu.entries[2].text, menu.entries[3].text, menu.entries[5].text })
		menu.entries[2].setSelected()
		assert.same({ "Valorstones", "Linen Cloth, in the banks" }, names(window().left))
		-- Counting the banks, it is another entry than the item in the bags.
		assert.is_true(Editor.AddItem(Editor.Bar(), 2589))
		assert.same({ "Valorstones", "Linen Cloth, in the banks", "Linen Cloth" }, names(window().left))
		row = rowOf(window().left, "Linen Cloth, in the banks")
		row.scripts.OnClick(row, "RightButton")
		Loader.ui.contextMenu.entries[5].callback()
		assert.same({ "Valorstones", "Linen Cloth, in the banks", "Linen Cloth, everywhere", "Linen Cloth" }, names(window().left))
		-- All three are on the bar: no fourth, and no count another entry has.
		row = rowOf(window().left, "Linen Cloth")
		row.scripts.OnClick(row, "RightButton")
		menu = Loader.ui.contextMenu
		assert.same({ true, false, false, false }, { menu.entries[1].enabled, menu.entries[2].enabled, menu.entries[3].enabled, menu.entries[5].enabled })
		assert.is_false(Editor.SetCount(Editor.Bar(), 4, "banks"))
		assert.same({ { kind = "currency", id = 3008 }, { kind = "item", id = 2589, count = "banks" }, { kind = "item", id = 2589, count = "all" },
			{ kind = "item", id = 2589 } }, Sets.Get("Default").bars[1].entries)
		-- A currency has no such menu.
		Loader.ui.contextMenu = nil
		row = rowOf(window().left, "Valorstones")
		row.scripts.OnClick(row, "RightButton")
		assert.is_nil(Loader.ui.contextMenu)
	end)

	it("adds nothing while the set has no bar", function()
		click(window().remove)
		assert.same({ 0, false }, { #Sets.Get("Default").bars, window().addItem.enabled })
		window().itemID:SetText("2589")
		click(window().addItem)
		assert.is_false(Editor.Add(Editor.Bar(), { kind = "item", id = 2589 }))
	end)

	it("changes no set while a bar asks whether to take an entry off", function()
		Sets.Create("Raid")
		local barSlot = Bars.slots[1]
		local button = barSlot.buttons[1]
		button.scripts.OnDragStart(button)
		barSlot.frame.mouseOver = false
		button.scripts.OnDragStop(button)
		-- Raid, the second name, chosen; Default's Reset, under its gear.
		local menu = api.OpenMenu(window().setMenu)
		menu.entries[2].setSelected()
		menu.entries[1].entries[2].callback()
		assert.same({ "Default", 1 }, { Sets.Current(), #api.popups })
		api.AcceptPopup()
		menu.entries[2].setSelected()
		assert.equals("Raid", Sets.Current())
	end)

	it("shows an item's name once the client has loaded it", function()
		Editor.AddItem(Editor.Bar(), 12345)
		assert.same({ "Valorstones", "Item 12345" }, names(window().left))
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 4 }, [765] = { name = "Silverleaf", icon = 5 }, [12345] = { name = "Dream Silk", icon = 6 } })
		Test.FireEvent("GET_ITEM_INFO_RECEIVED", 12345, true)
		assert.same({ "Valorstones", "Dream Silk" }, names(window().left))
	end)

	it("adds and removes bars of the set, and shows the chosen one", function()
		click(window().add)
		assert.same({ 2, {} }, { #Sets.Get("Default").bars, names(window().left) })
		click(window().remove)
		assert.same({ 1, { "Valorstones" } }, { #Sets.Get("Default").bars, names(window().left) })
	end)

	it("switches, creates and shares sets from its menu", function()
		local menu = api.OpenMenu(window().setMenu)
		local entries = {}
		for _, entry in ipairs(menu.entries) do
			entries[#entries + 1] = entry.kind .. ":" .. tostring(entry.text)
		end
		assert.same({ "radio:Default", "divider:nil" }, { entries[1], entries[2] })
		Sets.Create("Raid")
		Sets.Get("Raid").bars[1].entries = { { kind = "currency", id = 3110 } }
		menu = api.OpenMenu(window().setMenu)
		menu.entries[2].setSelected()
		assert.same({ "Raid", { "Gilded Crest" } }, { Sets.Current(), names(window().left) })
	end)

	it("opens with /lootoman bars and from the Bars page, and closes with Escape", function()
		window():Hide()
		Test.RunSlashCommand("LOOTOMAN", "bars")
		assert.is_true(window():IsShown())
		assert.is_true(Loader.ui.PressEscape())
		api.FindButton(api.FindCategory("Currency bars"), "Bars").onClick()
		assert.is_true(window():IsShown())
	end)
end)
