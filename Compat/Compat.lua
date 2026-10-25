local _, ns = ...

-- The only code that reads the game's data and state (techspec §3). Tests
-- replace this file with tests/mocks/Compat.lua, which has the same functions.
local Compat = {}
ns.Compat = Compat

-- Capability detection (techspec §2): Has("C_Container.GetContainerItemInfo")
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

function Compat.CloseLoot()
	CloseLoot()
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

-- The item in a bag slot as { itemID, count, link }, or nil for an empty slot.
function Compat.GetBagItem(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then
		return nil
	end
	return { itemID = info.itemID, count = info.stackCount, link = info.hyperlink }
end

-- The bag families an item fits (a bit field), 0 for general bags only.
function Compat.GetItemFamily(item)
	return C_Item.GetItemFamily(item) or 0
end

-- Item data by ID, link or name: name, link, quality, stackSize,
-- isCraftingReagent. Nil while the client has not loaded the item yet.
function Compat.GetItemInfo(item)
	local name, link, quality, _, _, _, _, stackSize, _, _, _, _, _, _, _, _, isCraftingReagent = C_Item.GetItemInfo(item)
	if not name then
		return nil
	end
	return { name = name, link = link, quality = quality, stackSize = stackSize, isCraftingReagent = isCraftingReagent }
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

-- A currency as { name, icon, quality, quantity, discovered }, or nil.
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
	}
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
