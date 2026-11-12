local _, ns = ...

-- The only code that reads the game's data and state. Tests
-- replace this file with tests/mocks/Compat.lua, which has the same functions.
local Compat = {}
ns.Compat = Compat

-- Capability detection: Has("C_Container.GetContainerItemInfo")
-- is true when that global, or field path below a global, exists.
function Compat.Has(path)
	local value = _G
	for part in path:gmatch("[^%.]+") do
		if type(value) ~= "table" then
			return false
		end
		value = value[part]
	end
	return value ~= nil
end

local eventFrame
local eventHandlers = {}

-- One handler per event; the event bus fans it out to its listeners.
function Compat.RegisterEvent(event, handler)
	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:SetScript("OnEvent", function(_, firedEvent, ...)
			local eventHandler = eventHandlers[firedEvent]
			if eventHandler then
				eventHandler(firedEvent, ...)
			end
		end)
	end
	eventHandlers[event] = handler
	eventFrame:RegisterEvent(event)
end

function Compat.UnregisterEvent(event)
	eventHandlers[event] = nil
	if eventFrame then
		eventFrame:UnregisterEvent(event)
	end
end

-- "Name-Realm"; nil until the character is known (PLAYER_LOGIN).
function Compat.GetCharacterKey()
	local name, realm = UnitFullName("player")
	if not realm or realm == "" then
		realm = GetNormalizedRealmName()
	end
	if not name or not realm or realm == "" then
		return nil
	end
	return name .. "-" .. realm
end

function Compat.InCombat()
	return InCombatLockdown() == true
end

-- Midnight: some values are secret during combat and must not be compared or
-- used in arithmetic. Clients without secret values have no issecretvalue.
function Compat.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Compat.IsAddOnLoaded(name)
	local _, loaded = C_AddOns.IsAddOnLoaded(name)
	return loaded == true
end

function Compat.GetAddOnMetadata(name, field)
	return C_AddOns.GetAddOnMetadata(name, field)
end

function Compat.After(seconds, callback)
	C_Timer.After(seconds, callback)
end

-- Seconds since an arbitrary point, with fractions; for measuring time.
function Compat.GetTime()
	return GetTime()
end

-- version ("12.1.5"), build, date, interface number (120105).
function Compat.GetBuildInfo()
	local version, build, date, interface = GetBuildInfo()
	return version, build, date, interface
end

-- The game's project (WOW_PROJECT_ID: 1 for retail, other numbers for other
-- games on the same client), or nil when the client does not say.
function Compat.GetProjectID()
	return type(WOW_PROJECT_ID) == "number" and WOW_PROJECT_ID or nil
end

-- Loot window. The global loot functions are not in the generated API docs;
-- Blizzard's LootFrame.lua uses them this way. Values may be secret in combat
-- (to verify in game with the Dev loot dump).
function Compat.GetNumLootItems()
	return GetNumLootItems()
end

local slotKinds

-- One loot slot as a table, or nil when the slot is empty (already looted):
-- kind ("item", "money", "currency", or "unknown" when the client keeps the
-- slot type secret), name, icon, quantity, quality, currencyID, link (items
-- only), locked, isQuestItem. Values are passed on as the client returns them.
function Compat.GetLootSlot(slot)
	if not slotKinds then
		local types = Enum.LootSlotType
		slotKinds = { [types.Item] = "item", [types.Money] = "money", [types.Currency] = "currency" }
	end
	local slotType = GetLootSlotType(slot)
	if Compat.IsSecret(slotType) then
		return { kind = "unknown" }
	end
	local kind = slotKinds[slotType]
	if not kind then
		return nil
	end
	local icon, name, quantity, currencyID, quality, locked, isQuestItem = GetLootSlotInfo(slot)
	return {
		kind = kind,
		name = name,
		icon = icon,
		quantity = quantity,
		quality = quality,
		currencyID = currencyID,
		link = kind == "item" and GetLootSlotLink(slot) or nil,
		locked = locked,
		isQuestItem = isQuestItem,
	}
end

function Compat.LootSlot(slot)
	LootSlot(slot)
end

-- Picks up a bind-on-pickup item after LOOT_BIND_CONFIRM.
function Compat.ConfirmLootSlot(slot)
	ConfirmLootSlot(slot)
end

function Compat.IsFishingLoot()
	return IsFishingLoot() == true
end

-- The game's auto loot setting, reversed while the auto loot key is held.
function Compat.IsAutoLootOn()
	return (C_CVar.GetCVarBool("autoLootDefault") == true) ~= (IsModifiedClick("AUTOLOOTTOGGLE") == true)
end

function Compat.IsInGroup()
	return IsInGroup() == true
end

-- Whether a window of this kind is open with an NPC or a player: a name of
-- Enum.PlayerInteractionType, such as "Merchant", "MailInfo" or "Banker". False
-- on a client without the interaction manager or that kind.
function Compat.IsInteracting(kind)
	local interaction = Enum.PlayerInteractionType and Enum.PlayerInteractionType[kind]
	if not interaction or not Compat.Has("C_PlayerInteractionManager.IsInteractingWithNpcOfType") then
		return false
	end
	return C_PlayerInteractionManager.IsInteractingWithNpcOfType(interaction) == true
end

-- The name of a game error from UI_ERROR_MESSAGE, such as "ERR_INV_FULL", the
-- same in every language (Blizzard's UIErrorsFrame reads it this way).
function Compat.GetGameErrorName(errorType)
	return (GetGameMessageInfo(errorType))
end

-- The player's bags, as Blizzard's ContainerFrame.lua finds them: a list of the
-- backpack and the equipped bags, and the reagent bag, or nil on a client
-- without one.
function Compat.GetPlayerBags()
	local constants = Constants.InventoryConstants
	local bags = {}
	for bag = Enum.BagIndex.Backpack, constants.NumBagSlots do
		bags[#bags + 1] = bag
	end
	local reagentBag = Enum.BagIndex.ReagentBag
	if reagentBag and (constants.NumReagentBagSlots or 0) >= 1 then
		return bags, reagentBag
	end
	return bags, nil
end

-- Free slots and the bag family: 0 for general bags, a bit field for
-- profession bags.
function Compat.GetBagFreeSlots(bag)
	local free, family = C_Container.GetContainerNumFreeSlots(bag)
	return free, family or 0
end

-- Number of slots; 0 when no bag is equipped there.
function Compat.GetBagSize(bag)
	return C_Container.GetContainerNumSlots(bag)
end

-- The item in a bag slot as { itemID, count, link, name, quality, icon, bound,
-- noValue, locked }, or nil for an empty slot. quality can be nil; noValue: no
-- merchant buys it; locked: it is moving, or being sold.
function Compat.GetBagItem(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then
		return nil
	end
	return {
		itemID = info.itemID,
		count = info.stackCount,
		link = info.hyperlink,
		name = info.itemName,
		quality = info.quality,
		icon = info.iconFileID,
		bound = info.isBound == true,
		noValue = info.hasNoValue == true,
		locked = info.isLocked == true,
	}
end

-- What keeps the item in a bag slot from being tossed or sold, and who it is:
-- { quest, equipmentSet, refundable, guid }. A quest item also covers an item
-- that starts a quest; refundable: it can still be returned to its merchant.
-- guid tells this item from another one that moved into the slot; nil for an
-- empty slot.
function Compat.GetBagItemFacts(bag, slot)
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	local inSet = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
	local purchase = C_Container.GetContainerItemPurchaseInfo(bag, slot, false)
	local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
	return {
		quest = quest ~= nil and (quest.isQuestItem == true or quest.questID ~= nil),
		equipmentSet = inSet == true,
		refundable = purchase ~= nil and (purchase.refundSeconds or 0) > 0,
		guid = C_Item.DoesItemExist(location) and C_Item.GetItemGUID(location) or nil,
	}
end

-- What decides whether the item in a bag slot can be used right now:
-- { itemID, questID (the quest it starts, if any), questTaken (that quest is
-- in the log), recipe (a recipe item), known (a recipe the character knows,
-- from its tooltip's "Already known"), openable (it holds loot), usable }, or
-- nil for an empty slot.
function Compat.GetBagItemUse(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then
		return nil
	end
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	local classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
	local recipe = classID ~= nil and classID == Enum.ItemClass.Recipe
	local known = false
	if recipe and Compat.Has("C_TooltipInfo.GetBagItem") then
		local tooltip = C_TooltipInfo.GetBagItem(bag, slot)
		for _, line in ipairs(tooltip and tooltip.lines or {}) do
			known = known or line.leftText == ITEM_SPELL_KNOWN
		end
	end
	return {
		itemID = info.itemID,
		questID = quest and quest.questID or nil,
		questTaken = quest ~= nil and quest.isActive == true,
		recipe = recipe,
		known = known,
		openable = info.hasLoot == true,
		usable = C_Item.IsUsableItem(info.itemID) == true,
	}
end

-- The collections a client has, as kinds of collectible items: pet, mount,
-- toy, set (appearance sets) and heirloom.
function Compat.GetCollectionKinds()
	return {
		pet = Compat.Has("C_PetJournal.GetPetInfoByItemID") and Compat.Has("C_PetJournal.GetNumCollectedInfo"),
		mount = Compat.Has("C_MountJournal.GetMountFromItem") and Compat.Has("C_MountJournal.GetMountInfoByID"),
		toy = Compat.Has("C_ToyBox.GetToyInfo") and Compat.Has("PlayerHasToy"),
		set = Compat.Has("C_Item.GetItemLearnTransmogSet") and Compat.Has("C_TransmogSets.GetSetInfo"),
		heirloom = Compat.Has("C_Heirloom.IsItemHeirloom") and Compat.Has("C_Heirloom.PlayerHasHeirloom"),
	}
end

-- What an item adds to a collection when used: { kind, collected }, kind as
-- in GetCollectionKinds; collected is true once it is in the collection (a
-- pet: when the species is at its limit). Nil for any other item.
function Compat.GetCollectible(itemID)
	local kinds = Compat.GetCollectionKinds()
	if kinds.pet then
		local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
		if speciesID then
			local owned, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
			return { kind = "pet", collected = (owned or 0) >= (limit or 0) }
		end
	end
	if kinds.mount then
		local mountID = C_MountJournal.GetMountFromItem(itemID)
		if mountID then
			return { kind = "mount", collected = select(11, C_MountJournal.GetMountInfoByID(mountID)) == true }
		end
	end
	if kinds.toy and C_ToyBox.GetToyInfo(itemID) then
		return { kind = "toy", collected = PlayerHasToy(itemID) == true }
	end
	if kinds.set then
		local setID = C_Item.GetItemLearnTransmogSet(itemID)
		local set = setID and C_TransmogSets.GetSetInfo(setID)
		if set then
			return { kind = "set", collected = set.collected == true }
		end
	end
	if kinds.heirloom and C_Heirloom.IsItemHeirloom(itemID) then
		return { kind = "heirloom", collected = C_Heirloom.PlayerHasHeirloom(itemID) == true }
	end
	return nil
end

-- Whether the player told the game to leave a bag out of junk selling (the
-- bag's menu); Blizzard's bag menu reads the backpack's flag apart. False on a
-- client without the flag.
function Compat.IsBagKeptFromJunkSale(bag)
	if bag == Enum.BagIndex.Backpack then
		return Compat.Has("C_Container.GetBackpackSellJunkDisabled") and C_Container.GetBackpackSellJunkDisabled() == true
	end
	local flag = Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
	return flag ~= nil and Compat.Has("C_Container.GetBagSlotFlag") and C_Container.GetBagSlotFlag(bag, flag) == true
end

-- Uses the item in a bag slot as a right-click does: at an open merchant, that
-- sells it; anywhere else it uses the item (equips it, opens it), so callers
-- check for the merchant right before.
function Compat.UseBagItem(bag, slot)
	C_Container.UseContainerItem(bag, slot)
end

-- The cursor. Deleting is a pick up and a delete in the same click (one item
-- per hardware event; DeleteCursorItem deletes whatever the cursor holds,
-- without asking).
function Compat.IsCursorEmpty()
	return GetCursorInfo() == nil
end

function Compat.PickupBagItem(bag, slot)
	C_Container.PickupContainerItem(bag, slot)
end

-- The bag and slot of the item on the cursor, or nil when it holds no item from
-- the bags.
function Compat.GetCursorBagSlot()
	local location = C_Cursor.GetCursorItem()
	if location and location:IsBagAndSlot() then
		return location:GetBagAndSlot()
	end
	return nil
end

function Compat.ClearCursor()
	ClearCursor()
end

function Compat.DeleteCursorItem()
	DeleteCursorItem()
end

-- The bag families an item fits (a bit field), 0 for general bags only.
function Compat.GetItemFamily(item)
	return C_Item.GetItemFamily(item) or 0
end

-- Item data by ID, link or name: name, link, quality, stackSize, sellPrice (a
-- merchant's price for one, in copper), isCraftingReagent. Nil while the
-- client has not loaded the item yet.
function Compat.GetItemInfo(item)
	local name, link, quality, _, _, _, _, stackSize, _, _, sellPrice, _, _, _, _, _, isCraftingReagent = C_Item.GetItemInfo(item)
	if not name then
		return nil
	end
	return {
		name = name,
		link = link,
		quality = quality,
		stackSize = stackSize,
		sellPrice = sellPrice,
		isCraftingReagent = isCraftingReagent,
	}
end

-- How many of an item the character has in bags, bank and reagent bank.
function Compat.GetItemCount(item)
	return C_Item.GetItemCount(item, true, false, true, false)
end

-- An item's icon and quality, also before its full data is loaded; either can
-- be nil.
function Compat.GetItemLook(item)
	return C_Item.GetItemIconByID(item), C_Item.GetItemQualityByID(item)
end

-- A currency as { name, icon, quality, quantity, discovered, max, totalEarned,
-- capsTotalEarned }, or nil. max is 0 without a cap; with capsTotalEarned (a
-- seasonal cap) the cap counts everything earned this season, not what is
-- held.
function Compat.GetCurrencyInfo(currencyID)
	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not info then
		return nil
	end
	return {
		name = info.name,
		icon = info.iconFileID,
		quality = info.quality,
		quantity = info.quantity,
		discovered = info.discovered,
		max = info.maxQuantity or 0,
		totalEarned = info.totalEarned or 0,
		capsTotalEarned = info.useTotalEarnedForMaxQty == true,
	}
end

-- A whole number with the client's thousands separators ("12,345").
function Compat.BreakUpLargeNumbers(number)
	return BreakUpLargeNumbers(number)
end

-- Copper.
function Compat.GetMoney()
	return GetMoney()
end

-- Experience in the current level, and the experience the level needs.
function Compat.GetXP()
	return UnitXP("player"), UnitXPMax("player")
end

-- One of the client's global strings, such as the chat format LOOT_ITEM_SELF;
-- nil when the client has no such string.
function Compat.GetGlobalString(name)
	local value = _G[name]
	if type(value) == "string" then
		return value
	end
	return nil
end

-- A table as text and back, for profile texts: CBOR, Deflate and Base64, as
-- Blizzard's own import strings (C_EncodingUtil, 11.1). Both return nil when
-- the client has no encoder or the text is broken; reading a text never runs
-- code. The calls may return nothing (API docs); errors are caught too.
function Compat.CanEncode()
	return Compat.Has("C_EncodingUtil.SerializeCBOR")
end

function Compat.Encode(value)
	if not Compat.CanEncode() then
		return nil
	end
	local ok, text = pcall(function()
		local cbor = C_EncodingUtil.SerializeCBOR(value)
		local packed = cbor and C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate)
		return packed and C_EncodingUtil.EncodeBase64(packed)
	end)
	return ok and text or nil
end

function Compat.Decode(text)
	if not Compat.CanEncode() or type(text) ~= "string" then
		return nil
	end
	local ok, value = pcall(function()
		local packed = C_EncodingUtil.DecodeBase64(text)
		local cbor = packed and C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
		return cbor and C_EncodingUtil.DeserializeCBOR(cbor)
	end)
	return ok and value or nil
end

function Compat.GetSaved(name)
	return _G[name]
end

function Compat.SetSaved(name, value)
	_G[name] = value
end

-- RegisterSlashCommand("LOOTOMAN", { "/lootoman", "/ltm" }, handler)
function Compat.RegisterSlashCommand(id, commands, handler)
	for index, command in ipairs(commands) do
		_G["SLASH_" .. id .. index] = command
	end
	SlashCmdList[id] = handler
end

function Compat.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

-- Reports an error to the game's error handler (BugSack) without stopping the caller.
function Compat.ReportError(err)
	geterrorhandler()(err)
end
