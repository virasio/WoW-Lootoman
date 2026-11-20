local _, ns = ...
local Feed = ns.Feed

-- The loot feed's debug command, /ltm debug bags, in English as all debug
-- output, and its part of the bug report. Made-up loot in the feed is in the
-- repository's version only.
local LootFeed = ns.Modules:Get("LootFeed")

-- The bug report: the profile's look and what in it differs from the defaults.
ns.BugReport.AddPart(function()
	local name = Feed.Looks.Current()
	local look = Feed.Looks.Get(name) or {}
	local lines = { ('Loot feed look "%s": base %s, view %s'):format(name, tostring(look.base), Feed.Looks.View(name)) }
	local function add(prefix, values)
		local keys = {}
		for key in pairs(values or {}) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local value = values[key]
			if type(value) == "table" then
				add(prefix .. key .. ".", value)
			else
				lines[#lines + 1] = ("%s%s = %s"):format(prefix, key, tostring(value))
			end
		end
	end
	add("look.", look.values)
	add("look.design.", look.changes)
	return lines
end)

local function kindOf(bag)
	return bag.reagent and "reagent" or (bag.family ~= 0 and "profession" or "general")
end

ns.Slash.RegisterDebug("bags", function()
	for _, bag in ipairs(ns.Inventory.Bags()) do
		ns.Print(("debug bags: bag %d, %s, family %d: %d of %d free"):format(bag.bag, kindOf(bag), bag.family or 0,
			bag.free, bag.size))
	end
	local slots = ns.Bags.FreeSlots()
	ns.Print(("  All: %d of %d free (%d used); general %d of %d; reagent %d of %d; profession %d of %d"):format(slots.free,
		slots.total, slots.used, slots.general, slots.generalTotal, slots.reagent, slots.reagentTotal, slots.profession,
		slots.professionTotal))
	local thresholds = {}
	for _, check in ipairs({
		{ "all bags", "warnTotal", "warnTotalAt", slots.free, slots.total },
		{ "general", "warnGeneral", "warnGeneralAt", slots.general, slots.generalTotal },
		{ "reagent", "warnReagent", "warnReagentAt", slots.reagent, slots.reagentTotal },
	}) do
		local on, at = LootFeed:Get(check[2]), LootFeed:Get(check[3])
		thresholds[#thresholds + 1] = ("%s %s at %d%s"):format(check[1], on and "on" or "off", at,
			on and check[5] > 0 and check[4] <= at and ", reached" or "")
	end
	ns.Print(("  Look “%s”: %s"):format(Feed.Looks.Current(), table.concat(thresholds, "; ")))
	ns.Print("  Warning text: " .. Feed.SlotsText.Render(LootFeed:Get("slotsText"), slots, "ffffffff"))
end, "/ltm debug bags: the bags as the low-space warning counts them, and the look's thresholds")
