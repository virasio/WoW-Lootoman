local _, ns = ...
local Bus, Compat, Text = ns.Bus, ns.Compat, ns.Text
local Feed = ns.Feed

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
--
--   /ltm demo loot 2589x5, |cff…|Hitem:…|h[Name]|h|r, currency[1220]+50,
--       exp+2000, rep["Stormwind"]+200, gold+0.0015
--
-- puts made-up gains into the feed through its own handler, so merging, the
-- junk row, the minimum quality and the delay between rows behave as for
-- real loot. An item the client has not loaded is asked for and comes when it
-- loads; one that does not load in LOAD_TIME seconds is named in the chat.
-- Development text is not translated.
local LootFeed = ns.Modules:Get("LootFeed")
local Demo = {}
Feed.Demo = Demo

Demo.LOAD_TIME = 5

local SYNTAX = {
	"/ltm demo loot takes pieces split by commas:",
	"  2589 or an item's link: one of the item; 2589x5: five",
	"  currency[1220]+50: a currency",
	"  exp+2000: experience",
	"  rep[\"Stormwind\"]+200 or -200: reputation, the faction named as the chat names it",
	"  gold+0.0015: money in gold, here 15 copper",
}

-- The pieces of a line, split by commas; links, whose names may hold commas,
-- are taken out first and put back.
function Demo.Pieces(text)
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
function Demo.Read(piece)
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
		Bus:OffEvent("ITEM_DATA_LOAD_RESULT", Demo)
	end
	local info = success and Compat.GetItemInfo(itemID)
	if not (info and info.link) then
		ns.Print(("demo loot: item %d does not exist."):format(itemID))
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
		Bus:OnEvent("ITEM_DATA_LOAD_RESULT", Demo, loaded)
	end
	local counts = loading[itemID]
	loading[itemID] = counts or {}
	table.insert(loading[itemID], count)
	if counts then
		return
	end
	Compat.RequestItem(itemID)
	Compat.After(Demo.LOAD_TIME, function()
		if loading[itemID] then
			loading[itemID] = nil
			if next(loading) == nil then
				Bus:OffEvent("ITEM_DATA_LOAD_RESULT", Demo)
			end
			ns.Print(("demo loot: item %d did not load in %d seconds."):format(itemID, Demo.LOAD_TIME))
		end
	end)
end

ns.Slash.RegisterDemo("loot", function(argument)
	local pieces = Demo.Pieces(argument)
	if #pieces == 0 then
		for _, line in ipairs(SYNTAX) do
			ns.Print(line)
		end
		return
	end
	if not LootFeed:IsActive() then
		ns.Print("demo loot: the loot feed is off.")
		return
	end
	for _, piece in ipairs(pieces) do
		local entry, problem = Demo.Read(piece)
		if not entry then
			ns.Print(("demo loot: cannot read “%s”: %s."):format(piece, problem))
		elseif entry.itemID then
			load(entry.itemID, entry.count)
		else
			LootFeed:Take(entry)
		end
	end
end, "/ltm demo loot <pieces>: made-up loot in the feed (alone: the pieces it takes)")
