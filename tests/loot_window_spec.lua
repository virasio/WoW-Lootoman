local Loader = require("tests.helpers.loader")

-- Blizzard's loot window during fast autoloot, with just enough of the
-- frames for it: LootFrame, UIParent and CreateFrame.
describe("loot window during fast autoloot", function()
	local ns, Test, UIParent, LootFrame

	local HEARTHSTONE = { kind = "item", name = "Hearthstone", link = "|Hitem:6948::|h[Hearthstone]|h", quantity = 1 }
	local MONEY = { kind = "money", name = "21 Copper", quantity = 0 }

	-- A frame takes its parent's strata when the parent changes.
	local function newFrame(parent, shown, strata)
		local frame = { parent = parent, shown = shown, strata = strata or "MEDIUM" }
		function frame:SetParent(newParent)
			self.parent = newParent
			self.strata = newParent.strata
		end
		function frame:Show() self.shown = true end
		function frame:Hide() self.shown = false end
		function frame:IsShown() return self.shown end
		function frame:IsVisible() return self.shown and (self.parent == nil or self.parent:IsVisible()) end
		function frame:GetFrameStrata() return self.strata end
		function frame:SetFrameStrata(value) self.strata = value end
		return frame
	end

	local function backpack(free)
		local items = {}
		for slot = 1, 16 - free do
			items[slot] = { itemID = 1, count = 1 }
		end
		Test.SetBags({ [0] = { size = 16, items = items } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
	end

	-- What Blizzard's LootFrame does on LOOT_OPENED.
	local function lootOpened()
		LootFrame:Show()
		Test.FireEvent("LOOT_OPENED", true, false)
	end

	before_each(function()
		UIParent = newFrame(nil, true)
		LootFrame = newFrame(UIParent, false, "HIGH")
		function LootFrame:Open()
			self.opened = (self.opened or 0) + 1
			self.shown = true
		end
		rawset(_G, "UIParent", UIParent)
		rawset(_G, "LootFrame", LootFrame)
		rawset(_G, "CreateFrame", function(_, _, parent) return newFrame(parent, true) end)
		rawset(_G, "StaticPopup_Hide", function() end)
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.SetItems({ [1] = { name = "Filler", stackSize = 1 }, [6948] = { name = "Hearthstone", stackSize = 1 } })
		backpack(10)
	end)

	it("hides the window in a hidden child of UIParent from the first LOOT_READY", function()
		Test.SetLoot({ HEARTHSTONE, MONEY })
		Test.FireEvent("LOOT_READY", true)
		local holder = LootFrame.parent
		assert.are_not.equal(UIParent, holder)
		assert.equals(UIParent, holder.parent)
		assert.is_false(holder.shown)
		lootOpened()
		assert.is_false(LootFrame:IsVisible())
	end)

	it("puts the window back closed, with its strata, when the loot closes", function()
		Test.SetLoot({ HEARTHSTONE, MONEY })
		Test.FireEvent("LOOT_READY", true)
		lootOpened()
		Test.ClearLootSlot(2)
		Test.ClearLootSlot(1)
		Test.FireEvent("LOOT_CLOSED")
		Test.FireEvent("LOOT_CLOSED")
		assert.equals(UIParent, LootFrame.parent)
		assert.is_false(LootFrame.shown)
		assert.equals("HIGH", LootFrame.strata)
		assert.is_nil(LootFrame.opened)
	end)

	it("shows the window with its list rebuilt when items do not fit", function()
		backpack(0)
		Test.SetLoot({ HEARTHSTONE, MONEY })
		Test.FireEvent("LOOT_READY", true)
		lootOpened()
		Test.ClearLootSlot(2)
		assert.equals(UIParent, LootFrame.parent)
		assert.is_true(LootFrame:IsVisible())
		assert.equals(1, LootFrame.opened)
		assert.equals("HIGH", LootFrame.strata)
	end)

	it("leaves opening to LOOT_OPENED when looting stops before it", function()
		backpack(0)
		Test.SetLoot({ HEARTHSTONE })
		Test.FireEvent("LOOT_READY", true)
		assert.equals(UIParent, LootFrame.parent)
		assert.is_false(LootFrame.shown)
		assert.is_nil(LootFrame.opened)
	end)

	it("does not move a window that is already visible", function()
		LootFrame:Show()
		Test.SetLoot({ HEARTHSTONE })
		Test.FireEvent("LOOT_READY", true)
		assert.equals(UIParent, LootFrame.parent)
	end)

	it("leaves the window alone in Edit Mode", function()
		LootFrame.isInEditMode = true
		Test.SetLoot({ HEARTHSTONE })
		Test.FireEvent("LOOT_READY", true)
		assert.equals(UIParent, LootFrame.parent)
	end)

	it("leaves the window alone when the game does not auto loot", function()
		Test.SetLoot({ HEARTHSTONE })
		Test.FireEvent("LOOT_READY", false)
		assert.equals(UIParent, LootFrame.parent)
	end)

	it("puts the window back when the module is turned off during a loot", function()
		Test.SetLoot({ HEARTHSTONE, MONEY })
		Test.FireEvent("LOOT_READY", true)
		ns.Modules:SetEnabled("AutoLoot", false)
		assert.equals(UIParent, LootFrame.parent)
		assert.equals("HIGH", LootFrame.strata)
	end)
end)
