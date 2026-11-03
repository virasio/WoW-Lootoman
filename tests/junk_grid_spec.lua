local Loader = require("tests.helpers.loader")

-- The bag-like window of the toss and sell windows.
describe("item grid", function()
	local ns, ItemGrid, Test, grid, clicked

	local function item(itemID, name, quality, count)
		return { itemID = itemID, link = "item:" .. itemID, name = name, quality = quality, count = count or 1, icon = 100 + itemID }
	end

	-- What a section shows: "name price" for every button that is shown.
	local function shown(key)
		local list = {}
		for _, button in ipairs(grid.sections[key].buttons) do
			if button:IsShown() then
				list[#list + 1] = ("%s %s"):format(button.entry.item.name, button.price.text)
			end
		end
		return list
	end

	local function button(key, index)
		return grid.sections[key].buttons[index]
	end

	-- Drags a button and lets it go over a section (or over nothing).
	local function drag(from, over)
		from.scripts.OnDragStart(from)
		for key, section in pairs(grid.sections) do
			section.frame.mouseOver = key == over
		end
		from.scripts.OnDragStop(from)
	end

	before_each(function()
		rawset(_G, "Auctionator", nil)
		ns = Loader.Start(Loader.LoadAddon())
		ItemGrid, Test = ns.Modules:Get("Junk").ItemGrid, ns.Compat.Test
		Test.SetItems({
			[1] = { name = "Broken Tooth", sellPrice = 7 },
			[2] = { name = "Linen Cloth", sellPrice = 13 },
			[3] = { name = "Sword", sellPrice = 15000 },
		})
		Test.SetBags({ [0] = { size = 4, items = {
			[1] = item(1, "Broken Tooth", 0, 3),
			[2] = item(2, "Linen Cloth", 1, 20),
			[3] = item(3, "Sword", 2, 1),
		} } })
		clicked = {}
		grid = ItemGrid.Create({
			name = "LootomanTestGrid",
			title = "Test",
			kind = "toss",
			rightClick = "Right-click: test",
			onRightClick = function(entry) clicked[#clicked + 1] = entry.item.name end,
		})
		grid:Attach()
	end)

	after_each(function()
		rawset(_G, "Auctionator", nil)
	end)

	it("shows the junk on top and the rest below, with short prices", function()
		grid:Open()
		assert.is_true(grid.frame:IsShown())
		assert.same({ "Broken Tooth 21c" }, shown("junk"))
		assert.same({ "Linen Cloth 2s", "Sword 1g" }, shown("rest"))
		assert.same({ false, false }, { grid.sections.junk.hint:IsShown(), grid.sections.rest.hint:IsShown() })
		Test.SetBags({ [0] = { size = 4 } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.same({ {}, {}, true, true }, { shown("junk"), shown("rest"), grid.sections.junk.hint:IsShown(), grid.sections.rest.hint:IsShown() })
	end)

	it("writes prices with the game's coins, by their biggest coin", function()
		assert.same({ "12g", "35s", "8c", "" }, { ItemGrid.ShortPrice(125000), ItemGrid.ShortPrice(3512), ItemGrid.ShortPrice(8), ItemGrid.ShortPrice(0) })
		Test.SetGlobalStrings({ GOLD_AMOUNT_TEXTURE = "%d|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0|t" })
		assert.equals("12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", ItemGrid.ShortPrice(125000))
	end)

	it("hands a right click to its owner and ignores a left one", function()
		grid:Open()
		local sword = button("rest", 2)
		sword.scripts.OnClick(sword, "LeftButton")
		sword.scripts.OnClick(sword, "RightButton")
		assert.same({ "Sword" }, clicked)
	end)

	it("marks an item dragged into the other section, and follows the mark", function()
		grid:Open()
		drag(button("rest", 1), "junk")
		assert.equals("junk", ns.Marks.Get(2))
		assert.same({ "Broken Tooth 21c", "Linen Cloth 2s" }, shown("junk"))
		drag(button("junk", 1), "rest")
		assert.equals("notJunk", ns.Marks.Get(1))
		assert.same({ "Linen Cloth 2s" }, shown("junk"))
		assert.same({ "Broken Tooth 21c", "Sword 1g" }, shown("rest"))
		assert.is_false(grid.ghost:IsShown())
	end)

	it("does nothing for a drag that ends where it began or outside", function()
		grid:Open()
		drag(button("rest", 1), "rest")
		drag(button("rest", 2), nil)
		assert.same({}, ns.Marks.List())
	end)

	it("follows the bags while it is shown", function()
		grid:Open()
		Test.state.bags[0].items[3] = nil
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.same({ "Linen Cloth 2s" }, shown("rest"))
		assert.is_false(button("rest", 2):IsShown())
	end)

	it("shows the game's tooltip of the bag slot, the comparison, the auction price and what the clicks do", function()
		rawset(_G, "Auctionator", { API = { v1 = { GetAuctionPriceByItemLink = function() return 500 end } } })
		Test.state.addons.Auctionator = true
		grid:Open()
		local sword = button("rest", 2)
		Loader.ui.compare = true
		sword.scripts.OnEnter(sword)
		local tooltip = Loader.ui.tooltip
		assert.same({ 0, 3 }, tooltip.bagItem)
		assert.is_true(tooltip.compared)
		assert.same({ "Auction price: 500 copper", "Right-click: test", "Drag it up to mark it as junk." }, tooltip.lines)
		assert.is_true(tooltip.shown)
	end)

	it("closes with Escape", function()
		grid:Open()
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(grid.frame:IsShown())
	end)
end)
