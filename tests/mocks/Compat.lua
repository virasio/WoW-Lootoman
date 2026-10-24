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
	-- LootSlot, ConfirmLootSlot and CloseLoot calls, in order: { "loot", 2 }, { "close" }.
	lootActions = {},
	-- Bags by ID: { size, family, items = { [slot] = { itemID, count, link } } };
	-- a bag that is not listed is not equipped. Items the client has loaded, by
	-- ID: { name, link, quality, stackSize, family, isCraftingReagent }.
	-- Game error names by error type, filled by Test.FireGameError.
	gameErrors = {},
	playerBags = { 0, 1, 2, 3, 4 },
	reagentBag = 5,
	bags = {},
	items = {},
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

function Compat.CloseLoot()
	state.lootActions[#state.lootActions + 1] = { "close" }
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
	return copy(info and info.items and info.items[slot])
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
		isCraftingReagent = info.isCraftingReagent,
	}
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

-- SetItems({ [2589] = { name = "Linen Cloth", stackSize = 200, isCraftingReagent = true } }).
function Test.SetItems(items)
	state.items = items
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
