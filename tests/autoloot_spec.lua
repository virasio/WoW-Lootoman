local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("fast autoloot settings", function()
	it("are on the options' main page: its switch and the bind-on-pickup option under it, both on by default", function()
		local api = SettingsAPI.Install()
		rawset(_G, "StaticPopup_Hide", function() end)
		local ns = Loader.LoadAddon({ skip = {} })
		Loader.Start(ns)
		local shown = {}
		for _, item in ipairs(ns.SettingsPanel.main.items) do
			if item.kind == "checkbox" and (item.text or ""):match("autoloot") or (item.text or ""):match("bind%-on%-pickup") then
				shown[#shown + 1] = ("%s@%d=%s"):format(item.text, item.indent, tostring(item.region.checked))
			end
		end
		assert.same({ "Enable fast autoloot@0=true", "Confirm bind-on-pickup items when alone@24=true" }, shown)
		assert.is_nil(api.FindCategory("Fast autoloot"))
		assert.is_true(ns.Modules:Get("AutoLoot"):IsActive())
	end)
end)

describe("fast autoloot", function()
	local ns, Test, actions, skipped, hiddenPopups

	local LINEN = { kind = "item", name = "Linen Cloth", link = "|Hitem:2589::|h[Linen Cloth]|h", quantity = 2, quality = 1 }
	local HEARTHSTONE = { kind = "item", name = "Hearthstone", link = "|Hitem:6948::|h[Hearthstone]|h", quantity = 1, quality = 1 }
	local MONEY = { kind = "money", name = "21 Copper", quantity = 0 }
	local CURRENCY = { kind = "currency", name = "Valorstones", quantity = 5, currencyID = 3008 }

	-- A backpack with the given number of free slots.
	local function backpack(free)
		local items = {}
		for slot = 1, 16 - free do
			items[slot] = { itemID = 1, count = 1 }
		end
		Test.SetBags({ [0] = { size = 16, items = items } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
	end

	-- Why the loot window was shown, from the debug output.
	local function shown()
		local reasons = {}
		for _, line in ipairs(Test.state.printed) do
			reasons[#reasons + 1] = line:match("loot window shown %((.-)%)")
		end
		return reasons
	end

	local function open(slots, autoLoot)
		Test.SetLoot(slots)
		Test.FireEvent("LOOT_READY", autoLoot == nil and true or autoLoot)
	end

	before_each(function()
		hiddenPopups = {}
		rawset(_G, "StaticPopup_Hide", function(which) hiddenPopups[#hiddenPopups + 1] = which end)
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test = ns.Compat.Test
		actions = Test.state.lootActions
		Test.SetItems({
			[1] = { name = "Filler", stackSize = 1 },
			[2589] = { name = "Linen Cloth", stackSize = 200, isCraftingReagent = true },
			[6948] = { name = "Hearthstone", stackSize = 1 },
		})
		backpack(10)
		skipped = {}
		ns.Bus:On("LootSkipped", "test", function(_, entry) skipped[#skipped + 1] = entry end)
		ns.Storage:SetGlobal("debug", true)
	end)

	it("loots one slot at a time, from the last, each after the previous one is cleared", function()
		open({ LINEN, HEARTHSTONE, MONEY })
		assert.same({ { "loot", 3 } }, actions)
		Test.ClearLootSlot(3)
		assert.same({ { "loot", 3 }, { "loot", 2 } }, actions)
		Test.ClearLootSlot(2)
		Test.ClearLootSlot(1)
		assert.same({ { "loot", 3 }, { "loot", 2 }, { "loot", 1 } }, actions)
		assert.same({}, shown())
	end)

	it("takes the first event of a loot and ignores its repeats", function()
		open({ LINEN, HEARTHSTONE })
		Test.FireEvent("LOOT_OPENED", true, false)
		Test.FireEvent("LOOT_READY", true)
		Test.ClearLootSlot(2)
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 2 }, { "loot", 1 } }, actions)
	end)

	it("leaves the loot to the game when it does not loot automatically, even if a repeat says so", function()
		open({ LINEN }, false)
		Test.FireEvent("LOOT_READY", true)
		assert.same({}, actions)
		Test.FireEvent("LOOT_CLOSED")
		open({ LINEN }, true)
		assert.same({ { "loot", 1 } }, actions)
	end)

	it("asks the game's auto loot setting when the event does not say", function()
		Test.SetLoot({ LINEN })
		Test.SetCVar("autoLootDefault", false)
		Test.FireEvent("LOOT_READY")
		assert.same({}, actions)
		Test.FireEvent("LOOT_CLOSED")
		Test.SetCVar("autoLootDefault", true)
		Test.FireEvent("LOOT_READY")
		assert.same({ { "loot", 1 } }, actions)
	end)

	it("waits for its own slot while the game clears others", function()
		open({ LINEN, HEARTHSTONE, MONEY })
		Test.ClearLootSlot(1)
		assert.same({ { "loot", 3 } }, actions)
		Test.ClearLootSlot(3)
		assert.same({ { "loot", 3 }, { "loot", 2 } }, actions)
	end)

	it("skips slots the game has looted meanwhile", function()
		open({ LINEN, HEARTHSTONE, MONEY })
		Test.ClearLootSlot(2)
		Test.ClearLootSlot(3)
		assert.same({ { "loot", 3 }, { "loot", 1 } }, actions)
	end)

	it("skips items that do not fit, reports them and shows the window at the end", function()
		backpack(0)
		open({ HEARTHSTONE, MONEY, CURRENCY })
		assert.same({ { "loot", 3 } }, actions)
		assert.same({ { kind = "skipped", name = "Hearthstone", link = HEARTHSTONE.link, quality = 1, amount = 1 } }, skipped)
		Test.ClearLootSlot(3)
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 3 }, { "loot", 2 } }, actions)
		assert.same({ "no room" }, shown())
	end)

	it("does not let two items count on the same free slot", function()
		backpack(1)
		open({ HEARTHSTONE, MONEY, HEARTHSTONE })
		assert.same({ { "loot", 3 } }, actions)
		assert.same({ { kind = "skipped", name = "Hearthstone", link = HEARTHSTONE.link, quality = 1, amount = 1 } }, skipped)
		Test.ClearLootSlot(3)
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 3 }, { "loot", 2 } }, actions)
		assert.same({ "no room" }, shown())
	end)

	it("loots money and currency with full bags, and stacks that fit into partial stacks", function()
		Test.SetBags({ [0] = { size = 1, items = { [1] = { itemID = 2589, count = 100 } } } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		open({ LINEN, MONEY, CURRENCY })
		Test.ClearLootSlot(3)
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 3 }, { "loot", 2 }, { "loot", 1 } }, actions)
		assert.same({}, skipped)
	end)

	it("leaves locked slots and shows the window", function()
		open({ { kind = "item", name = "Rolled", link = "|Hitem:6948::|h[Rolled]|h", locked = true }, MONEY })
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 2 } }, actions)
		assert.same({ "locked" }, shown())
	end)

	it("tries a slot whose link the client keeps secret", function()
		backpack(0)
		open({ { kind = "item", name = "Secret", link = { secret = true }, quantity = 1 } })
		assert.same({ { "loot", 1 } }, actions)
		assert.same({}, skipped)
	end)

	it("stops when a slot is not cleared in time, and does not continue later", function()
		open({ LINEN, HEARTHSTONE })
		Test.Advance(ns.Modules:Get("AutoLoot").SLOT_TIMEOUT)
		assert.same({ "timeout" }, shown())
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 2 } }, actions)
	end)

	it("does not time out a slot that was cleared in time", function()
		open({ LINEN, HEARTHSTONE })
		Test.Advance(0.5)
		Test.ClearLootSlot(2)
		Test.Advance(0.6)
		assert.same({}, shown())
	end)

	it("stops on a loot error, but not on other errors", function()
		open({ LINEN, HEARTHSTONE })
		Test.FireGameError("ERR_OUT_OF_RANGE")
		assert.same({}, shown())
		Test.FireGameError("ERR_INV_FULL")
		assert.same({ "error" }, shown())
		Test.ClearLootSlot(2)
		assert.same({ { "loot", 2 } }, actions)
	end)

	it("confirms bind-on-pickup items when alone and closes Blizzard's question", function()
		open({ LINEN, HEARTHSTONE })
		Test.FireEvent("LOOT_BIND_CONFIRM", 2)
		assert.same({ { "loot", 2 }, { "confirm", 2 } }, actions)
		assert.same({ "LOOT_BIND" }, hiddenPopups)
		Test.ClearLootSlot(2)
		assert.same({ "loot", 1 }, actions[3])
	end)

	it("leaves bind-on-pickup items to the player in a group", function()
		Test.SetGroup(true)
		open({ LINEN, HEARTHSTONE })
		Test.FireEvent("LOOT_BIND_CONFIRM", 2)
		assert.same({ { "loot", 2 } }, actions)
		assert.same({ "bind" }, shown())
	end)

	it("leaves bind-on-pickup items to the player when the setting is off", function()
		ns.Storage:Set("AutoLoot", "confirmBind", false)
		open({ LINEN, HEARTHSTONE })
		Test.FireEvent("LOOT_BIND_CONFIRM", 2)
		assert.same({ "bind" }, shown())
		assert.same({}, hiddenPopups)
	end)

	it("starts anew with the next loot", function()
		open({ LINEN })
		Test.ClearLootSlot(1)
		Test.FireEvent("LOOT_CLOSED")
		Test.FireEvent("LOOT_CLOSED")
		open({ HEARTHSTONE, MONEY })
		assert.same({ { "loot", 1 }, { "loot", 2 } }, actions)
	end)

	it("does nothing while turned off", function()
		ns.Modules:SetEnabled("AutoLoot", false)
		assert.is_false(Test.IsRegistered("LOOT_READY"))
		open({ LINEN })
		assert.same({}, actions)
	end)
end)
