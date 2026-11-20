local _, ns = ...
local Compat = ns.Compat

-- The chat as a fallback for a roll the loot history never shows: once a roll
-- has waited WAIT seconds without its drop, the lines the game writes about
-- it (CHAT_MSG_LOOT: "Brina has selected Need for: [Mail Helm]", "Need Roll -
-- 87 for [Mail Helm] by Brina") make a drop of its own for the model. The
-- lines are read with patterns built from the game's own strings, so any
-- language works, numbered arguments included (%2$s). A name from the chat
-- gets its class, level and GUID from the group's units, which are not secret
-- for members. Lines are kept a little while, for a roll still waiting.
ns.Rolls = ns.Rolls or {}
local Chat = {}
ns.Rolls.Chat = Chat

local Model = ns.Rolls.Model
local STATE = ns.Rules.Need.STATE

Chat.WAIT = 2
-- How long a line is kept for a roll that may still need it.
Chat.KEEP = 120

-- The game's strings, what each tells, and the role of each of its arguments
-- in their English order.
Chat.LINES = {
	{ "LOOT_ROLL_NEED", state = STATE.NEED, args = { "name", "item" } },
	{ "LOOT_ROLL_GREED", state = STATE.GREED, args = { "name", "item" } },
	{ "LOOT_ROLL_TRANSMOG", state = STATE.TRANSMOG, args = { "name", "item" } },
	{ "LOOT_ROLL_PASSED", state = STATE.PASS, args = { "name", "item" } },
	{ "LOOT_ROLL_PASSED_AUTO", state = STATE.PASS, args = { "name", "item" } },
	{ "LOOT_ROLL_PASSED_AUTO_FEMALE", state = STATE.PASS, args = { "name", "item" } },
	{ "LOOT_ROLL_NEED_SELF", state = STATE.NEED, args = { "item" }, self = true },
	{ "LOOT_ROLL_GREED_SELF", state = STATE.GREED, args = { "item" }, self = true },
	{ "LOOT_ROLL_TRANSMOG_SELF", state = STATE.TRANSMOG, args = { "item" }, self = true },
	{ "LOOT_ROLL_PASSED_SELF", state = STATE.PASS, args = { "item" }, self = true },
	{ "LOOT_ROLL_PASSED_SELF_AUTO", state = STATE.PASS, args = { "item" }, self = true },
	{ "LOOT_ROLL_ROLLED_NEED", state = STATE.NEED, args = { "roll", "item", "name" } },
	{ "LOOT_ROLL_ROLLED_GREED", state = STATE.GREED, args = { "roll", "item", "name" } },
	{ "LOOT_ROLL_ROLLED_TRANSMOG", state = STATE.TRANSMOG, args = { "roll", "item", "name" } },
	{ "LOOT_ROLL_WON", won = true, args = { "name", "item" } },
	{ "LOOT_ROLL_YOU_WON", won = true, args = { "item" }, self = true },
	{ "LOOT_ROLL_ALL_PASSED", allPassed = true, args = { "item" } },
}

-- A Lua pattern for a game string, and for each capture the index of the
-- argument it holds (a translation may reorder them with %2$s).
function Chat.Pattern(format)
	local pattern, args, auto, index = "^", {}, 0, 1
	while index <= #format do
		local position, kind, after = format:match("^%%(%d)%$([sd])()", index)
		if not kind then
			kind, after = format:match("^%%([sd])()", index)
		end
		if kind then
			if position then
				args[#args + 1] = tonumber(position)
			else
				auto = auto + 1
				args[#args + 1] = auto
			end
			pattern = pattern .. (kind == "d" and "(%-?%d+)" or "(.+)")
			index = after
		elseif format:sub(index, index + 1) == "%%" then
			pattern, index = pattern .. "%%", index + 2
		else
			pattern = pattern .. (format:sub(index, index):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
			index = index + 1
		end
	end
	return pattern .. "$", args
end

local patterns

local function build()
	patterns = {}
	for _, line in ipairs(Chat.LINES) do
		local format = Compat.GetGlobalString(line[1])
		if type(format) == "string" and format ~= "" then
			local pattern, args = Chat.Pattern(format)
			patterns[#patterns + 1] = { line = line, pattern = pattern, args = args, order = #patterns }
		end
	end
	-- Lines with fewer names in them first: "Everyone passed on: %s" before
	-- "%s passed on: %s", "You won: %s" before "%s won: %s".
	table.sort(patterns, function(a, b)
		if #a.args ~= #b.args then
			return #a.args < #b.args
		end
		return a.order < b.order
	end)
end

-- What a chat line tells, or nil: { state, won, allPassed, item, name, roll, self }.
function Chat.Read(text)
	if type(text) ~= "string" or Compat.IsSecret(text) then
		return nil
	end
	if not patterns then
		build()
	end
	for _, entry in ipairs(patterns) do
		local captures = { text:match(entry.pattern) }
		if #captures > 0 then
			local found = { state = entry.line.state, won = entry.line.won, allPassed = entry.line.allPassed, self = entry.line.self }
			for capture, argument in ipairs(entry.args) do
				local role = entry.line.args[argument]
				if role then
					found[role] = captures[capture]
				end
			end
			found.roll = tonumber(found.roll)
			if found.item then
				return found
			end
		end
	end
	return nil
end

local function itemOf(link)
	return type(link) == "string" and link:match("item:(%d+)") or nil
end

-- A name as the chat and the units may write it differently: no realm, no
-- spaces or hyphens, letters folded (Forever's "First Surname" in the chat as
-- "First-Surname").
local function folded(name)
	if type(name) ~= "string" then
		return nil
	end
	return ns.Text.FoldCase((name:gsub("[%s%-]", "")))
end

-- The group's members by folded name: { name, class, level, guid }.
local function members()
	local found = {}
	for _, unit in ipairs(Compat.GetGroupUnits()) do
		local name = Compat.GetUnitName(unit)
		if name then
			local member = { name = name, class = Compat.GetUnitClass(unit), level = Compat.GetUnitLevel(unit), guid = Compat.GetUnitGUID(unit),
				isSelf = unit == "player" or Compat.GetUnitGUID(unit) == Compat.GetPlayerGUID() }
			found[folded(name)] = member
		end
	end
	return found
end

local heard = {}
local used = {}

local ORDER = { [STATE.NEED] = 1, [STATE.NEED_OFF_SPEC] = 1, [STATE.TRANSMOG] = 2, [STATE.GREED] = 2, [STATE.PASS] = 3, [STATE.NONE] = 4 }

-- The chat's drop of a roll: every member, his choice and roll from the lines
-- heard about the roll's item, those who chose first by their roll.
local function dropOf(rollID)
	local roll = Model.Roll(rollID)
	local item = roll and itemOf(roll.link)
	if not item then
		return nil
	end
	local group = members()
	local byName, list = {}, {}
	local function entry(name, isSelf)
		local key = isSelf and "\0self" or folded(name)
		local player = byName[key]
		if not player then
			local member
			if isSelf then
				for _, candidate in pairs(group) do
					if candidate.isSelf then
						member = candidate
					end
				end
			else
				member = group[key] or group[folded(name:match("^[^%-]+"))]
			end
			player = { name = member and member.name or name, class = member and member.class, level = member and member.level,
				guid = member and member.guid, state = STATE.NONE, isSelf = isSelf or (member and member.isSelf) or false }
			byName[key] = player
			list[#list + 1] = player
		end
		return player
	end
	for _, member in pairs(group) do
		entry(member.name, member.isSelf)
	end
	local drop = { rolls = list }
	for _, line in ipairs(heard) do
		if line.itemID == item then
			local found = line.found
			if found.allPassed then
				drop.allPassed = true
			elseif found.name or found.self then
				local player = entry(found.name or "", found.self)
				if found.won then
					player.isWinner = true
					drop.winner = player
				else
					player.state = found.state or player.state
					player.roll = found.roll or player.roll
				end
			end
		end
	end
	table.sort(list, function(a, b)
		local orderA, orderB = ORDER[a.state] or 4, ORDER[b.state] or 4
		if orderA ~= orderB then
			return orderA < orderB
		end
		return (a.roll or 0) > (b.roll or 0)
	end)
	return drop
end

-- Hears a chat line (CHAT_MSG_LOOT) and keeps it; a roll the chat stands in
-- for gets its drop again.
function Chat.Hear(text)
	local found = Chat.Read(text)
	if not found then
		return
	end
	local now = Compat.GetTime()
	heard[#heard + 1] = { at = now, itemID = itemOf(found.item), found = found }
	while heard[1] and now - heard[1].at > Chat.KEEP do
		table.remove(heard, 1)
	end
	for rollID in pairs(used) do
		Chat.Use(rollID)
	end
end

-- Makes the chat stand in for a roll still unbound after WAIT seconds.
function Chat.Use(rollID)
	local roll = Model.Roll(rollID)
	if not roll then
		used[rollID] = nil
		return false
	end
	if not used[rollID] and not Model.Unbound(rollID, Chat.WAIT) then
		return false
	end
	if roll.drop and not roll.drop:match("^chat:") then
		used[rollID] = nil
		return false
	end
	used[rollID] = true
	local drop = dropOf(rollID)
	if drop then
		Model.SetChatDrop(rollID, drop)
	end
	return true
end

-- Forgets the lines and the rolls (the module turned off).
function Chat.Reset()
	heard, used, patterns = {}, {}, nil
end
