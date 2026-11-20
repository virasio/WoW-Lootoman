local _, ns = ...
local Compat = ns.Compat

-- Exists only when the addon runs from the repository (Dev/Demo.lua): the
-- made-up roll history, for testing and pictures. /ltm demo rollhistory
-- opens the Roll History window on three made-up groups of the demo's heroes
-- of Azeroth (Modules/Rolls/Demo.lua): two dungeon runs and a raid, with drops of a few
-- items the client has, a hero who needs nearly everything in the first run
-- and comes back in the second, and an exception; "full" fills it to the
-- history's limits (30 groups, 400 drops), to see that it stays quick. It is
-- never saved, and exceptions or deletions in it touch only it.
-- Development text is not translated.
ns.Rolls = ns.Rolls or {}
local DemoHistory = {}
ns.Rolls.DemoHistory = DemoHistory

local History = ns.Rolls.History
local STATE = ns.Rules.Need.STATE

-- How many times it waits for its items, and how long each time.
DemoHistory.TRIES, DemoHistory.WAIT = 5, 0.3
DemoHistory.RAID = 20
-- The made-up places; the client's own names are not needed for a demo.
DemoHistory.PLACES = { "The Deadmines", "Wailing Caverns", "Shadowfang Keep", "Onyxia's Lair" }

-- The items as links the game has loaded, each once; asks for the others.
function DemoHistory.Items()
	local data = ns.Data.rolls
	local ids, seen = {}, {}
	for _, id in ipairs(data.demoHistoryItems or {}) do
		ids[#ids + 1] = id
	end
	ids[#ids + 1] = data.demoItems.group
	ids[#ids + 1] = data.demoItems.raid
	local links, missing = {}, false
	for _, id in ipairs(ids) do
		if not seen[id] then
			seen[id] = true
			local info = Compat.GetItemInfo(id)
			if info and info.link then
				links[#links + 1] = { link = info.link, quality = info.quality }
			else
				Compat.RequestItem(id)
				missing = true
			end
		end
	end
	return links, missing
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

-- A repeatable sequence of numbers from 1 to n.
local function sequence(seed)
	local value = seed
	return function(n)
		value = (value * 1103515245 + 12345) % 2147483648
		return math.floor(value / 65536) % n + 1
	end
end

-- A drop: each hero chooses (the needy always need), and the highest need
-- wins, else the highest greed, else all passed.
local function newDrop(key, time, place, item, heroes, needy, next)
	local rolls, best, bestNeed = {}, nil, false
	for index, hero in ipairs(heroes) do
		local state
		if needy[hero.guid] then
			state = STATE.NEED
		else
			local pick = next(10)
			state = pick <= 2 and STATE.NEED or (pick <= 7 and STATE.GREED or STATE.PASS)
		end
		local roll = state ~= STATE.PASS and next(100) or nil
		rolls[index] = { guid = hero.guid, name = hero.name, class = hero.class, level = 60, state = state, roll = roll }
		local isNeed = state == STATE.NEED
		if roll and (not best or (isNeed and not bestNeed) or (isNeed == bestNeed and roll > best.roll)) then
			best, bestNeed = rolls[index], isNeed
		end
	end
	return { key = key, time = time, place = place, link = item.link, quality = item.quality, rolls = rolls,
		winner = best and best.guid or nil, allPassed = not best or nil }
end

-- A made-up group of heroes, started at a time, with its drops in places.
local function newGroup(id, started, heroes, places, count, items, needy, next)
	local group = { id = id, started = started, ended = started + 3600, drops = {} }
	for index = 1, count do
		local item = items[next(#items)]
		local place = places[math.min(#places, math.ceil(index * #places / count))]
		group.drops[index] = newDrop(id .. ":" .. index, started + index * 300, place, item, heroes, needy(index), next)
	end
	return group
end

-- The made-up groups: two runs and a raid, or, full, as many as the history keeps.
function DemoHistory.Groups(items, full, now)
	local heroes = ns.Rolls.Demo.Heroes()
	local next = sequence(7)
	local function pick(count, first)
		local list = {}
		for index = 1, math.min(count, #heroes) do
			list[index] = heroes[((first + index - 2) % #heroes) + 1]
		end
		return list
	end
	local five = pick(5, 1)
	local needy = five[1].guid
	local groups = {}
	-- The first run: the first hero needs everything; one of those needs was excused.
	groups[1] = newGroup("demo-1", now - 2 * 86400, five, { DemoHistory.PLACES[1], DemoHistory.PLACES[2] }, 6, items, function()
		return { [needy] = true }
	end, next)
	for _, player in ipairs(groups[1].drops[2].rolls) do
		if player.guid == needy then
			player.excused = true
		end
	end
	-- The second run: the same hero with others, needing the first item again.
	local others = pick(4, 6)
	table.insert(others, 1, five[1])
	groups[2] = newGroup("demo-2", now - 86400, others, { DemoHistory.PLACES[3] }, 5, items, function(index)
		return index == 1 and { [needy] = true } or {}
	end, next)
	-- A raid.
	local raid = pick(DemoHistory.RAID, 3)
	groups[3] = newGroup("demo-3", now - 7200, raid, { DemoHistory.PLACES[4] }, 4, items, function()
		return { [raid[2].guid] = true, [raid[5].guid] = true, [raid[9].guid] = true }
	end, next)
	if full then
		local drops = 15
		local index = 3
		while index < History.MAX_GROUPS do
			index = index + 1
			-- What is left, shared out among the groups still to come.
			local count = math.floor((History.MAX_DROPS - drops) / (History.MAX_GROUPS - index + 1))
			drops = drops + count
			table.insert(groups, 1, newGroup("demo-" .. index, now - index * 86400, pick(5, index), { DemoHistory.PLACES[(index % 3) + 1] },
				count, items, function()
					return {}
				end, next))
		end
	end
	return groups
end

DemoHistory.NewDrop = newDrop

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
	if #items == 0 then
		ns.Print(("demo %s: the client has none of its items yet; try again"):format(name))
		return false
	end
	return fn(items)
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
