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
