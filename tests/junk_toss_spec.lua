local Loader = require("tests.helpers.loader")
local UI = require("tests.mocks.UI")

-- The toss window and deleting, with the fake client's cursor.
describe("toss window", function()
	local ns, Junk, Toss, Test, LootFrame

	local function item(itemID, name, quality, count)
		return { itemID = itemID, link = "[" .. name .. "]", name = name, quality = quality, count = count or 1 }
	end

	local function entry(bag, slot)
		for _, section in ipairs({ "junk", "rest" }) do
			for _, found in ipairs(Toss.Grid().built[section].entries) do
				if found.item.bag == bag and found.item.slot == slot then
					return found
				end
			end
		end
	end

	local function bagItem(bag, slot)
		return Test.state.bags[bag].items[slot]
	end

	-- Drags an item's button out of the window and lets it go there.
	local function dragOut(bag, slot)
		local grid = Toss.Grid()
		for _, section in pairs(grid.sections) do
			for _, button in ipairs(section.buttons) do
				if button:IsShown() and button.entry.item.bag == bag and button.entry.item.slot == slot then
					button.scripts.OnDragStart(button)
					for _, other in pairs(grid.sections) do
						other.frame.mouseOver = false
					end
					grid.frame.mouseOver = false
					button.scripts.OnDragStop(button)
					return
				end
			end
		end
		error("no button for " .. bag .. ":" .. slot)
	end

	local function confirm()
		return rawget(_G, Toss.CONFIRM_NAME)
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Test = ns.Compat.Test
		LootFrame = UI.NewFake(Loader.ui.UIParent, "HIGH")
		LootFrame.shown = false
		LootFrame.ClosePanelButton = UI.NewFake(LootFrame)
		rawset(_G, "LootFrame", LootFrame)
		Loader.Start(ns)
		Junk = ns.Modules:Get("Junk")
		Toss = Junk.Toss
		Test.SetItems({ [1] = { name = "Broken Tooth", sellPrice = 7 }, [2] = { name = "Linen Cloth", sellPrice = 13 },
			[3] = { name = "Ring", sellPrice = 9000 } })
		Test.SetBags({ [0] = { size = 4, items = {
			[1] = item(1, "Broken Tooth", 0, 3),
			[2] = item(2, "Linen Cloth", 1, 20),
			[3] = item(3, "Ring", 4, 1),
		} } })
		Test.SetGlobalStrings({ DELETE_ITEM_CONFIRM_STRING = "DELETE" })
	end)

	after_each(function()
		rawset(_G, "LootFrame", nil)
	end)

	it("opens from the toss button next to the loot window and closes with the loot", function()
		LootFrame:Show()
		Toss.Toggle()
		local frame = Toss.Grid().frame
		assert.is_true(frame:IsShown())
		assert.same({ { "TOPLEFT", LootFrame, "TOPRIGHT", 4, 0 } }, frame.points)
		Test.FireEvent("LOOT_CLOSED")
		assert.is_false(frame:IsShown())
	end)

	it("opens in the middle of the screen while fast autoloot keeps the loot window hidden", function()
		LootFrame:Show()
		LootFrame.parent = UI.NewFake(Loader.ui.UIParent)
		LootFrame.parent:Hide()
		Toss.Toggle()
		assert.same({ { "CENTER" } }, Toss.Grid().frame.points)
	end)

	it("opens on the left of the loot window when there is no room on the right", function()
		LootFrame.GetRight = function() return 1800 end
		Loader.ui.UIParent.GetRight = function() return 1920 end
		LootFrame:Show()
		Toss.Toggle()
		assert.same({ { "TOPRIGHT", LootFrame, "TOPLEFT", -4, 0 } }, Toss.Grid().frame.points)
	end)

	it("opens in the middle of the screen with /lootoman toss, even by a loot window, and stays open when a loot closes", function()
		LootFrame:Show()
		Test.RunSlashCommand("LOOTOMAN", "toss")
		local frame = Toss.Grid().frame
		assert.same({ { true, { "CENTER" } } }, { { frame:IsShown(), frame.points[1] } })
		Test.FireEvent("LOOT_CLOSED")
		assert.is_true(frame:IsShown())
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(frame:IsShown())
		Test.RunSlashCommand("LOOTOMAN", "toss")
		assert.is_false(frame:IsShown())
		assert.matches("is off", Test.state.printed[#Test.state.printed])
	end)

	describe("deleting", function()
		before_each(function()
			Toss.Open()
		end)

		it("deletes a gray stack dragged out of the window at once: a pick up and a delete", function()
			dragOut(0, 1)
			assert.is_nil(bagItem(0, 1))
			assert.same({ { "pickup", 0, 1 }, { "delete" } }, Test.state.bagActions)
			assert.matches("Deleted %[Broken Tooth%] ×3", Test.state.printed[#Test.state.printed])
			assert.is_nil(confirm())
		end)

		it("asks before deleting an item above gray, and deletes it on Delete", function()
			dragOut(0, 2)
			assert.is_true(confirm():IsShown())
			assert.equals("Delete [Linen Cloth] ×20?", confirm().text.text)
			assert.is_false(confirm().word:IsShown())
			assert.same({}, Test.state.bagActions)
			confirm().delete.scripts.OnClick(confirm().delete)
			assert.is_nil(bagItem(0, 2))
			assert.is_false(confirm():IsShown())
		end)

		it("deletes nothing when the question is cancelled or closed", function()
			dragOut(0, 2)
			confirm().cancel.scripts.OnClick(confirm().cancel)
			dragOut(0, 2)
			assert.is_true(Loader.ui.PressEscape())
			assert.is_false(confirm():IsShown())
			assert.is_not_nil(bagItem(0, 2))
			assert.same({}, Test.state.bagActions)
		end)

		it("asks for the game's word for rare and better items, in any letter case", function()
			dragOut(0, 3)
			assert.equals("Delete [Ring]? Type “DELETE” to confirm.", confirm().text.text)
			assert.is_true(confirm().word:IsShown())
			assert.is_false(confirm().delete:IsEnabled())
			confirm().delete.scripts.OnClick(confirm().delete)
			assert.is_not_nil(bagItem(0, 3))
			confirm().word:SetText("delete")
			confirm().word.scripts.OnTextChanged(confirm().word)
			assert.is_true(confirm().delete:IsEnabled())
			confirm().word.scripts.OnEnterPressed(confirm().word)
			assert.is_nil(bagItem(0, 3))
		end)

		it("asks, with the game's word, before deleting an item whose quality is not known yet", function()
			Test.state.bags[0].items[4] = { itemID = 4, link = "[Unknown]", name = "Unknown", count = 1 }
			Test.FireEvent("BAG_UPDATE_DELAYED")
			dragOut(0, 4)
			assert.is_not_nil(bagItem(0, 4))
			assert.is_true(confirm():IsShown())
			assert.is_true(confirm().word:IsShown())
			assert.same({}, Test.state.bagActions)
		end)

		it("deletes nothing when the stack grew while the question was open", function()
			dragOut(0, 2)
			bagItem(0, 2).count = 25
			confirm().delete.scripts.OnClick(confirm().delete)
			assert.equals(25, bagItem(0, 2).count)
			assert.same({}, Test.state.bagActions)
			assert.matches("moved or changed", Test.state.printed[#Test.state.printed])
		end)

		it("deletes nothing that went into an equipment set while the question was open", function()
			dragOut(0, 2)
			Test.state.bags[0].protections = { [2] = { equipmentSet = true } }
			confirm().delete.scripts.OnClick(confirm().delete)
			assert.is_not_nil(bagItem(0, 2))
			assert.same({}, Test.state.bagActions)
			assert.matches("equipment set", Test.state.printed[#Test.state.printed])
		end)

		it("deletes nothing while the cursor holds something", function()
			Test.state.cursor = { bag = 2, slot = 5 }
			dragOut(0, 1)
			assert.is_not_nil(bagItem(0, 1))
			assert.same({}, Test.state.bagActions)
			assert.matches("Put down", Test.state.printed[#Test.state.printed])
		end)

		it("deletes nothing when another item moved into the slot, or the item is locked", function()
			local listed = entry(0, 1)
			bagItem(0, 1).guid = "another"
			Toss.Delete(listed)
			assert.is_not_nil(bagItem(0, 1))
			bagItem(0, 1).guid = nil
			bagItem(0, 1).locked = true
			Toss.Delete(listed)
			assert.is_not_nil(bagItem(0, 1))
			assert.same({}, Test.state.bagActions)
		end)

		it("puts the item back when the cursor ends up holding something else", function()
			local listed = entry(0, 1)
			local pickup = ns.Compat.PickupBagItem
			ns.Compat.PickupBagItem = function()
				Test.state.cursor = { bag = 1, slot = 1 }
			end
			Toss.Delete(listed)
			ns.Compat.PickupBagItem = pickup
			assert.is_not_nil(bagItem(0, 1))
			assert.same({ { "clear" } }, Test.state.bagActions)
			assert.is_nil(Test.state.cursor)
		end)
	end)
end)
