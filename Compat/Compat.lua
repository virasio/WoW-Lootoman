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

-- The game's Auto Loot option (Options, Gameplay, Controls): the CVar
-- autoLootDefault.
function Compat.GetAutoLoot()
	return C_CVar.GetCVarBool("autoLootDefault") == true
end

-- Whether an addon may change it: the client lets addons set a CVar that is
-- neither secure nor read-only.
function Compat.CanSetAutoLoot()
	local value, _, _, _, _, isSecure, isReadOnly = C_CVar.GetCVarInfo("autoLootDefault")
	return value ~= nil and not isSecure and not isReadOnly
end

-- Turns it on or off, as the game's own options page does; not in combat.
-- Returns whether it was changed.
function Compat.SetAutoLoot(on)
	if Compat.InCombat() or not Compat.CanSetAutoLoot() then
		return false
	end
	return C_CVar.SetCVar("autoLootDefault", on and "1" or "0") == true
end

-- The Auto Loot key: the game's modified click AUTOLOOTTOGGLE, "ALT", "CTRL",
-- "SHIFT" or "NONE". While Auto Loot is on, holding it loots by hand.
function Compat.GetAutoLootKey()
	return GetModifiedClick("AUTOLOOTTOGGLE")
end

function Compat.CanSetAutoLootKey()
	return Compat.Has("SetModifiedClick") and Compat.Has("SaveBindings") and Compat.Has("GetCurrentBindingSet")
end

-- Sets the key and saves it with the key bindings, as the game's own options
-- page does; not in combat. Returns whether it was changed.
function Compat.SetAutoLootKey(key)
	if Compat.InCombat() or not Compat.CanSetAutoLootKey() then
		return false
	end
	SetModifiedClick("AUTOLOOTTOGGLE", key)
	SaveBindings(GetCurrentBindingSet())
	return true
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
-- in the log), questItem (a quest item), recipe (a recipe item), known (a recipe the character knows,
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
		questItem = quest ~= nil and quest.isQuestItem == true,
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
-- merchant's price for one, in copper), isCraftingReagent, requiredLevel,
-- classID and subclassID (Enum.ItemClass and its subclasses). Nil while the
-- client has not loaded the item yet.
function Compat.GetItemInfo(item)
	local name, link, quality, _, requiredLevel, _, _, stackSize, _, _, sellPrice, classID, subclassID, _, _, _,
		isCraftingReagent = C_Item.GetItemInfo(item)
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
		requiredLevel = requiredLevel,
		classID = classID,
		subclassID = subclassID,
	}
end

-- How many of an item the character has in bags, bank and reagent bank, or
-- with bagsOnly in the bags (with the reagent bag) only.
function Compat.GetItemCount(item, bagsOnly)
	if bagsOnly then
		return C_Item.GetItemCount(item, false, false, false, false)
	end
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

-- Game settings (console variables), as the game's own options read and
-- change them. GetCVar is nil for a name the client does not know; SetCVar
-- refuses in combat, where the client refuses such changes, and says whether
-- the value was taken.
function Compat.GetCVar(name)
	local ok, value = pcall(C_CVar.GetCVar, name)
	if ok and value ~= nil and not Compat.IsSecret(value) then
		return value
	end
	return nil
end

function Compat.SetCVar(name, value)
	if Compat.InCombat() then
		return false
	end
	local ok, done = pcall(C_CVar.SetCVar, name, tostring(value))
	return ok and done ~= false
end

-- A value the client keeps secret is left out (nil); so is a failing call.
local function plain(ok, value)
	if not ok or value == nil or Compat.IsSecret(value) then
		return nil
	end
	return value
end

local function try(fn, ...)
	return plain(pcall(fn, ...))
end

-- The object ID in a game object's GUID ("GameObject-0-1-2-3-<id>-…"), or nil.
local function objectID(guid)
	if type(guid) ~= "string" then
		return nil
	end
	return tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

-- The game's soft interact target: the one object or unit the Interact key
-- would use (the unit "softinteract").
local SOFT = "softinteract"
local cursorProbe

-- The facts about the soft interact target, or nil without one: isObject,
-- isDead, isLiving (a unit that is neither an object nor dead), objectID
-- (from its GUID), name, cursor (the file ID, path or atlas of the cursor the
-- game would show over it), inReach (nil without UnitIsInInteractRange),
-- questRelated (to an active quest), questObjective (a quest objective line
-- in its tooltip). Each value the client keeps secret is nil.
-- skipQuest: leave out the quest facts (questRelated, questObjective), the
-- costly part (the tooltip comes as a new table), for a caller that keeps
-- them from an earlier read of the same target.
function Compat.GetSoftInteract(skipQuest)
	-- A world object does not exist as far as UnitExists is concerned (as
	-- Lueur and Forever Loot Sparkles found); only a unit does.
	local isUnit, isObject = try(UnitExists, SOFT), try(UnitIsGameObject, SOFT)
	if isUnit ~= true and isObject ~= true then
		return nil
	end
	local facts = {
		isObject = isObject,
		isDead = try(UnitIsDead, SOFT),
		objectID = objectID(try(UnitGUID, SOFT)),
		name = try(UnitName, SOFT),
	}
	facts.isLiving = facts.isObject == false and facts.isDead == false
	-- The cursor goes onto a hidden texture, as the game's own nameplates do
	-- for this unit; low-priority cursors too, as Lueur found objects use them.
	cursorProbe = cursorProbe or UIParent:CreateTexture(nil, "BACKGROUND")
	cursorProbe:Hide()
	cursorProbe:SetTexture(nil)
	if try(SetUnitCursorTexture, cursorProbe, SOFT, nil, true) then
		facts.cursor = try(cursorProbe.GetTexture, cursorProbe) or try(cursorProbe.GetAtlas, cursorProbe)
	end
	if Compat.Has("UnitIsInInteractRange") then
		facts.inReach = try(UnitIsInInteractRange, SOFT)
	end
	if skipQuest then
		return facts
	end
	if Compat.Has("C_QuestLog.UnitIsRelatedToActiveQuest") then
		facts.questRelated = try(C_QuestLog.UnitIsRelatedToActiveQuest, SOFT)
	end
	if Compat.Has("C_TooltipInfo.GetUnit") then
		local data = try(C_TooltipInfo.GetUnit, SOFT)
		for _, line in ipairs(type(data) == "table" and data.lines or {}) do
			if line.type == Enum.TooltipDataLineType.QuestObjective then
				facts.questObjective = true
			end
		end
	end
	return facts
end

-- Puts the soft interact target's cursor on a texture, the icon the game
-- would show over it (low-priority cursors too); whether it has one.
function Compat.SetSoftInteractCursor(texture)
	return try(SetUnitCursorTexture, texture, SOFT, nil, true) == true
end

-- The soft interact target's name, for showing it, and whether it has one.
-- The name may be a value the client keeps secret: give it only to a font
-- string's SetText, which takes secrets; never compare or measure it.
function Compat.GetSoftInteractName()
	local ok, name = pcall(UnitName, SOFT)
	if not ok then
		return nil, false
	end
	if Compat.IsSecret(name) then
		return name, true
	end
	if type(name) == "string" and name ~= "" then
		return name, true
	end
	return nil, false
end

-- The objective types of something to collect or to use: the ones a game
-- object can be for.
local OBJECTIVE_TYPES = { item = true, object = true }

-- The texts of the unfinished objectives, of the quests in the log, that ask
-- to collect or use something ("Waterlogged Saw: 0/1"), in the client's
-- language: a game object for such a quest often has neither the quest flag
-- nor a quest line in its tooltip. A text the client keeps secret is left
-- out; without the quest log functions, none.
function Compat.GetQuestObjectiveTexts()
	local texts = {}
	if not (Compat.Has("C_QuestLog.GetNumQuestLogEntries") and Compat.Has("C_QuestLog.GetQuestIDForLogIndex")
		and Compat.Has("C_QuestLog.GetQuestObjectives")) then
		return texts
	end
	for index = 1, try(C_QuestLog.GetNumQuestLogEntries) or 0 do
		local questID = try(C_QuestLog.GetQuestIDForLogIndex, index)
		local objectives = type(questID) == "number" and questID > 0 and try(C_QuestLog.GetQuestObjectives, questID)
		for _, objective in ipairs(type(objectives) == "table" and objectives or {}) do
			local text, kind = plain(true, objective.text), plain(true, objective.type)
			if type(text) == "string" and plain(true, objective.finished) == false and (kind == nil or OBJECTIVE_TYPES[kind]) then
				texts[#texts + 1] = text
			end
		end
	end
	return texts
end

-- The client's name of an item class (Enum.ItemClass), such as "Trade Goods",
-- or nil.
function Compat.GetItemClassName(classID)
	return try(C_Item.GetItemClassInfo, classID)
end

-- Equips an item from the bags (a link or an ID), or swaps it in; the game
-- picks the slot, asks about binding, and refuses armour in a fight.
function Compat.EquipItem(item)
	try(C_Item.EquipItemByName, item)
end

-- Whether the chat-link modifier (Shift) is held now.
function Compat.IsChatLinkHeld()
	return IsModifiedClick("CHATLINK") == true
end

-- The game's modified click on an item, as its bags handle one (the chat link
-- with Shift, the dressing room with Ctrl); true when one was made. A client
-- without it still links with the chat-link modifier.
function Compat.ModifiedItemClick(link)
	if HandleModifiedItemClick then
		return HandleModifiedItemClick(link) == true
	end
	if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
		ChatFrameUtil.InsertLink(link)
		return true
	end
	return false
end

-- Whether an item can be equipped at all (by anyone), and whether this
-- character can use it now: nil where the client cannot say.
function Compat.IsEquippableItem(item)
	return try(C_Item.IsEquippableItem, item) == true
end

function Compat.CanUseItem(itemID)
	if not Compat.Has("C_PlayerInfo.CanUseItem") then
		return nil
	end
	return try(C_PlayerInfo.CanUseItem, itemID)
end

-- Whether the character has done a quest, or nil where the client cannot say.
function Compat.IsQuestDone(questID)
	if type(questID) ~= "number" or not Compat.Has("C_QuestLog.IsQuestFlaggedCompleted") then
		return nil
	end
	return try(C_QuestLog.IsQuestFlaggedCompleted, questID)
end

-- Whether a quest is in the character's log, or nil where the client cannot say.
function Compat.IsOnQuest(questID)
	if type(questID) ~= "number" or not Compat.Has("C_QuestLog.IsOnQuest") then
		return nil
	end
	return try(C_QuestLog.IsOnQuest, questID)
end

-- The character's level.
function Compat.GetPlayerLevel()
	return try(UnitLevel, "player") or 0
end

-- The item on the cursor (picked up from the bags or dragged), or nil.
function Compat.GetCursorItemID()
	local kind, itemID = GetCursorInfo()
	if kind == "item" and type(itemID) == "number" then
		return itemID
	end
	return nil
end

-- The texts of the objectives to collect or use of every quest in the log,
-- by quest, finished ones too: { [questID] = { "Waterlogged Saw: 1/1", … } }.
-- Read before a quest is turned in, they say which items it wanted. A text
-- the client keeps secret is left out; without the quest log functions, none.
function Compat.GetQuestItemObjectives()
	local quests = {}
	if not (Compat.Has("C_QuestLog.GetNumQuestLogEntries") and Compat.Has("C_QuestLog.GetQuestIDForLogIndex")
		and Compat.Has("C_QuestLog.GetQuestObjectives")) then
		return quests
	end
	for index = 1, try(C_QuestLog.GetNumQuestLogEntries) or 0 do
		local questID = try(C_QuestLog.GetQuestIDForLogIndex, index)
		if type(questID) == "number" and questID > 0 then
			local objectives = try(C_QuestLog.GetQuestObjectives, questID)
			local texts = {}
			for _, objective in ipairs(type(objectives) == "table" and objectives or {}) do
				local text, kind = plain(true, objective.text), plain(true, objective.type)
				if type(text) == "string" and (kind == nil or OBJECTIVE_TYPES[kind]) then
					texts[#texts + 1] = text
				end
			end
			if #texts > 0 then
				quests[questID] = texts
			end
		end
	end
	return quests
end

-- The file ID of one of the game's cursors (Interface\Cursor\<name>), or nil.
function Compat.GetCursorFileID(name)
	local path = "Interface\\Cursor\\" .. name
	return try(GetFileIDFromPath, path) or try(GetFileIDFromPath, path .. ".blp")
end

-- The nameplate of a unit, but not a forbidden one; nil without one.
function Compat.GetNamePlate(unit)
	return try(C_NamePlate.GetNamePlateForUnit, unit, false)
end

-- The soft interact target's nameplate: by its own unit, or else among the
-- nameplates shown now (their units, "nameplate1" …, as the game named them
-- when it added each), the one that is the soft target or a game object.
-- Lueur found the first way does not always give an object's plate.
function Compat.GetSoftInteractPlate(units)
	local plate = Compat.GetNamePlate(SOFT)
	if plate then
		return plate
	end
	local object
	for unit in pairs(units or {}) do
		if try(UnitIsUnit, unit, SOFT) == true then
			plate = Compat.GetNamePlate(unit)
			if plate then
				return plate
			end
		elseif not object and try(UnitIsGameObject, unit) == true then
			object = unit
		end
	end
	return object and Compat.GetNamePlate(object) or nil
end

-- The object IDs of the game objects the open loot window came from (a
-- chest, a herb), each once.
function Compat.GetLootSourceObjects()
	local ids, seen = {}, {}
	for slot = 1, GetNumLootItems() do
		local sources = { pcall(GetLootSourceInfo, slot) }
		if sources[1] then
			-- guid, quantity, guid, quantity, …
			for index = 2, #sources, 2 do
				local id = objectID(plain(true, sources[index]))
				if id and not seen[id] then
					seen[id] = true
					ids[#ids + 1] = id
				end
			end
		end
	end
	return ids
end

-- Whether the character has Herbalism, Mining and Skinning: { herbs, ore,
-- skinning }, each true, false, or nil when the client cannot say yet, read
-- as Lueur does on WoW Forever. Yes from any source is enough: a spell the
-- profession teaches (Find Herbs, Find Minerals, Skinning's ranks), the skill line with a rank, the
-- professions list. No only when a source that can answer says so; while the
-- client has not loaded the skill lines yet (just after logging in), it
-- cannot say. The professions list only ever says yes: on WoW Forever it may
-- leave the classic professions out.
local GATHERING = {
	herbs = { line = 182, spells = { 2383, 8387 } },
	ore = { line = 186, spells = { 2580, 8388 } },
	skinning = { line = 393, spells = { 8613, 8617, 8618, 10768 } },
}

local function professionLines()
	if not (Compat.Has("GetProfessions") and Compat.Has("GetProfessionInfo")) then
		return nil
	end
	local lines = {}
	local ok, first, second, third, fourth, fifth = pcall(GetProfessions)
	if not ok then
		return nil
	end
	for _, profession in pairs({ first, second, third, fourth, fifth }) do
		if type(profession) == "number" then
			local line = plain(pcall(function()
				return (select(7, GetProfessionInfo(profession)))
			end))
			if line then
				lines[line] = true
			end
		end
	end
	return lines
end

local function gatheringSkill(profession, known, lines)
	local answered = false
	if known then
		for _, spell in ipairs(profession.spells) do
			local has = try(known, spell)
			if has == true then
				return true
			end
			answered = answered or has == false
		end
	end
	if lines and lines[profession.line] then
		return true
	end
	if Compat.Has("C_SkillInfo.GetSkillLineInfoByID") then
		-- No skill lines yet: they are still loading, and nothing can say no.
		if (try(C_SkillInfo.GetNumSkillLines) or 0) == 0 then
			return nil
		end
		local info = try(C_SkillInfo.GetSkillLineInfoByID, profession.line)
		if type(info) == "table" and (type(info.maxRank) ~= "number" or info.maxRank > 0) then
			return true
		end
		answered = true
	end
	if answered then
		return false
	end
	return nil
end

function Compat.GetGatheringSkills()
	local known = Compat.Has("C_SpellBook.IsSpellKnown") and C_SpellBook.IsSpellKnown or nil
	local lines = professionLines()
	return { herbs = gatheringSkill(GATHERING.herbs, known, lines), ore = gatheringSkill(GATHERING.ore, known, lines),
		skinning = gatheringSkill(GATHERING.skinning, known, lines) }
end

-- The player's position in the world, two coordinates in yards as the client
-- gives them, or nil where it does not (secret, or missing in instances).
function Compat.GetPlayerPosition()
	local ok, first, second = pcall(UnitPosition, "player")
	if ok and type(first) == "number" and type(second) == "number" and not Compat.IsSecret(first) and not Compat.IsSecret(second) then
		return first, second
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

-- limit: the most bytes the decompressed data may have, or nil for no limit.
-- A short text can decompress into a great deal; the client's decompression
-- takes no limit of its own (API docs), so the length is checked before the
-- data is read.
function Compat.Decode(text, limit)
	if not Compat.CanEncode() or type(text) ~= "string" then
		return nil
	end
	local ok, value = pcall(function()
		local packed = C_EncodingUtil.DecodeBase64(text)
		local cbor = packed and C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
		if type(cbor) ~= "string" or (limit and #cbor > limit) then
			return nil
		end
		return C_EncodingUtil.DeserializeCBOR(cbor)
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

-- The stack where an error was raised, as Blizzard's script errors show it:
-- called from ReportError, which an xpcall calls as its handler, it starts at
-- the function that raised the error.
function Compat.GetStack()
	return debugstack(3)
end

-- fn(err, stack) hears every error ReportError reports, before the game does.
local errorListener

function Compat.SetErrorListener(fn)
	errorListener = fn
end

-- Reports an error to the game's error handler (BugSack) without stopping the
-- caller; the listener keeps it first, and an error of its own stops nothing.
function Compat.ReportError(err)
	if errorListener then
		pcall(errorListener, err, Compat.GetStack())
	end
	geterrorhandler()(err)
end
