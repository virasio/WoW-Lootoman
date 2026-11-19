local _, ns = ...
local Bus, Compat, Text = ns.Bus, ns.Compat, ns.Text
local Feed = ns.Feed

-- The loot feed's debug commands, in English as all debug output:
--
--   /ltm debug loot 2589x5, |cff…|Hitem:…|h[Name]|h|r, currency[1220]+50,
--       exp+2000, rep["Stormwind"]+200, gold+0.0015
--
-- puts made-up gains into the feed through its own handler, so merging, the
-- junk row, the minimum quality and the delay between rows behave as for
-- real loot. An item the client has not loaded is asked for and comes when it
-- loads; one that does not load in LOAD_TIME seconds is named in the chat.
local LootFeed = ns.Modules:Get("LootFeed")
local Debug = {}
Feed.Debug = Debug

Debug.LOAD_TIME = 5

local SYNTAX = {
	"/ltm debug loot takes pieces split by commas:",
	"  2589 or an item's link: one of the item; 2589x5: five",
	"  currency[1220]+50: a currency",
	"  exp+2000: experience",
	"  rep[\"Stormwind\"]+200 or -200: reputation, the faction named as the chat names it",
	"  gold+0.0015: money in gold, here 15 copper",
}

-- The pieces of a line, split by commas; links, whose names may hold commas,
-- are taken out first and put back.
function Debug.Pieces(text)
	local links = {}
	local function hold(link)
		links[#links + 1] = link
		return "\1" .. #links .. "\1"
	end
	text = text:gsub("|c[^|]*|H.-|h%[.-%]|h|r", hold):gsub("|H.-|h%[.-%]|h", hold)
	local pieces = {}
	for piece in (text .. ","):gmatch("%s*(.-)%s*,") do
		if piece ~= "" then
			pieces[#pieces + 1] = (piece:gsub("\1(%d+)\1", function(index)
				return links[tonumber(index)]
			end))
		end
	end
	return pieces
end

-- A piece as an entry of the feed's shape, or { itemID, count } for an item
-- to load first, or nil and why it cannot be read.
function Debug.Read(piece)
	local word = Text.FoldCase(piece)
	local link, rest = piece:match("^(|c[^|]*|H.-|h%[.-%]|h|r)%s*(.*)$")
	if not link then
		link, rest = piece:match("^(|H.-|h%[.-%]|h)%s*(.*)$")
	end
	if link then
		local count = rest == "" and 1 or tonumber(Text.FoldCase(rest):match("^x(%d+)$"))
		if count and count > 0 and link:match("item:%d+") then
			return Feed.Sources.ItemEntry(link, count)
		end
		return nil, "not an item's link with an optional count"
	end
	local itemID, times = word:match("^(%d+)$"), "1"
	if not itemID then
		itemID, times = word:match("^(%d+)%s*x(%d+)$")
	end
	if itemID then
		local id, count = tonumber(itemID), tonumber(times) or 0
		if count < 1 then
			return nil, "a count of at least 1"
		end
		local info = Compat.GetItemInfo(id)
		if info and info.link then
			return Feed.Sources.ItemEntry(info.link, count)
		end
		return { itemID = id, count = count }
	end
	local currencyID, amount = word:match("^currency%[(%d+)%]%s*%+%s*(%d+)$")
	if currencyID then
		local info = Compat.GetCurrencyInfo(tonumber(currencyID))
		if not info then
			return nil, "no currency " .. currencyID
		end
		return {
			kind = "currency",
			id = tonumber(currencyID),
			name = info.name,
			icon = info.icon,
			quality = info.quality,
			amount = tonumber(amount),
			total = (info.quantity or 0) + tonumber(amount),
		}
	end
	amount = word:match("^exp%s*%+%s*(%d+)$")
	if amount then
		return { kind = "xp", amount = tonumber(amount) }
	end
	local name, sign, change = piece:match("^[Rr][Ee][Pp]%[%s*[\"']?(.-)[\"']?%s*%]%s*([%+%-])%s*(%d+)$")
	if name and name ~= "" then
		return { kind = "reputation", name = name, declined = false, amount = tonumber(change) * (sign == "-" and -1 or 1) }
	end
	local gold = word:match("^gold%s*%+%s*(%d*%.?%d+)$")
	if gold then
		local copper = math.floor(tonumber(gold) * 10000 + 0.5)
		if copper < 1 then
			return nil, "less than a copper"
		end
		return { kind = "money", amount = copper }
	end
	return nil, "not a piece the command knows"
end

-- Items asked for: { [itemID] = { counts } }, while any wait.
local loading = {}

local function loaded(_, itemID, success)
	local counts = loading[itemID]
	if not counts then
		return
	end
	loading[itemID] = nil
	if next(loading) == nil then
		Bus:OffEvent("ITEM_DATA_LOAD_RESULT", Debug)
	end
	local info = success and Compat.GetItemInfo(itemID)
	if not (info and info.link) then
		ns.Print(("debug loot: item %d does not exist."):format(itemID))
		return
	end
	if LootFeed:IsActive() then
		for _, count in ipairs(counts) do
			LootFeed:Take(Feed.Sources.ItemEntry(info.link, count))
		end
	end
end

local function load(itemID, count)
	if next(loading) == nil then
		Bus:OnEvent("ITEM_DATA_LOAD_RESULT", Debug, loaded)
	end
	local counts = loading[itemID]
	loading[itemID] = counts or {}
	table.insert(loading[itemID], count)
	if counts then
		return
	end
	Compat.RequestItem(itemID)
	Compat.After(Debug.LOAD_TIME, function()
		if loading[itemID] then
			loading[itemID] = nil
			if next(loading) == nil then
				Bus:OffEvent("ITEM_DATA_LOAD_RESULT", Debug)
			end
			ns.Print(("debug loot: item %d did not load in %d seconds."):format(itemID, Debug.LOAD_TIME))
		end
	end)
end

ns.Slash.RegisterDebug("loot", function(argument)
	local pieces = Debug.Pieces(argument)
	if #pieces == 0 then
		for _, line in ipairs(SYNTAX) do
			ns.Print(line)
		end
		return
	end
	if not LootFeed:IsActive() then
		ns.Print("debug loot: the loot feed is off.")
		return
	end
	for _, piece in ipairs(pieces) do
		local entry, problem = Debug.Read(piece)
		if not entry then
			ns.Print(("debug loot: cannot read “%s”: %s."):format(piece, problem))
		elseif entry.itemID then
			load(entry.itemID, entry.count)
		else
			LootFeed:Take(entry)
		end
	end
end, "/ltm debug loot <pieces>: made-up loot in the feed (alone: the pieces it takes)")

-- The bug report: the profile's look and what in it differs from the defaults.
ns.BugReport.AddPart(function()
	local name = Feed.Looks.Current()
	local look = Feed.Looks.Get(name) or {}
	local lines = { ("Loot feed look “%s”: base %s, view %s"):format(name, tostring(look.base), Feed.Looks.View(name)) }
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
