local _, ns = ...

-- Stand-in for Compat/Compat.lua in tests: the same functions, backed by a fake
-- client in Compat.Test.state. Compat.Test drives it: fire events, enter
-- combat, move time.
local Compat = {}
ns.Compat = Compat

local state = {
	capabilities = {},
	events = {},
	character = "Tester-Realm",
	combat = false,
	addons = { Lootoman = true },
	metadata = { Lootoman = { Title = "Lootoman", Version = "@project-version@" } },
	time = 0,
	timers = {},
	build = { "12.1.5", "70575", "Oct 23 2026", 120105 },
	saved = {},
	slashCommands = {},
	printed = {},
	errors = {},
	-- Auto loot is on in the fake client; no modifier keys are held.
	cvars = { autoLootDefault = true },
	modifiers = {},
	group = false,
	-- The loot window: count stays the same while looted slots become false.
	loot = { slots = {}, count = 0, fishing = false },
	-- LootSlot and ConfirmLootSlot calls, in order: { "loot", 2 }, { "confirm", 2 }.
	lootActions = {},
	-- Bags by ID: { size, family, items = { [slot] = { itemID, count, link, name,
	-- quality, icon, bound, noValue, locked } } };
	-- a bag that is not listed is not equipped. Items the client has loaded, by
	-- ID: { name, link, quality, stackSize, sellPrice, family, isCraftingReagent, owned }.
	-- Feed sources: global strings (chat formats), money in copper, experience
	-- and its level maximum, currencies by ID ({ name, icon, quality, quantity, discovered }).
	globalStrings = {},
	money = 0,
	xp = { 0, 1000 },
	currencies = {},
	-- Windows open with an NPC or a player, by kind: { Merchant = true }.
	interacting = {},
	-- Game error names by error type, filled by Test.FireGameError.
	gameErrors = {},
	playerBags = { 0, 1, 2, 3, 4 },
	reagentBag = 5,
	bags = {},
	items = {},
	-- Profile texts: the client has an encoder unless this is false; the
	-- tables encoded so far, a text "ENC<n>" for the n-th.
	encoder = true,
	encoded = {},
	-- The cursor: nil, or { bag, slot } of the item it holds.
	cursor = nil,
	-- Bag item uses, pick ups, deletes and cursor clears, in order.
	bagActions = {},
}

function Compat.Has(path)
	return state.capabilities[path] == true
end

function Compat.RegisterEvent(event, handler)
	state.events[event] = handler
end

function Compat.UnregisterEvent(event)
	state.events[event] = nil
end

function Compat.GetCharacterKey()
	return state.character
end

function Compat.InCombat()
	return state.combat
end

function Compat.IsSecret(value)
	return type(value) == "table" and value.secret == true
end

function Compat.IsAddOnLoaded(name)
	return state.addons[name] == true
end

function Compat.GetAddOnMetadata(name, field)
	local fields = state.metadata[name]
	return fields and fields[field]
end

function Compat.After(seconds, callback)
	state.timers[#state.timers + 1] = { at = state.time + seconds, callback = callback }
end

function Compat.GetTime()
	return state.time
end

function Compat.GetBuildInfo()
	return unpack(state.build)
end

function Compat.GetNumLootItems()
	return state.loot.count
end

function Compat.GetLootSlot(slot)
	local info = state.loot.slots[slot]
	if not info then
		return nil
	end
	local copy = {}
	for key, value in pairs(info) do
		copy[key] = value
	end
	return copy
end

function Compat.LootSlot(slot)
	state.lootActions[#state.lootActions + 1] = { "loot", slot }
end

function Compat.ConfirmLootSlot(slot)
	state.lootActions[#state.lootActions + 1] = { "confirm", slot }
end

function Compat.IsFishingLoot()
	return state.loot.fishing
end

function Compat.IsAutoLootOn()
	return (state.cvars.autoLootDefault == true) ~= (state.modifiers.AUTOLOOTTOGGLE == true)
end

function Compat.IsInGroup()
	return state.group
end

function Compat.IsInteracting(kind)
	return state.interacting[kind] == true
end

function Compat.GetGameErrorName(errorType)
	return state.gameErrors[errorType]
end

local function copy(source)
	if not source then
		return nil
	end
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

-- Items are found by ID or by the ID inside a link.
local function findItem(item)
	local id = type(item) == "string" and tonumber(item:match("item:(%d+)")) or item
	return state.items[id]
end

function Compat.GetPlayerBags()
	return copy(state.playerBags), state.reagentBag
end

function Compat.GetBagFreeSlots(bag)
	local info = state.bags[bag]
	if not info then
		return 0, 0
	end
	local used = 0
	for _ in pairs(info.items or {}) do
		used = used + 1
	end
	return info.size - used, info.family or 0
end

function Compat.GetBagSize(bag)
	local info = state.bags[bag]
	return info and info.size or 0
end

function Compat.GetBagItem(bag, slot)
	local info = state.bags[bag]
	local item = copy(info and info.items and info.items[slot])
	if item then
		item.bound, item.noValue, item.locked = item.bound == true, item.noValue == true, item.locked == true
	end
	return item
end

-- Bags: { protections = { [slot] = { quest = true } } }; an item's guid is
-- its own guid field, or "<bag>:<slot>:<itemID>".
function Compat.GetBagItemFacts(bag, slot)
	local info = state.bags[bag]
	local item = info and info.items and info.items[slot]
	local facts = copy(info and info.protections and info.protections[slot]) or {}
	return {
		quest = facts.quest == true,
		equipmentSet = facts.equipmentSet == true,
		refundable = facts.refundable == true,
		guid = item and (item.guid or ("%d:%d:%d"):format(bag, slot, item.itemID)) or nil,
	}
end

-- Bags: { keptFromJunkSale = true }.
function Compat.IsBagKeptFromJunkSale(bag)
	local info = state.bags[bag]
	return info ~= nil and info.keptFromJunkSale == true
end

-- Each use is recorded as { "use", bag, slot } in state.bagActions; at an open
-- merchant the item is sold (it locks, as the server answers later: Test.FinishSale),
-- elsewhere it stays.
function Compat.UseBagItem(bag, slot)
	state.bagActions[#state.bagActions + 1] = { "use", bag, slot, merchant = state.interacting.Merchant == true }
	local item = state.bags[bag] and state.bags[bag].items and state.bags[bag].items[slot]
	if item and state.interacting.Merchant then
		item.locked = true
	end
end

function Compat.IsCursorEmpty()
	return state.cursor == nil
end

-- The cursor holds { bag, slot } after a pick up; picking up with an item on
-- the cursor swaps them, as in the client.
function Compat.PickupBagItem(bag, slot)
	state.bagActions[#state.bagActions + 1] = { "pickup", bag, slot }
	local item = state.bags[bag] and state.bags[bag].items and state.bags[bag].items[slot]
	if state.cursor then
		state.cursor = item and { bag = bag, slot = slot, swapped = true } or nil
	elseif item and not item.locked then
		state.cursor = { bag = bag, slot = slot }
	end
end

function Compat.GetCursorBagSlot()
	if state.cursor and not state.cursor.swapped then
		return state.cursor.bag, state.cursor.slot
	end
	return nil
end

function Compat.ClearCursor()
	state.bagActions[#state.bagActions + 1] = { "clear" }
	state.cursor = nil
end

-- Removes the item the cursor holds from its slot.
function Compat.DeleteCursorItem()
	state.bagActions[#state.bagActions + 1] = { "delete" }
	local cursor = state.cursor
	if cursor and state.bags[cursor.bag] and state.bags[cursor.bag].items then
		state.bags[cursor.bag].items[cursor.slot] = nil
	end
	state.cursor = nil
end

function Compat.GetItemFamily(item)
	local info = findItem(item)
	return info and info.family or 0
end

function Compat.GetItemInfo(item)
	local info = findItem(item)
	if not info then
		return nil
	end
	return {
		name = info.name,
		link = info.link,
		quality = info.quality,
		stackSize = info.stackSize,
		sellPrice = info.sellPrice,
		isCraftingReagent = info.isCraftingReagent,
	}
end

function Compat.GetItemCount(item)
	local info = findItem(item)
	return info and info.owned or 0
end

function Compat.GetItemLook(item)
	local info = findItem(item)
	if not info then
		return nil, nil
	end
	return info.icon, info.quality
end

function Compat.GetCurrencyInfo(currencyID)
	return copy(state.currencies[currencyID])
end

function Compat.GetMoney()
	return state.money
end

function Compat.GetXP()
	return state.xp[1], state.xp[2]
end

function Compat.GetGlobalString(name)
	return state.globalStrings[name]
end

function Compat.CanEncode()
	return state.encoder ~= false
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[deepCopy(key)] = deepCopy(item)
	end
	return result
end

-- Copies, so a text read back is not the table that was encoded.
function Compat.Encode(value)
	if state.encoder == false then
		return nil
	end
	state.encoded[#state.encoded + 1] = deepCopy(value)
	return "ENC" .. #state.encoded
end

function Compat.Decode(text)
	local index = state.encoder ~= false and type(text) == "string" and tonumber(text:match("^ENC(%d+)$"))
	return index and state.encoded[index] and deepCopy(state.encoded[index]) or nil
end

function Compat.GetSaved(name)
	return state.saved[name]
end

function Compat.SetSaved(name, value)
	state.saved[name] = value
end

function Compat.RegisterSlashCommand(id, commands, handler)
	state.slashCommands[id] = { commands = commands, handler = handler }
end

function Compat.Print(text)
	state.printed[#state.printed + 1] = text
end

function Compat.ReportError(err)
	state.errors[#state.errors + 1] = err
end

local Test = { state = state }
Compat.Test = Test

function Test.FireEvent(event, ...)
	local handler = state.events[event]
	if handler then
		handler(event, ...)
	end
end

function Test.IsRegistered(event)
	return state.events[event] ~= nil
end

-- Fires PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED like the game does.
function Test.SetCombat(inCombat)
	state.combat = inCombat
	Test.FireEvent(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

-- Runs the timers that are due after the given number of seconds.
function Test.Advance(seconds)
	state.time = state.time + seconds
	local due, waiting = {}, {}
	for _, timer in ipairs(state.timers) do
		if timer.at <= state.time then
			due[#due + 1] = timer
		else
			waiting[#waiting + 1] = timer
		end
	end
	state.timers = waiting
	for _, timer in ipairs(due) do
		timer.callback()
	end
end

-- Fills the loot window, e.g. SetLoot({ { kind = "item", name = "Linen Cloth",
-- quantity = 2, quality = 1, link = "…" }, { kind = "money", quantity = 150 } }).
-- Fire LOOT_READY / LOOT_OPENED afterwards, as the game does.
function Test.SetLoot(slots, fishing)
	state.loot = { slots = {}, count = #slots, fishing = fishing == true }
	for index, slot in ipairs(slots) do
		state.loot.slots[index] = slot
	end
end

-- Empties a slot and fires LOOT_SLOT_CLEARED, as the server does after LootSlot.
function Test.ClearLootSlot(slot)
	state.loot.slots[slot] = false
	Test.FireEvent("LOOT_SLOT_CLEARED", slot)
end

-- SetBags({ [0] = { size = 16, items = { [1] = { itemID = 2589, count = 5 } } },
-- [1] = { size = 20, family = 32 }, [5] = { size = 36 } }). Fire
-- BAG_UPDATE_DELAYED afterwards when the bags change while the addon runs.
function Test.SetBags(bags)
	state.bags = bags
end

-- What the server does after a sale (UseBagItem at a merchant): the slot
-- empties, the money arrives and the bags update.
function Test.FinishSale(bag, slot)
	local items = state.bags[bag].items
	local item = items[slot]
	items[slot] = nil
	local info = item and findItem(item.itemID)
	state.money = state.money + (info and info.sellPrice or 0) * (item and item.count or 0)
	Test.FireEvent("PLAYER_MONEY")
	Test.FireEvent("BAG_UPDATE_DELAYED")
end

-- Opens or closes a window with an NPC, firing the events the client fires:
-- SetInteracting("Merchant", true) fires MERCHANT_SHOW.
local INTERACTION_EVENTS = { Merchant = { "MERCHANT_SHOW", "MERCHANT_CLOSED" } }

function Test.SetInteracting(kind, open)
	state.interacting[kind] = open or nil
	local events = INTERACTION_EVENTS[kind]
	if events then
		Test.FireEvent(open and events[1] or events[2])
	end
end

-- SetItems({ [2589] = { name = "Linen Cloth", stackSize = 200, isCraftingReagent = true } }).
function Test.SetItems(items)
	state.items = items
end

-- The client's global strings, e.g. the chat formats of one locale.
function Test.SetGlobalStrings(strings)
	state.globalStrings = strings
end

-- Sets the money and fires PLAYER_MONEY.
function Test.SetMoney(copper)
	state.money = copper
	Test.FireEvent("PLAYER_MONEY")
end

-- Sets the experience and fires PLAYER_XP_UPDATE.
function Test.SetXP(xp, max)
	state.xp = { xp, max or state.xp[2] }
	Test.FireEvent("PLAYER_XP_UPDATE", "player")
end

-- SetCurrency(3008, { name = "Valorstones", quantity = 10, discovered = true }).
function Test.SetCurrency(currencyID, info)
	state.currencies[currencyID] = info
end

-- Changes a currency's quantity and fires CURRENCY_DISPLAY_UPDATE like the client.
function Test.ChangeCurrency(currencyID, change)
	local info = state.currencies[currencyID]
	info.quantity = info.quantity + change
	Test.FireEvent("CURRENCY_DISPLAY_UPDATE", currencyID, info.quantity, change)
end

-- Fires UI_ERROR_MESSAGE for a game error by name, e.g. FireGameError("ERR_INV_FULL").
function Test.FireGameError(name)
	local errorType = #state.gameErrors + 1
	state.gameErrors[errorType] = name
	Test.FireEvent("UI_ERROR_MESSAGE", errorType, name)
end

-- SetCVar("autoLootDefault", false); SetModifier("AUTOLOOTTOGGLE", true).
function Test.SetCVar(name, value)
	state.cvars[name] = value
end

function Test.SetModifier(action, held)
	state.modifiers[action] = held
end

function Test.SetGroup(inGroup)
	state.group = inGroup
end

-- Runs a slash command as if the player typed "/<command> <message>".
function Test.RunSlashCommand(id, message)
	state.slashCommands[id].handler(message or "")
end
