-- The real Compat against stubbed game globals, and the mock's contract.

local function loadCompat(path)
	local ns = {}
	assert(loadfile(path))("Lootoman", ns)
	return ns.Compat
end

local function functionNames(object)
	local names = {}
	for name, value in pairs(object) do
		if type(value) == "function" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

local function stub(globals)
	for name, value in pairs(globals) do
		rawset(_G, name, value)
	end
end

describe("Compat", function()
	local Compat

	before_each(function()
		Compat = loadCompat("Compat/Compat.lua")
	end)

	it("has the same functions as its test mock", function()
		assert.same(functionNames(Compat), functionNames(loadCompat("tests/mocks/Compat.lua")))
	end)

	it("detects capabilities by global and field path", function()
		stub({ C_FakeContainer = { GetItem = function() end } })
		assert.is_true(Compat.Has("C_FakeContainer"))
		assert.is_true(Compat.Has("C_FakeContainer.GetItem"))
		assert.is_false(Compat.Has("C_FakeContainer.Missing"))
		assert.is_false(Compat.Has("C_FakeMissing.GetItem"))
		assert.is_false(Compat.Has("C_FakeContainer.GetItem.Deeper"))
	end)

	it("builds the character key from name and realm", function()
		stub({
			UnitFullName = function() return "Ana", "Silvermoon" end,
			GetNormalizedRealmName = function() return "Other" end,
		})
		assert.equals("Ana-Silvermoon", Compat.GetCharacterKey())
	end)

	it("falls back to the normalized realm name", function()
		stub({
			UnitFullName = function() return "Ana", nil end,
			GetNormalizedRealmName = function() return "TwistingNether" end,
		})
		assert.equals("Ana-TwistingNether", Compat.GetCharacterKey())
	end)

	it("has no character key before the realm is known", function()
		stub({
			UnitFullName = function() return "Ana", "" end,
			GetNormalizedRealmName = function() return nil end,
		})
		assert.is_nil(Compat.GetCharacterKey())
	end)

	it("treats every value as not secret when the client has no secret values", function()
		rawset(_G, "issecretvalue", nil)
		assert.is_false(Compat.IsSecret(42))
	end)

	it("asks the client about secret values when it can", function()
		stub({ issecretvalue = function(value) return value == "hidden" end })
		assert.is_true(Compat.IsSecret("hidden"))
		assert.is_false(Compat.IsSecret("shown"))
	end)

	it("asks the interaction manager which kind of window is open", function()
		stub({
			Enum = { PlayerInteractionType = { Merchant = 5, MailInfo = 17 } },
			C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function(kind) return kind == 5 end },
		})
		assert.is_true(Compat.IsInteracting("Merchant"))
		assert.is_false(Compat.IsInteracting("MailInfo"))
		assert.is_false(Compat.IsInteracting("Unknown"))
		stub({ C_PlayerInteractionManager = {} })
		assert.is_false(Compat.IsInteracting("Merchant"))
	end)

	it("reports an addon as loaded only when loading has finished", function()
		stub({ C_AddOns = { IsAddOnLoaded = function(name) return true, name == "Done" end } })
		assert.is_true(Compat.IsAddOnLoaded("Done"))
		assert.is_false(Compat.IsAddOnLoaded("StillLoading"))
	end)

	describe("loot", function()
		local SLOT_TYPES = { None = 0, Item = 1, Money = 2, Currency = 3 }

		before_each(function()
			stub({
				Enum = { LootSlotType = SLOT_TYPES },
				issecretvalue = function(value) return value == "hidden" end,
				GetLootSlotLink = function(slot) return "link" .. slot end,
				GetLootSlotInfo = function(slot)
					return "icon" .. slot, "name" .. slot, slot * 10, slot == 3 and 2815 or nil, 2, false, slot == 1
				end,
			})
		end)

		it("reads a slot as a table, with a link only for items", function()
			stub({ GetLootSlotType = function(slot) return ({ 1, 0, 3, 2 })[slot] end })
			assert.same({
				kind = "item", name = "name1", icon = "icon1", quantity = 10, quality = 2,
				link = "link1", locked = false, isQuestItem = true,
			}, Compat.GetLootSlot(1))
			assert.is_nil(Compat.GetLootSlot(2))
			local currency = Compat.GetLootSlot(3)
			assert.equals("currency", currency.kind)
			assert.equals(2815, currency.currencyID)
			assert.is_nil(currency.link)
			assert.equals("money", Compat.GetLootSlot(4).kind)
		end)

		it("does not look up a slot type the client keeps secret", function()
			stub({ GetLootSlotType = function() return "hidden" end })
			assert.same({ kind = "unknown" }, Compat.GetLootSlot(1))
		end)

		it("passes loot actions to the client", function()
			local calls = {}
			stub({
				LootSlot = function(slot) calls[#calls + 1] = "loot " .. slot end,
				ConfirmLootSlot = function(slot) calls[#calls + 1] = "confirm " .. slot end,
			})
			Compat.LootSlot(2)
			Compat.ConfirmLootSlot(3)
			assert.same({ "loot 2", "confirm 3" }, calls)
		end)

		it("turns auto loot around while the auto loot key is held", function()
			local cvar, held
			stub({
				C_CVar = { GetCVarBool = function(name) return name == "autoLootDefault" and cvar or nil end },
				IsModifiedClick = function(action) return action == "AUTOLOOTTOGGLE" and held end,
			})
			for _, case in ipairs({ { true, false, true }, { true, true, false }, { nil, false, false }, { false, true, true } }) do
				cvar, held = case[1], case[2]
				assert.equals(case[3], Compat.IsAutoLootOn(), ("setting %s, key %s"):format(tostring(cvar), tostring(held)))
			end
		end)
	end)

	describe("bags", function()
		it("lists the backpack and the equipped bags, and the reagent bag", function()
			stub({
				Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 } },
				Constants = { InventoryConstants = { NumBagSlots = 4, NumReagentBagSlots = 1 } },
			})
			local bags, reagentBag = Compat.GetPlayerBags()
			assert.same({ 0, 1, 2, 3, 4 }, bags)
			assert.equals(5, reagentBag)
		end)

		it("has no reagent bag on a client without one", function()
			stub({
				Enum = { BagIndex = { Backpack = 0 } },
				Constants = { InventoryConstants = { NumBagSlots = 4 } },
			})
			assert.is_nil(select(2, Compat.GetPlayerBags()))
			stub({
				Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 } },
				Constants = { InventoryConstants = { NumBagSlots = 4, NumReagentBagSlots = 0 } },
			})
			assert.is_nil(select(2, Compat.GetPlayerBags()))
		end)

		it("reads free slots, bag families and items", function()
			stub({
				C_Container = {
					GetContainerNumFreeSlots = function(bag) return bag + 3, bag == 1 and 32 or nil end,
					GetContainerItemInfo = function(_, slot)
						if slot == 1 then
							return { itemID = 2589, stackCount = 7, hyperlink = "link", isLocked = false }
						end
					end,
				},
			})
			assert.same({ 3, 0 }, { Compat.GetBagFreeSlots(0) })
			assert.same({ 4, 32 }, { Compat.GetBagFreeSlots(1) })
			assert.same({ itemID = 2589, count = 7, link = "link" }, Compat.GetBagItem(0, 1))
			assert.is_nil(Compat.GetBagItem(0, 2))
		end)

		it("reads item data, or nothing while the client has not loaded the item", function()
			stub({
				C_Item = {
					GetItemFamily = function(item) return item == 765 and 32 or nil end,
					GetItemInfo = function(item)
						if item == 2589 then
							return "Linen Cloth", "link", 1, 5, 0, "Tradeskill", "Cloth", 200, "", 1, 13, 7, 5, 0, 0, nil, true
						end
					end,
				},
			})
			assert.same({ name = "Linen Cloth", link = "link", quality = 1, stackSize = 200, isCraftingReagent = true },
				Compat.GetItemInfo(2589))
			assert.is_nil(Compat.GetItemInfo(999))
			assert.equals(32, Compat.GetItemFamily(765))
			assert.equals(0, Compat.GetItemFamily(2589))
		end)
	end)

	it("registers slash commands the way the game expects", function()
		local handler = function() end
		stub({ SlashCmdList = {} })
		Compat.RegisterSlashCommand("FAKEADDON", { "/fake", "/fk" }, handler)
		assert.equals("/fake", rawget(_G, "SLASH_FAKEADDON1"))
		assert.equals("/fk", rawget(_G, "SLASH_FAKEADDON2"))
		assert.equals(handler, rawget(_G, "SlashCmdList").FAKEADDON)
	end)
end)

describe("Compat mock", function()
	local Compat

	before_each(function()
		Compat = loadCompat("tests/mocks/Compat.lua")
	end)

	it("runs timers when time moves past them", function()
		local ran = {}
		Compat.After(1, function() ran[#ran + 1] = "one" end)
		Compat.After(5, function() ran[#ran + 1] = "five" end)
		Compat.Test.Advance(2)
		assert.same({ "one" }, ran)
		Compat.Test.Advance(3)
		assert.same({ "one", "five" }, ran)
	end)

	it("fires combat events when combat changes", function()
		local fired = {}
		Compat.RegisterEvent("PLAYER_REGEN_DISABLED", function(event) fired[#fired + 1] = event end)
		Compat.RegisterEvent("PLAYER_REGEN_ENABLED", function(event) fired[#fired + 1] = event end)
		Compat.Test.SetCombat(true)
		assert.is_true(Compat.InCombat())
		Compat.Test.SetCombat(false)
		assert.same({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }, fired)
	end)

	it("has a loot window that keeps its size while slots are looted", function()
		local cleared = {}
		Compat.RegisterEvent("LOOT_SLOT_CLEARED", function(_, slot) cleared[#cleared + 1] = slot end)
		Compat.Test.SetLoot({ { kind = "item", name = "Linen Cloth" }, { kind = "money", quantity = 150 } }, true)
		assert.equals(2, Compat.GetNumLootItems())
		assert.is_true(Compat.IsFishingLoot())
		Compat.GetLootSlot(1).name = "changed by a caller"
		assert.equals("Linen Cloth", Compat.GetLootSlot(1).name)
		Compat.Test.ClearLootSlot(1)
		assert.is_nil(Compat.GetLootSlot(1))
		assert.equals(150, Compat.GetLootSlot(2).quantity)
		assert.equals(2, Compat.GetNumLootItems())
		assert.same({ 1 }, cleared)
	end)

	it("records loot actions in order", function()
		Compat.LootSlot(2)
		Compat.ConfirmLootSlot(2)
		assert.same({ { "loot", 2 }, { "confirm", 2 } }, Compat.Test.state.lootActions)
	end)

	it("turns auto loot around while the auto loot key is held, like the client", function()
		assert.is_true(Compat.IsAutoLootOn())
		Compat.Test.SetModifier("AUTOLOOTTOGGLE", true)
		assert.is_false(Compat.IsAutoLootOn())
		Compat.Test.SetCVar("autoLootDefault", false)
		assert.is_true(Compat.IsAutoLootOn())
	end)

	it("can put the player in a group", function()
		assert.is_false(Compat.IsInGroup())
		Compat.Test.SetGroup(true)
		assert.is_true(Compat.IsInGroup())
	end)
end)
