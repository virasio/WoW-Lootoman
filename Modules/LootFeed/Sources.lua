local _, ns = ...
local Bus, Compat = ns.Bus, ns.Compat

-- What the loot feed shows, from game events (techspec §7.3). Each entry is
-- { kind, id, link, name, icon, quality, amount, total }, where kind is "item",
-- "currency", "money", "reputation", "xp" or "skipped":
--
--   item        CHAT_MSG_LOOT in the player's own formats: looted, received,
--               created, bonus roll; amount is the stack size
--   currency    CURRENCY_DISPLAY_UPDATE with a gain, for discovered currencies;
--               total is the new quantity
--   money       PLAYER_MONEY: the gain in copper, except while a merchant, mail,
--               trade, auction house, bank or guild bank window is open
--   reputation  CHAT_MSG_COMBAT_FACTION_CHANGE: name is the faction as the
--               message writes it, declined is true when the client declined
--               it (Russian); amount is negative for a loss, nil when the
--               message has no number
--   xp          PLAYER_XP_UPDATE: the gain, also across a level-up
--   skipped     LootSkipped from fast autoloot: an item that did not fit
--
-- Chat formats come from the client's own strings, so every locale works.
-- None of these chat events is secret during chat messaging lockdown.
ns.Feed = ns.Feed or {}
local Sources = {}
ns.Feed.Sources = Sources

-- The player's own loot, multiple-item formats first: "You receive loot: %s"
-- would also match "You receive loot: [Linen Cloth]x2".
local ITEM_FORMATS = {
	"LOOT_ITEM_SELF_MULTIPLE",
	"LOOT_ITEM_PUSHED_SELF_MULTIPLE",
	"LOOT_ITEM_CREATED_SELF_MULTIPLE",
	"LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
	"LOOT_ITEM_SELF",
	"LOOT_ITEM_PUSHED_SELF",
	"LOOT_ITEM_CREATED_SELF",
	"LOOT_ITEM_BONUS_ROLL_SELF",
}

-- Reputation formats with the sign of the change; arguments are the faction
-- name, then the amount when there is one.
local REPUTATION_FORMATS = {
	{ "FACTION_STANDING_INCREASED", 1 },
	{ "FACTION_STANDING_INCREASED_BONUS", 1 },
	{ "FACTION_STANDING_INCREASED_DOUBLE_BONUS", 1 },
	{ "FACTION_STANDING_INCREASED_ACH_BONUS", 1 },
	{ "FACTION_STANDING_INCREASED_ACCOUNT_WIDE", 1 },
	{ "FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE", 1 },
	{ "FACTION_STANDING_INCREASED_GENERIC", 1 },
	{ "FACTION_STANDING_INCREASED_GENERIC_ACCOUNT_WIDE", 1 },
	{ "FACTION_STANDING_DECREASED", -1 },
	{ "FACTION_STANDING_DECREASED_ACCOUNT_WIDE", -1 },
	{ "FACTION_STANDING_DECREASED_GENERIC", -1 },
	{ "FACTION_STANDING_DECREASED_GENERIC_ACCOUNT_WIDE", -1 },
}

-- While one of these windows is open, money changes are trades, not loot.
local MONEY_WINDOWS = {
	MERCHANT_SHOW = "MERCHANT_CLOSED",
	MAIL_SHOW = "MAIL_CLOSED",
	TRADE_SHOW = "TRADE_CLOSED",
	AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED",
	BANKFRAME_OPENED = "BANKFRAME_CLOSED",
	GUILDBANKFRAME_OPENED = "GUILDBANKFRAME_CLOSED",
}

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

-- A chat format as an anchored Lua pattern, the argument number of each
-- capture, and the set of arguments the client declines:
-- "You receive loot: %sx%d" → "^You receive loot: (.+)x(%-?%d+)$", { 1, 2 }, {}.
-- Handles positional arguments (%2$s) and the Russian declension marker
-- around an argument (|3-7(%s): the client writes the declined word).
function Sources.ToPattern(format)
	local parts, order, declined = { "^" }, {}, {}
	local position, sequence = 1, 0
	local inMarker = false
	while position <= #format do
		local char = format:sub(position, position)
		local _, markerEnd = format:find("^|3%-%d+%(%%", position)
		if markerEnd then
			inMarker = true
			position = markerEnd
		elseif inMarker and char == ")" then
			inMarker = false
			position = position + 1
		elseif char ~= "%" then
			parts[#parts + 1] = (char:gsub(MAGIC, "%%%0"))
			position = position + 1
		elseif format:sub(position + 1, position + 1) == "%" then
			parts[#parts + 1] = "%%"
			position = position + 2
		else
			local rest = format:sub(position + 1)
			local index, spec = rest:match("^(%d+)%$([-+ #0]*%d*%.?%d*[sdf])")
			local length
			if index then
				index, length = assert(tonumber(index)), #index + 1 + #spec
			else
				spec = assert(rest:match("^([-+ #0]*%d*%.?%d*[sdf])"), "unsupported format: " .. format)
				sequence = sequence + 1
				index, length = sequence, #spec
			end
			local conversion = spec:sub(-1)
			parts[#parts + 1] = conversion == "s" and "(.+)" or conversion == "d" and "(%-?%d+)" or "(%-?[%d%.,]+)"
			order[#order + 1] = index
			declined[index] = inMarker or nil
			position = position + 1 + length
		end
	end
	parts[#parts + 1] = "$"
	return table.concat(parts), order, declined
end

-- The arguments of a chat message in the format's order, or nil.
local function match(compiled, text)
	local captures = { text:match(compiled.pattern) }
	if captures[1] == nil then
		return nil
	end
	local args = {}
	for capture, index in ipairs(compiled.order) do
		args[index] = captures[capture]
	end
	return args
end

local missing = {}

-- Formats the client did not have, for the self-test.
function Sources.MissingFormats()
	return missing
end

local function compile(names)
	local list = {}
	for _, name in ipairs(names) do
		local format = Compat.GetGlobalString(name)
		if format then
			local pattern, order, declined = Sources.ToPattern(format)
			list[#list + 1] = { name = name, pattern = pattern, order = order, declined = declined }
		else
			missing[#missing + 1] = name
		end
	end
	return list
end

-- A value the client keeps secret cannot be used; nil instead.
local function known(value)
	if Compat.IsSecret(value) then
		return nil
	end
	return value
end

local function itemEntry(link, count)
	local icon, quality = Compat.GetItemLook(link)
	return {
		kind = "item",
		id = tonumber(link:match("item:(%d+)")),
		link = link,
		name = link:match("|h%[(.-)%]|h") or link,
		icon = icon,
		quality = quality,
		amount = tonumber(count) or 1,
	}
end

-- Starts reading the events for owner (the loot feed module, whose listeners
-- the registry removes when it stops) and calls emit(entry) for each gain.
function Sources.Start(owner, emit)
	missing = {}
	local itemFormats = compile(ITEM_FORMATS)
	local reputationNames, reputationSigns = {}, {}
	for index, format in ipairs(REPUTATION_FORMATS) do
		reputationNames[index], reputationSigns[format[1]] = format[1], format[2]
	end
	local reputationFormats = compile(reputationNames)

	Bus:OnEvent("CHAT_MSG_LOOT", owner, function(_, text)
		text = known(text)
		if not text then
			return
		end
		for _, compiled in ipairs(itemFormats) do
			local args = match(compiled, text)
			if args then
				emit(itemEntry(args[1], args[2]))
				return
			end
		end
	end)

	Bus:OnEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", owner, function(_, text)
		text = known(text)
		if not text then
			return
		end
		for _, compiled in ipairs(reputationFormats) do
			local args = match(compiled, text)
			if args then
				local amount = tonumber(args[2])
				emit({
					kind = "reputation",
					name = args[1],
					declined = compiled.declined[1],
					amount = amount and amount * reputationSigns[compiled.name],
				})
				return
			end
		end
	end)

	Bus:OnEvent("CURRENCY_DISPLAY_UPDATE", owner, function(_, currencyID, quantity, change)
		currencyID, change = known(currencyID), known(change)
		if not currencyID or not change or change <= 0 then
			return
		end
		local info = Compat.GetCurrencyInfo(currencyID)
		if info and info.discovered then
			emit({
				kind = "currency",
				id = currencyID,
				name = info.name,
				icon = info.icon,
				quality = info.quality,
				amount = change,
				total = known(quantity) or info.quantity,
			})
		end
	end)

	local money = Compat.GetMoney()
	local openWindows = {}
	for showEvent, closeEvent in pairs(MONEY_WINDOWS) do
		Bus:OnEvent(showEvent, owner, function()
			openWindows[showEvent] = true
		end)
		Bus:OnEvent(closeEvent, owner, function()
			openWindows[showEvent] = nil
		end)
	end
	Bus:OnEvent("PLAYER_MONEY", owner, function()
		local now = Compat.GetMoney()
		local gain = now - money
		money = now
		if gain > 0 and next(openWindows) == nil then
			emit({ kind = "money", amount = gain })
		end
	end)

	local xp, xpMax = Compat.GetXP()
	Bus:OnEvent("PLAYER_XP_UPDATE", owner, function(_, unit)
		if unit ~= "player" then
			return
		end
		local now, nowMax = Compat.GetXP()
		-- After a level-up the experience starts again from zero.
		local gain = now >= xp and now - xp or (xpMax - xp) + now
		xp, xpMax = now, nowMax
		if gain > 0 then
			emit({ kind = "xp", amount = gain })
		end
	end)

	Bus:On("LootSkipped", owner, function(_, entry)
		emit(entry)
	end)
end
