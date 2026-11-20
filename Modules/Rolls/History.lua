local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- The roll history, kept by group for the character: from joining a group to
-- leaving it, however many instances it runs (Groups.lua opens and closes
-- them). Each drop of the loot history seen in a group is kept with its time
-- and place (no boss: trash drops too), the item, the winner, and each
-- player's GUID, name, class, level, choice, roll and whether his need was
-- excused. Marks are not kept: they are judged when shown, by the rules of
-- the day. The newest MAX_GROUPS groups and MAX_DROPS drops are kept, the
-- oldest groups going first.
--
-- LootomanCharDB.sections.rollHistory = { schema = 1, groups = { { id
-- (partyGUID or nil), category, started, ended, drops = { { key, time, place,
-- link, quality, winner (GUID), allPassed, rolls = { { guid, name, class,
-- level, state, roll, excused } } } } } } }.
ns.Rolls = ns.Rolls or {}
local History = {}
ns.Rolls.History = History

History.SECTION = "rollHistory"
History.SCHEMA = 1
History.MAX_GROUPS = 30
History.MAX_DROPS = 400

-- The quality of an item by its link's colour, when the game has not loaded it.
local COLORS = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6 }

function History.Section()
	local saved = Storage:GetCharacterSection(History.SECTION)
	saved.schema = saved.schema or History.SCHEMA
	if type(saved.groups) ~= "table" then
		saved.groups = {}
	end
	return saved
end

function History.Groups()
	return History.Section().groups
end

-- The group open now, or nil.
function History.Open()
	local groups = History.Groups()
	local last = groups[#groups]
	if type(last) == "table" and not last.ended then
		return last
	end
	return nil
end

local function trim()
	local groups = History.Groups()
	local function total()
		local count = 0
		for _, group in ipairs(groups) do
			count = count + #group.drops
		end
		return count
	end
	while #groups > History.MAX_GROUPS or (#groups > 1 and total() > History.MAX_DROPS) do
		table.remove(groups, 1)
	end
	local only = groups[1]
	while only and #groups == 1 and #only.drops > History.MAX_DROPS do
		table.remove(only.drops, 1)
	end
end

-- Opens a group (closing one still open).
function History.Start(id, category)
	local open = History.Open()
	if open then
		open.ended = Compat.GetServerTime()
	end
	local group = { id = id, category = category, started = Compat.GetServerTime(), drops = {} }
	local groups = History.Groups()
	groups[#groups + 1] = group
	trim()
	return group
end

function History.Close()
	local open = History.Open()
	if open then
		open.ended = Compat.GetServerTime()
	end
end

local function qualityOf(link)
	local info = Compat.GetItemInfo(link)
	if info and info.quality then
		return info.quality
	end
	local color = type(link) == "string" and link:match("|cff(%x%x%x%x%x%x)")
	return color and COLORS[color:lower()] or nil
end

-- The group's members' levels by GUID, read now.
local function levels()
	local found = {}
	for _, unit in ipairs(Compat.GetGroupUnits()) do
		local guid = Compat.GetUnitGUID(unit)
		if guid then
			found[guid] = Compat.GetUnitLevel(unit)
		end
	end
	return found
end

-- Keeps a drop of the loot history (as the model holds it) in the open group,
-- or updates it there. Nothing without an open group.
function History.Record(drop)
	local group = History.Open()
	if not group or type(drop) ~= "table" or not drop.key or not drop.link then
		return nil
	end
	local entry
	for _, kept in ipairs(group.drops) do
		if kept.key == drop.key then
			entry = kept
		end
	end
	if not entry then
		entry = { key = drop.key, time = Compat.GetServerTime(), place = Compat.GetPlace(), link = drop.link, quality = qualityOf(drop.link), rolls = {} }
		group.drops[#group.drops + 1] = entry
	end
	local before, now = {}, levels()
	for _, player in ipairs(entry.rolls) do
		if player.guid then
			before[player.guid] = player
		end
	end
	local rolls = {}
	for index, player in ipairs(drop.rolls or {}) do
		local kept = player.guid and before[player.guid] or {}
		rolls[index] = {
			guid = player.guid,
			name = player.name,
			class = player.class,
			level = player.level or (player.guid and now[player.guid]) or kept.level,
			state = player.state,
			roll = player.roll,
			excused = kept.excused,
		}
	end
	entry.rolls = rolls
	entry.winner = drop.winner and drop.winner.guid or nil
	entry.allPassed = drop.allPassed or nil
	trim()
	return entry
end

-- A drop kept in a group, by its key.
function History.Find(group, key)
	for _, entry in ipairs(group and group.drops or {}) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- A player's choices in a group in time order, up to the drop with the key
-- untilKey (not included) when given: { link, state, roll, excused, key, time,
-- place, level }.
function History.Choices(group, guid, untilKey)
	local choices = {}
	for _, entry in ipairs(group and group.drops or {}) do
		if untilKey and entry.key == untilKey then
			break
		end
		for _, player in ipairs(entry.rolls) do
			if player.guid == guid then
				choices[#choices + 1] = { link = entry.link, state = player.state, roll = player.roll, excused = player.excused, key = entry.key,
					time = entry.time, place = entry.place, level = player.level }
			end
		end
	end
	return choices
end

-- The last group before the given one (or before the open one) in which the
-- player chose on something; nil when there is none.
function History.LastShared(guid, current)
	local groups = History.Groups()
	local index = #groups
	if current then
		for position, group in ipairs(groups) do
			if group == current then
				index = position
			end
		end
	end
	for position = index - 1, 1, -1 do
		if #History.Choices(groups[position], guid) > 0 then
			return groups[position]
		end
	end
	return nil
end

-- Excuses a player's need on a drop of any kept group ("they asked in the
-- chat"), or takes it back. True when the choice was found.
function History.SetExcused(group, key, guid, excused)
	local entry = History.Find(group, key)
	for _, player in ipairs(entry and entry.rolls or {}) do
		if player.guid == guid then
			player.excused = excused or nil
			return true
		end
	end
	return false
end

local STATE = ns.Rules.Need.STATE

-- What one choice adds to a player's counts.
local function count(into, state, won)
	if state == STATE.NEED or state == STATE.NEED_OFF_SPEC then
		into.need = into.need + 1
	elseif state == STATE.GREED or state == STATE.TRANSMOG then
		into.greed = into.greed + 1
	elseif state == STATE.PASS then
		into.pass = into.pass + 1
	end
	if won then
		into.won = into.won + 1
	end
end

local function newCounts(player)
	return { guid = player.guid, name = player.name, class = player.class, need = 0, greed = 0, pass = 0, won = 0 }
end

-- A group's players in the order they first chose, each with their counts:
-- { guid, name, class, need, greed (transmog too), pass, won }; a player
-- known by GUID, under the name of their latest choice.
function History.Players(group)
	local players, byGUID = {}, {}
	for _, entry in ipairs(group and group.drops or {}) do
		for _, kept in ipairs(entry.rolls) do
			local id = kept.guid or kept.name
			if id then
				local player = byGUID[id]
				if not player then
					player = newCounts(kept)
					byGUID[id] = player
					players[#players + 1] = player
				end
				player.name, player.class = kept.name or player.name, kept.class or player.class
				count(player, kept.state, kept.guid ~= nil and entry.winner == kept.guid)
			end
		end
	end
	return players
end

-- A group's places, each once, in the order it was in them.
function History.Places(group)
	local places, seen = {}, {}
	for _, entry in ipairs(group and group.drops or {}) do
		if entry.place and not seen[entry.place] then
			seen[entry.place] = true
			places[#places + 1] = entry.place
		end
	end
	return places
end

-- A player in every kept group, by GUID: their counts over all of them, under
-- their latest name, and the groups they chose in, newest first, each with
-- its drops they chose on: { player, groups = { { group, drops = { { entry,
-- choice } } } } }; nil when no group has them.
function History.Across(guid)
	local found, player = {}, nil
	local groups = History.Groups()
	for index = #groups, 1, -1 do
		local group = groups[index]
		local drops = {}
		for _, entry in ipairs(group.drops) do
			for _, kept in ipairs(entry.rolls) do
				if kept.guid == guid then
					drops[#drops + 1] = { entry = entry, choice = kept }
					if not player then
						-- The newest group first: its name is the latest.
						player = newCounts(kept)
					end
					count(player, kept.state, entry.winner == guid)
				end
			end
		end
		if #drops > 0 then
			found[#found + 1] = { group = group, drops = drops }
		end
	end
	if not player then
		return nil
	end
	return { player = player, groups = found }
end

-- Deletes a kept group. The open group may go too: the next drop in a group
-- starts a new one.
function History.Delete(group)
	local groups = History.Groups()
	for index = #groups, 1, -1 do
		if groups[index] == group then
			table.remove(groups, index)
			return true
		end
	end
	return false
end

-- Deletes every kept group.
function History.Clear()
	History.Section().groups = {}
end

-- How many groups and drops are kept, for the bug report.
function History.Size()
	local drops = 0
	for _, group in ipairs(History.Groups()) do
		drops = drops + #group.drops
	end
	return #History.Groups(), drops
end
