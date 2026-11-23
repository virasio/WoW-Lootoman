local _, ns = ...
local Compat = ns.Compat

-- Exists only when the addon runs from the repository (Dev/Demo.lua): the
-- made-up roll history, for testing and pictures, of the roll demo's groups
-- (Dev/DemoRoll.lua), the character as Player. /ltm demo rollhistory opens
-- the Roll History window on three of them: two runs of the dungeon's five
-- (Varian, Tyrande, Jaina, Shaw and Player) on dungeon items, Shaw needing
-- nearly everything in the first, one of those needs excused, and coming
-- back to need again in the second; and a raid of forty on Onyxia's items,
-- three heroes needing everything, the Test players passing. Each hero
-- needs what fits his class now and then and greeds the rest. "full" fills
-- it to the history's limits (30 groups, 400 drops) with more runs of the
-- five, to see that it stays quick. It is never saved, and exceptions or
-- deletions in it touch only it. Development text is not translated.
ns.Rolls = ns.Rolls or {}
local DemoHistory = {}
ns.Rolls.DemoHistory = DemoHistory

local History, Marks = ns.Rolls.History, ns.Rolls.Marks
local STATE = ns.Rules.Need.STATE

-- How many times it waits for its items, and how long each time.
DemoHistory.TRIES, DemoHistory.WAIT = 5, 0.3
-- The made-up places; the client's own names are not needed for a demo.
DemoHistory.PLACES = { "The Deadmines", "Wailing Caverns", "Shadowfang Keep", "Onyxia's Lair" }
-- The one who needs nearly everything in the dungeon's runs.
DemoHistory.NEEDY = "Demo-Shaw"

-- The links of the items the game has loaded, each once ({ link, quality }),
-- the dungeon's and the raid's; asks for the others.
function DemoHistory.Items()
	local data = ns.Data.rolls
	local missing, seen = false, {}
	local function links(ids)
		local list = {}
		for _, id in ipairs(ids) do
			if not seen[id] then
				seen[id] = true
				local info = Compat.GetItemInfo(id)
				if info and info.link then
					list[#list + 1] = { link = info.link, quality = info.quality }
				else
					Compat.RequestItem(id)
					missing = true
				end
			end
		end
		return list
	end
	local dungeon = { data.demoItems.group }
	for _, id in ipairs(data.demoHistoryItems or {}) do
		dungeon[#dungeon + 1] = id
	end
	local items = { dungeon = links(dungeon), raid = links(data.demoRaidItems or { data.demoItems.raid }) }
	-- Either list stands in for the other when the game gives none of it.
	if #items.raid == 0 then
		items.raid = items.dungeon
	elseif #items.dungeon == 0 then
		items.dungeon = items.raid
	end
	return items, missing
end

-- A stand-in for History over made-up groups, with the calls the window and
-- the marks use.
function DemoHistory.StandIn(groups)
	local stand = { demo = true, title = "Roll History (Demo)" }
	function stand.Groups()
		return groups
	end
	function stand.Open()
		return nil
	end
	stand.Choices = History.Choices
	stand.Find = History.Find
	stand.SetExcused = History.SetExcused
	function stand.LastShared(guid, current)
		return History.LastShared(guid, current, groups)
	end
	function stand.Across(guid)
		return History.Across(guid, groups)
	end
	function stand.Delete(group)
		for index = #groups, 1, -1 do
			if groups[index] == group then
				table.remove(groups, index)
				return true
			end
		end
		return false
	end
	function stand.Clear()
		for index = #groups, 1, -1 do
			groups[index] = nil
		end
	end
	return stand
end

-- A player's choice on an item: the needy need, those who only pass pass;
-- the others need what fits them now and then, and greed the rest.
local function choiceOf(player, facts, needy, next)
	if player.passes then
		return STATE.PASS
	elseif needy[player.guid] then
		return STATE.NEED
	end
	local pick = next(10)
	if not facts or Marks.Fits(facts, player.class, player.level) then
		return pick <= 3 and STATE.NEED or (pick <= 9 and STATE.GREED or STATE.PASS)
	end
	return pick <= 7 and STATE.GREED or STATE.PASS
end

-- A drop: each player chooses, the highest need wins, else the highest
-- greed, else all passed.
local function newDrop(key, time, place, item, party, needy, next)
	local facts = Marks.Facts(item.link)
	local rolls, best, bestNeed = {}, nil, false
	for index, member in ipairs(party) do
		local state = choiceOf(member, facts, needy, next)
		local roll = state ~= STATE.PASS and next(100) or nil
		rolls[index] = { guid = member.guid, name = member.name, class = member.class, level = member.level, state = state, roll = roll }
		local isNeed = state == STATE.NEED
		if roll and (not best or (isNeed and not bestNeed) or (isNeed == bestNeed and roll > best.roll)) then
			best, bestNeed = rolls[index], isNeed
		end
	end
	return { key = key, time = time, place = place, link = item.link, quality = item.quality, rolls = rolls,
		winner = best and best.guid or nil, allPassed = not best or nil }
end

-- A made-up group, started at a time, with its drops in places.
local function newGroup(id, started, party, places, count, items, needy, next)
	local group = { id = id, started = started, ended = started + 3600, drops = {} }
	for index = 1, count do
		local item = items[next(#items)]
		local place = places[math.min(#places, math.ceil(index * #places / count))]
		group.drops[index] = newDrop(id .. ":" .. index, started + index * 300, place, item, party, needy(index), next)
	end
	return group
end

-- The made-up groups, oldest first: two runs of the dungeon's five and a
-- raid of forty, or, full, as many runs as the history keeps.
function DemoHistory.Groups(items, full, now)
	local Demo = ns.Rolls.Demo
	local next = Demo.Sequence(7)
	local five, forty = Demo.Party("dung"), Demo.Party("raid")
	local needy = DemoHistory.NEEDY
	local groups = {}
	-- The first run: Shaw needs everything; one of those needs was excused.
	groups[1] = newGroup("demo-1", now - 2 * 86400, five, { DemoHistory.PLACES[1], DemoHistory.PLACES[2] }, 6, items.dungeon, function()
		return { [needy] = true }
	end, next)
	for _, player in ipairs(groups[1].drops[2].rolls) do
		if player.guid == needy then
			player.excused = true
		end
	end
	-- The second run: the same five, Shaw needing the first item again.
	groups[2] = newGroup("demo-2", now - 86400, five, { DemoHistory.PLACES[3] }, 5, items.dungeon, function(index)
		return index == 1 and { [needy] = true } or {}
	end, next)
	-- The raid: three heroes need everything.
	local raidNeedy = {}
	for _, key in ipairs({ "Demo-Gul'dan", "Demo-Rexxar", "Demo-Jaina" }) do
		raidNeedy[key] = true
	end
	groups[3] = newGroup("demo-3", now - 7200, forty, { DemoHistory.PLACES[4] }, 5, items.raid, function()
		return raidNeedy
	end, next)
	if full then
		local drops = 16
		local index = 3
		while index < History.MAX_GROUPS do
			index = index + 1
			-- What is left, shared out among the groups still to come.
			local count = math.floor((History.MAX_DROPS - drops) / (History.MAX_GROUPS - index + 1))
			drops = drops + count
			table.insert(groups, 1, newGroup("demo-" .. index, now - index * 86400, five, { DemoHistory.PLACES[(index % 3) + 1] },
				count, items.dungeon, function()
					return {}
				end, next))
		end
	end
	return groups
end

-- fn(items) once the items are in (the game loads an item it has not seen
-- this session a moment later); a line in the chat, under the demo's name,
-- when none came.
function DemoHistory.WithItems(name, fn, tries)
	local items, missing = DemoHistory.Items()
	tries = tries or 1
	if missing and tries < DemoHistory.TRIES then
		Compat.After(DemoHistory.WAIT, function()
			DemoHistory.WithItems(name, fn, tries + 1)
		end)
		return true
	end
	if #items.dungeon == 0 then
		ns.Print(("demo %s: the client has none of its items yet; try again"):format(name))
		return false
	end
	-- Later than the command, from a timer: an error goes to the journal.
	local ok, result = xpcall(function()
		return fn(items)
	end, Compat.ReportError)
	if not ok then
		ns.Print(("demo %s failed: /ltm debug log"):format(name))
	end
	return ok and result
end

-- Opens the Roll History window on the made-up history.
function DemoHistory.Open(full)
	return DemoHistory.WithItems("rollhistory", function(items)
		DemoHistory.history = DemoHistory.StandIn(DemoHistory.Groups(items, full, Compat.GetServerTime()))
		return ns.Rolls.HistoryWindow.Open(DemoHistory.history)
	end)
end

ns.Slash.RegisterDemo("rollhistory", function(rest)
	DemoHistory.Open(rest == "full")
end, "/ltm demo rollhistory [full]: the roll history on a made-up history, full to its limits")
