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

		it("changes the game's Auto Loot only where the client lets addons, and out of combat", function()
			local info, set, combat = { "0", "1", false, false, false, false, false }, {}, false
			stub({
				C_CVar = {
					GetCVarBool = function() return false end,
					GetCVarInfo = function(name)
						if name == "autoLootDefault" then
							return unpack(info)
						end
					end,
					SetCVar = function(name, value) set[#set + 1] = name .. "=" .. value; return true end,
				},
				InCombatLockdown = function() return combat end,
			})
			assert.is_true(Compat.CanSetAutoLoot())
			assert.is_true(Compat.SetAutoLoot(true))
			assert.same({ "autoLootDefault=1" }, set)
			combat = true
			assert.is_false(Compat.SetAutoLoot(false))
			combat = false
			info[6] = true
			assert.is_false(Compat.CanSetAutoLoot())
			info[6], info[7] = false, true
			assert.is_false(Compat.SetAutoLoot(false))
			assert.same({ "autoLootDefault=1" }, set)
		end)

		it("sets the Auto Loot key and saves it with the current key bindings, out of combat", function()
			local calls, combat = {}, false
			stub({
				GetModifiedClick = function(action) return action == "AUTOLOOTTOGGLE" and "SHIFT" or nil end,
				SetModifiedClick = function(action, key) calls[#calls + 1] = action .. "=" .. key end,
				GetCurrentBindingSet = function() return 2 end,
				SaveBindings = function(set) calls[#calls + 1] = "save " .. set end,
				InCombatLockdown = function() return combat end,
			})
			assert.equals("SHIFT", Compat.GetAutoLootKey())
			assert.is_true(Compat.SetAutoLootKey("CTRL"))
			assert.same({ "AUTOLOOTTOGGLE=CTRL", "save 2" }, calls)
			combat = true
			assert.is_false(Compat.SetAutoLootKey("ALT"))
			assert.equals(2, #calls)
			combat = false
			rawset(_G, "SaveBindings", nil)
			assert.same({ false, false }, { Compat.CanSetAutoLootKey(), Compat.SetAutoLootKey("ALT") })
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
							return { itemID = 2589, stackCount = 7, hyperlink = "link", isLocked = false, itemName = "Linen Cloth",
								quality = 1, iconFileID = 132889, isBound = false, hasNoValue = false }
						end
					end,
				},
			})
			assert.same({ 3, 0 }, { Compat.GetBagFreeSlots(0) })
			assert.same({ 4, 32 }, { Compat.GetBagFreeSlots(1) })
			assert.same({ itemID = 2589, count = 7, link = "link", name = "Linen Cloth", quality = 1, icon = 132889,
				bound = false, noValue = false, locked = false }, Compat.GetBagItem(0, 1))
			assert.is_nil(Compat.GetBagItem(0, 2))
		end)

		it("reads what decides whether a bag item can be used, a recipe's knowledge from its tooltip", function()
			stub({
				C_Container = {
					GetContainerItemInfo = function(_, slot)
						return slot <= 2 and { itemID = slot == 1 and 100 or 200, hasLoot = slot == 1 } or nil
					end,
					GetContainerItemQuestInfo = function(_, slot)
						return { isQuestItem = slot == 1, questID = slot == 1 and 500 or nil, isActive = false }
					end,
				},
				C_Item = {
					GetItemInfoInstant = function(item) return item, "Kind", "Subkind", "", 1, item == 200 and 9 or 15, 0 end,
					IsUsableItem = function(item) return item == 100, false end,
				},
				Enum = { ItemClass = { Recipe = 9 } },
				C_TooltipInfo = { GetBagItem = function()
					return { lines = { { leftText = "Tailoring (75)" }, { leftText = "Already known" } } }
				end },
				ITEM_SPELL_KNOWN = "Already known",
			})
			assert.same({ itemID = 100, questID = 500, questTaken = false, recipe = false, known = false, openable = true, usable = true },
				Compat.GetBagItemUse(0, 1))
			assert.same({ itemID = 200, questTaken = false, recipe = true, known = true, openable = false, usable = false },
				Compat.GetBagItemUse(0, 2))
			assert.is_nil(Compat.GetBagItemUse(0, 3))
		end)

		it("reads what an item adds to a collection, on the collections the client has", function()
			stub({
				C_PetJournal = {
					GetPetInfoByItemID = function(item)
						if item == 1 then
							return "Cat", 1, 2, 3, "", "", false, false, 0, 0, 0, 5, 77
						end
					end,
					GetNumCollectedInfo = function(species) return species == 77 and 3, 3 end,
				},
				C_MountJournal = {
					GetMountFromItem = function(item) return item == 2 and 40 or nil end,
					GetMountInfoByID = function() return "Horse", 1, 2, false, true, 0, false, false, nil, false, false, 40 end,
				},
				C_ToyBox = { GetToyInfo = function(item) return item == 3 and item or nil end },
				PlayerHasToy = function() return true end,
				C_Item = { GetItemLearnTransmogSet = function(item) return item == 4 and 900 or nil end },
				C_TransmogSets = { GetSetInfo = function() return { collected = false } end },
				C_Heirloom = { IsItemHeirloom = function(item) return item == 5 end, PlayerHasHeirloom = function() return false end },
			})
			assert.same({ pet = true, mount = true, toy = true, set = true, heirloom = true }, Compat.GetCollectionKinds())
			assert.same({ { kind = "pet", collected = true }, { kind = "mount", collected = false }, { kind = "toy", collected = true },
				{ kind = "set", collected = false }, { kind = "heirloom", collected = false } },
				{ Compat.GetCollectible(1), Compat.GetCollectible(2), Compat.GetCollectible(3), Compat.GetCollectible(4),
					Compat.GetCollectible(5) })
			assert.is_nil(Compat.GetCollectible(6))
			-- A client without the pet and mount journals.
			rawset(_G, "C_PetJournal", nil)
			rawset(_G, "C_MountJournal", nil)
			assert.same({ false, false, true }, { Compat.GetCollectionKinds().pet, Compat.GetCollectionKinds().mount,
				Compat.GetCollectionKinds().toy })
			assert.is_nil(Compat.GetCollectible(1))
		end)

		it("reads what protects an item in a bag slot, and its guid", function()
			local exists = true
			stub({
				ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end },
				C_Item = {
					DoesItemExist = function() return exists end,
					GetItemGUID = function(location) return ("Item-%d-%d"):format(location.bag, location.slot) end,
				},
				C_Container = {
					GetContainerItemQuestInfo = function(_, slot)
						return { isQuestItem = slot == 1, questID = slot == 2 and 100 or nil, isActive = false }
					end,
					GetContainerItemEquipmentSetInfo = function(_, slot) return slot == 3, slot == 3 and "Tank" or "" end,
					GetContainerItemPurchaseInfo = function(_, slot)
						if slot == 4 then
							return { money = 100, itemCount = 1, refundSeconds = 7000, currencyCount = 0, hasEnchants = false }
						elseif slot == 5 then
							return { money = 100, itemCount = 1, refundSeconds = 0, currencyCount = 0, hasEnchants = false }
						end
					end,
				},
			})
			local function facts(slot)
				local found = Compat.GetBagItemFacts(0, slot)
				return { found.quest, found.equipmentSet, found.refundable }
			end
			assert.same({ true, false, false }, facts(1))
			assert.same({ true, false, false }, facts(2))
			assert.same({ false, true, false }, facts(3))
			assert.same({ false, false, true }, facts(4))
			assert.same({ false, false, false }, facts(5))
			assert.equals("Item-0-6", Compat.GetBagItemFacts(0, 6).guid)
			exists = false
			assert.is_nil(Compat.GetBagItemFacts(0, 6).guid)
		end)

		it("reads the bags left out of junk selling, the backpack apart", function()
			stub({
				Enum = { BagIndex = { Backpack = 0 }, BagSlotFlags = { ExcludeJunkSell = 64 } },
				C_Container = {
					GetBackpackSellJunkDisabled = function() return true end,
					GetBagSlotFlag = function(bag, flag) return bag == 2 and flag == 64 end,
				},
			})
			assert.same({ true, false, true }, { Compat.IsBagKeptFromJunkSale(0), Compat.IsBagKeptFromJunkSale(1),
				Compat.IsBagKeptFromJunkSale(2) })
			stub({ Enum = { BagIndex = { Backpack = 0 } }, C_Container = {} })
			assert.same({ false, false }, { Compat.IsBagKeptFromJunkSale(0), Compat.IsBagKeptFromJunkSale(2) })
		end)

		it("finds the bag slot of the item on the cursor", function()
			local held
			stub({
				GetCursorInfo = function() return held and "item" or nil end,
				C_Cursor = {
					GetCursorItem = function()
						if held then
							return {
								IsBagAndSlot = function() return held.bag ~= nil end,
								GetBagAndSlot = function() return held.bag, held.slot end,
							}
						end
					end,
				},
			})
			assert.is_true(Compat.IsCursorEmpty())
			assert.is_nil(Compat.GetCursorBagSlot())
			held = { bag = 2, slot = 7 }
			assert.is_false(Compat.IsCursorEmpty())
			assert.same({ 2, 7 }, { Compat.GetCursorBagSlot() })
			held = {}
			assert.is_nil(Compat.GetCursorBagSlot())
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
			assert.same({ name = "Linen Cloth", link = "link", quality = 1, stackSize = 200, sellPrice = 13, isCraftingReagent = true },
				Compat.GetItemInfo(2589))
			assert.is_nil(Compat.GetItemInfo(999))
			assert.equals(32, Compat.GetItemFamily(765))
			assert.equals(0, Compat.GetItemFamily(2589))
		end)

	end)

	describe("currencies", function()
		it("read a currency with its cap, a seasonal cap counting what was earned", function()
			stub({ C_CurrencyInfo = { GetCurrencyInfo = function(id)
				return { name = "Crest", iconFileID = 5, quality = 4, quantity = 30, discovered = true, maxQuantity = 90,
					totalEarned = 70, useTotalEarnedForMaxQty = id == 2 }
			end } })
			assert.same({ name = "Crest", icon = 5, quality = 4, quantity = 30, discovered = true, max = 90, totalEarned = 70,
				capsTotalEarned = false }, Compat.GetCurrencyInfo(1))
			assert.is_true(Compat.GetCurrencyInfo(2).capsTotalEarned)
		end)
	end)

	it("counts an item in the bags and bank, or in the bags only", function()
		local asked = {}
		stub({ C_Item = { GetItemCount = function(...) asked[#asked + 1] = { ... } return 7 end } })
		assert.same({ 7, 7 }, { Compat.GetItemCount(2589), Compat.GetItemCount(2589, true) })
		assert.same({ { 2589, true, false, true, false }, { 2589, false, false, false, false } }, asked)
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

describe("Compat for highlights", function()
	local Compat
	local SECRET = { secret = true }

	before_each(function()
		Compat = loadCompat("Compat/Compat.lua")
		stub({
			issecretvalue = function(value) return value == SECRET end,
			InCombatLockdown = function() return false end,
		})
	end)

	it("reads game settings, nil when unknown or secret, and changes them only out of combat", function()
		local values, set, combat = { SoftTargetInteract = "1", Hidden = SECRET }, {}, false
		stub({
			C_CVar = {
				GetCVar = function(name) return values[name] end,
				SetCVar = function(name, value) set[#set + 1] = name .. "=" .. value; return true end,
			},
			InCombatLockdown = function() return combat end,
		})
		assert.same({ "1", nil, nil }, { Compat.GetCVar("SoftTargetInteract"), Compat.GetCVar("Missing"), Compat.GetCVar("Hidden") })
		assert.is_true(Compat.SetCVar("SoftTargetInteract", 3))
		combat = true
		assert.is_false(Compat.SetCVar("SoftTargetInteract", 0))
		assert.same({ "SoftTargetInteract=3" }, set)
	end)

	it("tells the soft interact target's facts, leaving out what the client keeps secret", function()
		local probe = { texture = nil }
		function probe:Hide() end
		function probe:SetTexture(texture) self.texture = texture end
		function probe:GetTexture() return self.texture end
		function probe:GetAtlas() return nil end
		local exists, name, guid, inReach = true, "Peacebloom", "GameObject-0-1-2-3-1617-00004A1B2C", false
		stub({
			UnitExists = function(unit) return unit == "softinteract" and exists end,
			UnitIsGameObject = function() return true end,
			UnitIsDead = function() return false end,
			UnitGUID = function() return guid end,
			UnitName = function() return name end,
			UIParent = { CreateTexture = function() return probe end },
			SetUnitCursorTexture = function(texture, unit, _, lowPriority)
				texture:SetTexture(unit == "softinteract" and lowPriority and 136126 or nil)
				return true
			end,
			UnitIsInInteractRange = function() return inReach end,
			C_QuestLog = { UnitIsRelatedToActiveQuest = function() return false end },
			C_TooltipInfo = { GetUnit = function() return { lines = { { type = 8 } } } end },
			Enum = { TooltipDataLineType = { QuestObjective = 8 } },
		})
		local facts = Compat.GetSoftInteract()
		assert.same({ true, false, false, 1617, "Peacebloom", 136126, false, false, true },
			{ facts.isObject, facts.isDead, facts.isLiving, facts.objectID, facts.name, facts.cursor, facts.inReach,
				facts.questRelated, facts.questObjective })
		name, guid, inReach = SECRET, SECRET, SECRET
		facts = Compat.GetSoftInteract()
		assert.same({ nil, nil, nil, true }, { facts.name, facts.objectID, facts.inReach, facts.isObject })
		-- A creature's GUID gives no object ID; no target, no facts.
		name, guid = "Wolf", "Creature-0-1-2-3-525-00004A1B2C"
		assert.is_nil(Compat.GetSoftInteract().objectID)
		exists = false
		assert.is_nil(Compat.GetSoftInteract())
	end)

	it("finds the game's cursor files, the loot window's source objects and the player's position", function()
		local position = { 100, -50 }
		stub({
			GetFileIDFromPath = function(path) return path == "Interface\\Cursor\\Mine.blp" and 136126 or nil end,
			GetNumLootItems = function() return 2 end,
			GetLootSourceInfo = function(slot)
				if slot == 1 then
					return "GameObject-0-1-2-3-1617-0000AA", 1, "Creature-0-1-2-3-525-0000BB", 2
				end
				return "GameObject-0-1-2-3-1617-0000CC", 1
			end,
			UnitPosition = function() return position[1], position[2], 0, 1 end,
		})
		assert.same({ 136126, nil }, { Compat.GetCursorFileID("Mine"), Compat.GetCursorFileID("GatherHerbs") })
		assert.same({ 1617 }, Compat.GetLootSourceObjects())
		assert.same({ 100, -50 }, { Compat.GetPlayerPosition() })
		position = { SECRET, -50 }
		assert.is_nil(Compat.GetPlayerPosition())
	end)

	it("knows Herbalism and Mining from the tracking spells, the skill lines or the professions", function()
		local spells, lines = {}
		local function unset(...)
			for _, name in ipairs({ ... }) do
				rawset(_G, name, nil)
			end
		end
		unset("C_SkillInfo", "GetProfessions", "GetProfessionInfo", "IsPlayerSpell")
		stub({ C_SpellBook = { IsSpellKnown = function(spell) return spells[spell] == true end } })
		assert.same({ false, false }, { Compat.GetGatheringSkills().herbs, Compat.GetGatheringSkills().ore })
		spells[8387] = true
		assert.same({ true, false }, { Compat.GetGatheringSkills().herbs, Compat.GetGatheringSkills().ore })
		-- WoW Forever's skill lines: Mining with a rank.
		spells = {}
		stub({ C_SkillInfo = {
			GetNumSkillLines = function() return 3 end,
			GetSkillLineInfoByID = function(line) return line == 186 and { maxRank = 75 } or { maxRank = 0 } end,
		} })
		assert.same({ false, true }, { Compat.GetGatheringSkills().herbs, Compat.GetGatheringSkills().ore })
		-- The professions list.
		unset("C_SkillInfo", "C_SpellBook")
		stub({ GetProfessions = function() return 1, nil, nil, 4 end,
			GetProfessionInfo = function(index) return nil, nil, nil, nil, nil, nil, index == 1 and 182 or 356 end })
		lines = Compat.GetGatheringSkills()
		assert.same({ true, false }, { lines.herbs, lines.ore })
		-- Nothing can say.
		unset("GetProfessions", "GetProfessionInfo")
		assert.same({ nil, nil }, { Compat.GetGatheringSkills().herbs, Compat.GetGatheringSkills().ore })
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
