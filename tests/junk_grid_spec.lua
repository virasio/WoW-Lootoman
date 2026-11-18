local Loader = require("tests.helpers.loader")

-- The bag-like window of the junk windows.
describe("item grid", function()
	local ns, ItemGrid, Test, grid, dropped, shift

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

	-- The section's button showing an item.
	local function button(name)
		for _, key in ipairs(ItemGrid.SECTIONS) do
			for _, each in ipairs(grid.sections[key].buttons) do
				if each:IsShown() and each.entry.item.name == name then
					return each
				end
			end
		end
	end

	-- The section's shown subgroup headings.
	local function headings(key)
		local list = {}
		for _, header in ipairs(grid.sections[key].headers) do
			if header:IsShown() then
				list[#list + 1] = header.title.text
			end
		end
		return list
	end

	-- Drags a button and lets it go over a section, over the rest of the window
	-- (nil) or outside it ("outside").
	local function drag(from, over)
		from.scripts.OnDragStart(from)
		for key, section in pairs(grid.sections) do
			section.frame.mouseOver = key == over
		end
		grid.frame.mouseOver = over ~= "outside"
		from.scripts.OnDragStop(from)
	end

	local function click(from, mouseButton)
		from.scripts.OnClick(from, mouseButton)
	end

	local function create(options)
		options = options or {}
		grid = ItemGrid.Create({
			name = options.name or "LootomanTestGrid",
			title = "Test",
			kind = options.kind or "toss",
			dropOutside = options.kind ~= "sell" and "Drag out: test" or nil,
			onDropOutside = function(entry) dropped[#dropped + 1] = entry.item.name end,
		})
		grid:Attach()
		grid:Open()
	end

	before_each(function()
		rawset(_G, "Auctionator", nil)
		shift = false
		rawset(_G, "IsShiftKeyDown", function() return shift end)
		ns = Loader.Start(Loader.LoadAddon())
		ItemGrid, Test = ns.Modules:Get("Junk").ItemGrid, ns.Compat.Test
		Test.state.itemClasses = { [7] = "Trade Goods" }
		Test.state.playerLevel = 60
		Test.SetItems({
			[1] = { name = "Broken Tooth", sellPrice = 7 },
			[2] = { name = "Linen Cloth", sellPrice = 13, classID = 7 },
			[3] = { name = "Sword", sellPrice = 15000 },
			[4] = { name = "Old Bread", sellPrice = 1, classID = 0, subclassID = 5, requiredLevel = 5 },
		})
		Test.SetBags({ [0] = { size = 6, items = {
			[1] = item(1, "Broken Tooth", 0, 3),
			[2] = item(2, "Linen Cloth", 1, 20),
			[3] = item(3, "Sword", 2, 1),
			[4] = item(4, "Old Bread", 1, 5),
		} } })
		dropped = {}
	end)

	after_each(function()
		rawset(_G, "Auctionator", nil)
		rawset(_G, "IsShiftKeyDown", nil)
	end)

	it("shows the junk, the suggestions by rule and the rest by kind, with short prices", function()
		create()
		assert.is_true(grid.frame:IsShown())
		assert.same({ "Broken Tooth 21c" }, shown("junk"))
		assert.same({ "Old Bread 5c" }, shown("suggested"))
		assert.same({ "Outgrown" }, headings("suggested"))
		assert.same({ "Sword 1g", "Linen Cloth 2s" }, shown("rest"))
		assert.same({ "Other", "Trade Goods" }, headings("rest"))
		assert.same({ false, false, false }, { grid.sections.junk.hint:IsShown(), grid.sections.suggested.hint:IsShown(),
			grid.sections.rest.hint:IsShown() })
		Test.SetBags({ [0] = { size = 4 } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		assert.same({ {}, {}, {}, true, true }, { shown("junk"), shown("suggested"), shown("rest"), grid.sections.junk.hint:IsShown(),
			grid.sections.suggested.hint:IsShown() })
	end)

	it("writes prices with the game's coins, by their biggest coin", function()
		assert.same({ "12g", "35s", "8c", "" }, { ItemGrid.ShortPrice(125000), ItemGrid.ShortPrice(3512), ItemGrid.ShortPrice(8), ItemGrid.ShortPrice(0) })
		Test.SetGlobalStrings({ GOLD_AMOUNT_TEXTURE = "%d|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:2:0|t" })
		assert.equals("12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", ItemGrid.ShortPrice(125000))
	end)

	it("takes a suggestion to the junk with a left click and to not junk with a right one, for good", function()
		create()
		click(button("Old Bread"), "LeftButton")
		assert.same({ "junk", { "Old Bread 5c", "Broken Tooth 21c" } }, { ns.Marks.Get(4), shown("junk") })
		ns.Marks.Set(4, nil)
		click(button("Old Bread"), "RightButton")
		assert.same({ "notJunk", {} }, { ns.Marks.Get(4), shown("suggested") })
	end)

	it("moves junk and not junk by dragging only; clicks on them do nothing", function()
		create()
		click(button("Sword"), "RightButton")
		click(button("Broken Tooth"), "LeftButton")
		assert.same({}, ns.Marks.List())
		drag(button("Sword"), "junk")
		assert.equals("junk", ns.Marks.Get(3))
		drag(button("Broken Tooth"), "rest")
		assert.equals("notJunk", ns.Marks.Get(1))
		assert.same({ "Sword 1g" }, shown("junk"))
		assert.is_false(grid.ghost:IsShown())
	end)

	it("takes a hinted junk item to not junk with a left click", function()
		Test.state.questObjectives = { "Broken Tooth: 0/3" }
		Test.FireEvent("QUEST_LOG_UPDATE")
		create()
		assert.same({ "A quest in your log still wants these" }, headings("junk"))
		click(button("Broken Tooth"), "LeftButton")
		assert.equals("notJunk", ns.Marks.Get(1))
	end)

	it("hands an item dropped outside the window to its owner, and does nothing on the suggestions or where it began", function()
		create()
		drag(button("Broken Tooth"), "outside")
		assert.same({ "Broken Tooth" }, dropped)
		drag(button("Sword"), "suggested")
		drag(button("Sword"), "rest")
		drag(button("Linen Cloth"), nil)
		assert.same({}, ns.Marks.List())
	end)

	it("sends a whole suggestion group to the junk with To Junk", function()
		create()
		local header = grid.sections.suggested.headers[1]
		assert.is_true(header.button:IsShown())
		header.button.scripts.OnClick(header.button)
		assert.equals("junk", ns.Marks.Get(4))
	end)

	describe("in the sell window", function()
		it("moves for this sale only without Shift, and for good with it", function()
			create({ kind = "sell", name = "LootomanTestSellGrid" })
			click(button("Old Bread"), "LeftButton")
			assert.same({ {}, { "Old Bread 5c", "Broken Tooth 21c" } }, { ns.Marks.List(), shown("junk") })
			drag(button("Broken Tooth"), "rest")
			assert.same({ {}, { "Old Bread 5c" } }, { ns.Marks.List(), shown("junk") })
			shift = true
			drag(button("Sword"), "junk")
			assert.equals("junk", ns.Marks.Get(3))
		end)

		it("forgets this sale's decisions when it closes", function()
			create({ kind = "sell", name = "LootomanTestSellGrid" })
			click(button("Old Bread"), "LeftButton")
			grid:Close()
			grid:Open()
			assert.same({ "Broken Tooth 21c" }, shown("junk"))
		end)
	end)

	it("shows the game's tooltip, the auction price, why it is suggested and what the clicks and drags do", function()
		rawset(_G, "Auctionator", { API = { v1 = { GetAuctionPriceByItemLink = function(_, link)
			return link == "item:3" and 500 or nil
		end } } })
		Test.state.addons.Auctionator = true
		create()
		local bread, sword = button("Old Bread"), button("Sword")
		Loader.ui.compare = true
		bread.scripts.OnEnter(bread)
		local tooltip = Loader.ui.tooltip
		assert.same({ 0, 4 }, tooltip.bagItem)
		assert.is_true(tooltip.compared)
		assert.same({ "Far below your level.", "Left-click: to junk. Right-click: not junk.", "Drag it to Junk to mark it as junk.",
			"Drag out: test" }, tooltip.lines)
		assert.is_true(tooltip.shown)
		sword.scripts.OnEnter(sword)
		assert.same({ "Auction price: 500 copper", "Drag it to Junk to mark it as junk.", "Drag out: test" }, tooltip.lines)
	end)

	it("closes with Escape", function()
		create()
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(grid.frame:IsShown())
	end)
end)
