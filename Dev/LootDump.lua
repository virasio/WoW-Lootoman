local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- Exists only when the addon runs from the repository: the packager removes
-- the #@debug@ block from the TOC. After /lootoman debug on, it prints the loot
-- window and the loot events with their times, and shows values the client
-- keeps secret as <secret>, to check the loot functions in combat (plans/0.1.md,
-- risks). Development text is not translated.

local EVENTS = { "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_BIND_CONFIRM", "LOOT_CLOSED" }
local FIELDS = { "kind", "name", "quantity", "quality", "currencyID", "locked", "isQuestItem", "link" }

-- A secret value must not be turned into text.
local function show(value)
	if Compat.IsSecret(value) then
		return "<secret>"
	end
	return tostring(value)
end

local function showAll(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = show((select(index, ...)))
	end
	return table.concat(parts, ", ")
end

local function dumpSlots()
	local count = Compat.GetNumLootItems()
	ns.Debug(("Loot window: %s slots; in combat %s, fishing %s, auto loot %s"):format(show(count),
		show(Compat.InCombat()), show(Compat.IsFishingLoot()), show(Compat.IsAutoLootOn())))
	if Compat.IsSecret(count) then
		return
	end
	for slot = 1, count do
		local info = Compat.GetLootSlot(slot)
		if info then
			local parts = {}
			for _, field in ipairs(FIELDS) do
				parts[#parts + 1] = field .. "=" .. show(info[field])
			end
			ns.Debug(("  slot %d: %s"):format(slot, table.concat(parts, " ")))
		else
			ns.Debug(("  slot %d: empty"):format(slot))
		end
	end
end

for _, event in ipairs(EVENTS) do
	Bus:OnEvent(event, "LootDump", function(name, ...)
		ns.Debug(("%.2f %s(%s)"):format(Compat.GetTime(), name, showAll(...)))
		if name == "LOOT_READY" then
			dumpSlots()
		end
	end)
end
