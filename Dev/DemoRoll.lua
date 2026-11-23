local _, ns = ...
local Compat, L, Storage, Text = ns.Compat, ns.L, ns.Storage, ns.Text

-- Exists only when the addon runs from the repository (Dev/Demo.lua): the
-- loot rolls' demo, for testing and pictures, as if the character were in a
-- made-up group under the name Player:
--
--   /ltm demo roll dung [IDs]   a dungeon's group of five: four heroes of
--       the classic game (Varian the tank, Tyrande the healer, Jaina and
--       Shaw dealing damage) and Player, the third to deal damage; one item
--       (the data's group item)
--   /ltm demo roll raid [IDs]   a raid of forty: the dungeon's four, nine
--       more heroes, Player, and twenty-six others (Test1, Test2, …) who pass
--       on everything; five of Onyxia's items
--
-- IDs: the items to roll on this time, split by commas without spaces
-- (5191,6460). Player has the character's class, level and GUID, and a name
-- of no real character. Everything drops at once, as a boss's loot. A roll
-- runs LENGTH seconds; the made-up players choose and roll one by one within
-- CHOSEN seconds (a hero the item fits needs it now and then, the others
-- greed or pass; one needs what his class should not, or carries a mark of
-- his made-up past, for the detection), and the roll ends with its winner
-- as soon as everyone has chosen, or when its time is up: then Player
-- passes, as the game does for an untouched roll.
--
-- The windows go by the options, as for real rolls. With the game's roll
-- frames shown, look-alikes of them stand where they would (up to FRAMES at
-- once; the others wait for a free one), each with its panel (with Show Who
-- Rolled What on); a choice on one takes it away, and the Loot Rolls window
-- opens a moment later with that roll and the others still going (with its
-- option on), or takes it in when open. With Hide the Game's Roll Frames on
-- (and the window's option with it), the window opens at once
-- with the rolls on top, our buttons and their timers; a choice moves a roll
-- under the line. A right click on a marked need excuses it, in the demo
-- only; no Suspicious Needs window at the end (/ltm demo exceptions shows
-- one, Dev/DemoExceptions.lua). Nothing goes to the game,
-- nothing into the history. An item the game does not give in a moment is
-- left out, and worn gear stands in when none comes. No demo while a real
-- roll is open, or in a fight (its frames are made out of combat).
-- Development text is not translated.
local Demo = ns.Rolls.Demo
local Panel, Marks, LiveWindow = ns.Rolls.Panel, ns.Rolls.Marks, ns.Rolls.LiveWindow
local Need = ns.Rules.Need
local STATE = Need.STATE

-- How long a roll runs, how often the made-up players move, and by when
-- they have all chosen, in seconds.
Demo.LENGTH = 60
Demo.STEP = 0.5
Demo.CHOSEN = 12
-- The game's roll frames at once.
Demo.FRAMES = 4
Demo.RAID_SIZE = 40
-- How many times the demo waits for its items, and how long each time.
Demo.TRIES, Demo.WAIT = 5, 0.3
Demo.ME = "Player"

-- The dungeon's heroes, in the group's order: tank, healer, two damage
-- dealers. { key, name, class }.
Demo.DUNGEON = {
	{ "Varian", L["Varian"], "WARRIOR" }, { "Tyrande", L["Tyrande"], "PRIEST" }, { "Jaina", L["Jaina"], "MAGE" }, { "Shaw", L["Shaw"], "ROGUE" },
}
-- The raid's heroes besides the dungeon's four.
Demo.RAIDERS = {
	{ "Thrall", L["Thrall"], "SHAMAN" }, { "Uther", L["Uther"], "PALADIN" }, { "Sylvanas", L["Sylvanas"], "HUNTER" },
	{ "Malfurion", L["Malfurion"], "DRUID" }, { "Gul'dan", L["Gul'dan"], "WARLOCK" }, { "Rexxar", L["Rexxar"], "HUNTER" },
	{ "Khadgar", L["Khadgar"], "MAGE" }, { "Muradin", L["Muradin"], "WARRIOR" }, { "Anduin", L["Anduin"], "PRIEST" },
}

-- RollOnLoot's types, as the Loot Rolls window's buttons give them, as choices.
local CHOICES = { [0] = STATE.PASS, [1] = STATE.NEED, [2] = STATE.GREED, [4] = STATE.TRANSMOG }

-- No history in the demo: its marks come from its own made-up past.
local NO_HISTORY = {
	Open = function() return nil end,
	Choices = function() return {} end,
	LastShared = function() return nil end,
}

-- The made-up group, in its order: { name, class, guid, level, isSelf,
-- passes (one who passes on everything) }; kind "dung" or "raid". The heroes
-- are those whose class the client has.
function Demo.Party(kind)
	local level = Compat.GetUnitLevel("player") or 60
	local party = {}
	local function hero(entry)
		if ns.Data.rolls.canEquip[entry[3]] then
			party[#party + 1] = { name = entry[2], class = entry[3], guid = "Demo-" .. entry[1], level = level }
		end
	end
	for _, entry in ipairs(Demo.DUNGEON) do
		hero(entry)
	end
	if kind == "raid" then
		for _, entry in ipairs(Demo.RAIDERS) do
			hero(entry)
		end
	end
	party[#party + 1] = { name = Demo.ME, class = Compat.GetPlayerClass() or "WARRIOR", guid = Compat.GetPlayerGUID() or "Demo-Player",
		level = level, isSelf = true }
	if kind == "raid" then
		local classes = ns.Data.rolls.classes
		local index = 0
		while #party < Demo.RAID_SIZE do
			index = index + 1
			party[#party + 1] = { name = ("Test%d"):format(index), class = classes[((index - 1) % #classes) + 1][1], guid = "Demo-Test" .. index,
				level = level, passes = true }
		end
	end
	return party
end

-- A repeatable sequence of numbers from 1 to n.
function Demo.Sequence(seed)
	local value = seed % 2147483648
	return function(n)
		value = (value * 1103515245 + 12345) % 2147483648
		return math.floor(value / 65536) % n + 1
	end
end

-- Whether the item fits a player's class, as the detection judges it; an
-- item the game has not described yet fits.
local function fits(facts, player)
	return not facts or Marks.Fits(facts, player.class, player.level)
end

-- What the made-up players do on a roll, { player, state, roll, at } (at:
-- seconds from its start), and the made-up reasons of their marks. One hero
-- needs an item that does not fit his class; when the item fits them all,
-- one who needs it carries a mark of his past. In a raid, one more who needs
-- is marked as needing nearly everything.
local function script(view, kind, next)
	local facts = Marks.Facts(view.link)
	local heroes = {}
	for _, player in ipairs(view.players) do
		if not player.isSelf and not player.passes then
			heroes[#heroes + 1] = player
		end
	end
	local ninja
	local first = #heroes > 0 and next(#heroes) or 1
	for offset = 0, #heroes - 1 do
		local hero = heroes[((first + offset - 1) % #heroes) + 1]
		if not ninja and not fits(facts, hero) then
			ninja = hero
		end
	end
	local moves, needers = {}, {}
	local steps = math.floor(Demo.CHOSEN / Demo.STEP)
	for _, player in ipairs(view.players) do
		if not player.isSelf then
			local state
			if player.passes then
				state = STATE.PASS
			elseif player == ninja then
				state = STATE.NEED
			elseif not fits(facts, player) then
				state = next(10) <= 7 and STATE.GREED or STATE.PASS
			else
				local pick = next(10)
				state = pick <= 4 and STATE.NEED or (pick <= 9 and STATE.GREED or STATE.PASS)
			end
			if state == STATE.NEED and player ~= ninja then
				needers[#needers + 1] = player
			end
			local at = (player.passes and next(8) or (next(steps - 2) + 2)) * Demo.STEP
			moves[#moves + 1] = { player = player, state = state, roll = state ~= STATE.PASS and next(100) or nil, at = at }
		end
	end
	local reasons = {}
	local past = ninja == nil and (needers[1] or heroes[1]) or nil
	if past then
		for _, move in ipairs(moves) do
			if move.player == past then
				move.state, move.roll = STATE.NEED, move.roll or next(100)
			end
		end
		reasons[past.guid] = { { kind = "lastTime", needs = 6, total = 7, day = Compat.FormatDay(Compat.GetServerTime() - 86400),
			place = Compat.GetPlace() } }
	end
	local greedy = kind == "raid" and needers[#needers] or nil
	if greedy and greedy ~= past then
		reasons[greedy.guid] = { { kind = "everything", needs = 4, total = 5 } }
	end
	return moves, reasons
end

-- The leader now: the highest need's roll, else the highest greed's.
local function leaderOf(players)
	for _, wanted in ipairs({ "need", "greed" }) do
		local best
		for _, player in ipairs(players) do
			local matches = (wanted == "need" and Need.IsNeed(player.state)) or (wanted == "greed" and player.state == STATE.GREED)
			if matches and player.roll and (not best or player.roll > best.roll) then
				best = player
			end
		end
		if best then
			return best
		end
	end
	return nil
end

local cards = {}
local rolls = {}
local generation = 0
local running = false

-- The look-alikes and the rolls of the last demo, for tests.
Demo.cards = cards
Demo.rolls = rolls

local choose

-- A look-alike of the game's roll frame (Modules/Shared/RollLookalike.lua)
-- with its panel; its buttons are the player's choice on its roll.
local function newCard()
	local card = ns.RollLookalike.New()
	card.onChoose = function(owner, state)
		if owner.roll then
			choose(owner.roll, state)
		end
	end
	card.panel = Panel.New()
	card.panel.onRightClick = function(owner, player, view)
		ns.Rolls.SuspiciousNeeds.Menu(owner, player, view)
	end
	return card
end

-- Takes a roll's look-alike away, as the game takes its frame away.
local function free(roll)
	local card = roll.card
	if card then
		card.roll, roll.card = nil, nil
		card.frame:Hide()
		Panel.Hide(card.panel)
	end
end

-- Gives the rolls still waiting for the player a free look-alike each, in
-- their order, and stacks them upwards from the first slot, as the game does.
local function deal()
	for _, roll in ipairs(rolls) do
		if not roll.hidden and not roll.card and not roll.over and roll.me.state == STATE.NONE then
			for _, card in ipairs(cards) do
				if not roll.card and not card.roll then
					card.roll, roll.card = roll, card
					ns.RollLookalike.Fill(card, roll.view.link, Demo.LENGTH)
					card.frame:Show()
				end
			end
		end
	end
	local slot = 0
	for _, roll in ipairs(rolls) do
		if roll.card then
			slot = slot + 1
			ns.RollLookalike.Place(roll.card, slot)
		end
	end
end

-- Draws a roll's marks, its look-alike's timer and panel.
local function draw(roll)
	local view = roll.view
	if not roll.over then
		local leader = leaderOf(view.players)
		view.leader = leader
		for _, player in ipairs(view.players) do
			player.isLeader = player == leader or nil
		end
	end
	Marks.Add(view, roll.context)
	if roll.card then
		roll.card.frame.timer:SetValue(math.max(0, Demo.LENGTH - (Compat.GetTime() - roll.started)))
		-- Its panel as a real roll's: while Show Who Rolled What is on.
		if Storage:Get("Rolls", "panels") then
			Panel.Show(roll.card.panel, roll.card.frame, view)
		else
			Panel.Hide(roll.card.panel)
		end
	end
end

local function drawAll()
	for _, roll in ipairs(rolls) do
		draw(roll)
	end
	LiveWindow.Redraw()
end

local function chosenByAll(roll)
	for _, player in ipairs(roll.view.players) do
		if player.state == STATE.NONE then
			return false
		end
	end
	return true
end

-- Ends a roll: what is left of the made-up players' moves, a pass for the
-- player if untouched, and its winner (or all passed).
local function finish(roll)
	if roll.over then
		return
	end
	for _, move in ipairs(roll.moves) do
		if not move.done then
			move.done = true
			move.player.state, move.player.roll = move.state, move.roll
		end
	end
	if roll.me.state == STATE.NONE then
		roll.me.state = STATE.PASS
	end
	roll.over = true
	local view = roll.view
	view.choosable, view.leader = nil, nil
	local winner = leaderOf(view.players)
	for _, player in ipairs(view.players) do
		player.isLeader = nil
		player.isWinner = player == winner or nil
	end
	view.winner = winner
	view.allPassed = winner == nil or nil
	free(roll)
end

-- Opens the Loot Rolls window with a roll and the demo's other rolls still
-- going, as it opens for a real one; open already, it takes the roll in.
local function openWith(roll)
	local frame = LiveWindow.Frame()
	if not frame then
		return
	end
	if not frame:IsShown() then
		for _, other in ipairs(rolls) do
			if other ~= roll and not other.over then
				LiveWindow.AddView(other.view, true)
			end
		end
	end
	LiveWindow.AddView(roll.view)
end

-- The player's choice on a roll, from a look-alike or the window's buttons:
-- only the demo hears it.
choose = function(roll, state)
	if roll.over or not state or roll.me.state ~= STATE.NONE then
		return
	end
	roll.me.state = state
	roll.me.roll = state ~= STATE.PASS and roll.next(100) or nil
	roll.view.choosable = nil
	free(roll)
	if chosenByAll(roll) then
		finish(roll)
	end
	deal()
	drawAll()
	if roll.hidden then
		return
	end
	-- The window as after a real choice: open, it takes the roll in at
	-- once; closed, it opens a moment later, with its option on.
	local frame = LiveWindow.Frame()
	if frame and frame:IsShown() then
		LiveWindow.AddView(roll.view)
	elseif Storage:Get("Rolls", "liveWindow") then
		Compat.After(LiveWindow.WAIT, function()
			if ns.Rolls.Module.active then
				openWith(roll)
			end
		end)
	end
end

-- Moves the made-up players and ends the rolls, step by step.
local function tick(mine)
	Compat.After(Demo.STEP, function()
		if generation ~= mine then
			return
		end
		local now = Compat.GetTime()
		local going = false
		for _, roll in ipairs(rolls) do
			if not roll.over then
				local elapsed = now - roll.started + 0.001
				for _, move in ipairs(roll.moves) do
					if not move.done and move.at <= elapsed then
						move.done = true
						move.player.state, move.player.roll = move.state, move.roll
					end
				end
				if chosenByAll(roll) or elapsed >= Demo.LENGTH then
					finish(roll)
				else
					going = true
				end
			end
		end
		deal()
		drawAll()
		if going then
			tick(mine)
		else
			running = false
		end
	end)
end

-- Excuses a need of the demo, or takes it back: only the demo hears it.
function Demo.SetExcused(view, guid, excused)
	local roll = view.demoRoll
	if roll and guid then
		roll.excused[guid] = excused or nil
		draw(roll)
		LiveWindow.Redraw()
	end
end

-- Why the demo cannot start now, or nil.
function Demo.Blocked()
	local module = ns.Rolls.Module
	if not (module and module.active) then
		return "demo roll: the loot rolls are off."
	elseif Compat.InCombat() then
		return "demo roll: it starts out of combat."
	elseif #ns.Rolls.Model.Rolls() > 0 then
		return "demo roll: it waits until the rolls in progress are over."
	end
	return nil
end

-- The links of the items, and the IDs the game has not given yet (asked for).
local function load(ids)
	local links, absent = {}, {}
	for _, id in ipairs(ids) do
		local info = Compat.GetItemInfo(id)
		if info and info.link then
			links[#links + 1] = info.link
		else
			Compat.RequestItem(id)
			absent[#absent + 1] = id
		end
	end
	return links, absent
end

-- Worn gear, up to count pieces, for items the game does not give.
local function worn(count)
	local links, seen = {}, {}
	for _, slot in ipairs(ns.RollLookalike.SLOTS) do
		local link = Compat.GetEquippedLink(slot)
		local id = link and link:match("item:(%d+)")
		if id and not seen[id] and #links < count then
			seen[id] = true
			links[#links + 1] = link
		end
	end
	return links
end

-- The rolls of a run, one per item.
local function newRolls(kind, links, hidden, mine)
	local party = Demo.Party(kind)
	local next = Demo.Sequence(math.floor(Compat.GetTime() * 10) + #links)
	local now = Compat.GetTime()
	local list = {}
	for index, link in ipairs(links) do
		local players, levels = {}, {}
		for position, member in ipairs(party) do
			local player = {}
			for key, value in pairs(member) do
				player[key] = value
			end
			player.state = STATE.NONE
			players[position] = player
			levels[player.guid] = player.level
		end
		local view = { rollID = "demo" .. index, link = link, bound = true, demo = true, players = players,
			item = { canNeed = true, canGreed = true, canTransmog = false } }
		local roll = { view = view, started = now, generation = mine, hidden = hidden, excused = {}, next = next }
		view.demoRoll = roll
		for _, player in ipairs(players) do
			if player.isSelf then
				roll.me = player
			end
		end
		local reasons
		roll.moves, reasons = script(view, kind, next)
		roll.context = { history = NO_HISTORY, reasons = reasons, levels = levels, excused = roll.excused }
		view.onChoose = function(rollType)
			choose(roll, CHOICES[rollType])
		end
		if hidden then
			view.choosable = true
			view.timeShare = function()
				if roll.over then
					return nil
				end
				local share = 1 - (Compat.GetTime() - roll.started) / Demo.LENGTH
				return share > 0 and share or nil
			end
		end
		list[index] = roll
	end
	return list
end

-- Plays a run: kind "dung" or "raid", ids the items (or the data's). Returns
-- false, with why, when it cannot start.
function Demo.Start(kind, ids, tries)
	local blocked = Demo.Blocked()
	if blocked then
		ns.Print(blocked)
		return false, blocked
	end
	Demo.Stop()
	generation = generation + 1
	running = true
	local mine = generation
	local data = ns.Data.rolls
	local wanted = ids or (kind == "raid" and data.demoRaidItems or { data.demoItems.group })
	local links, absent = load(wanted)
	-- The game gives an item it has not seen this session a moment later.
	tries = tries or 1
	if #absent > 0 and tries < Demo.TRIES then
		Compat.After(Demo.WAIT, function()
			if generation == mine then
				Demo.Start(kind, ids, tries + 1)
			end
		end)
		return true
	end
	for _, id in ipairs(absent) do
		ns.Print(("demo roll: item %d did not come; left out."):format(id))
	end
	if #links == 0 then
		links = worn(#wanted)
	end
	if #links == 0 then
		running = false
		ns.Print("demo roll: none of its items came; try again.")
		return false
	end
	local hidden = ns.Rolls.Module.HidesGameFrames()
	for index = #rolls, 1, -1 do
		rolls[index] = nil
	end
	for index, roll in ipairs(newRolls(kind, links, hidden, mine)) do
		rolls[index] = roll
	end
	if not hidden then
		for slot = 1, Demo.FRAMES do
			cards[slot] = cards[slot] or newCard()
		end
		deal()
	end
	drawAll()
	-- The drops come into the window as a boss's loot does: with the game's
	-- frames kept away it opens with them, whatever its option says; else
	-- only an open window takes them in.
	local frame = LiveWindow.Frame()
	if hidden or (frame and frame:IsShown()) then
		for _, roll in ipairs(rolls) do
			LiveWindow.AddView(roll.view)
		end
	end
	tick(mine)
	return true
end

-- Ends the run at once: each roll gets its winner, the look-alikes go.
function Demo.Stop()
	generation = generation + 1
	running = false
	for _, roll in ipairs(rolls) do
		finish(roll)
	end
	for _, card in ipairs(cards) do
		card.roll = nil
		card.frame:Hide()
		Panel.Hide(card.panel)
	end
	if #rolls > 0 then
		LiveWindow.Redraw()
	end
end

function Demo.IsRunning()
	return running
end

local USAGE = {
	"/ltm demo roll dung [IDs]: a dungeon's group of five rolls on an item, you as Player",
	"/ltm demo roll raid [IDs]: a raid of forty rolls on five of Onyxia's items, you as Player",
	"  IDs: the items this time, split by commas without spaces (5191,6460)",
}

-- The command's words: the kind and the item IDs, or nil and what is wrong.
function Demo.Read(text)
	local kind, list, extra = (text or ""):match("^%s*(%S*)%s*(%S*)%s*(.-)%s*$")
	kind = Text.FoldCase(kind or "")
	if kind == "dungeon" then
		kind = "dung"
	end
	if kind ~= "dung" and kind ~= "raid" then
		return nil
	end
	if extra ~= "" then
		return nil, "the IDs go split by commas without spaces"
	end
	local ids
	if list ~= "" then
		ids = {}
		for id in (list .. ","):gmatch("([^,]*),") do
			local number = tonumber(id)
			if not number or number < 1 or number % 1 ~= 0 then
				return nil, ("“%s” is not an item's ID"):format(id)
			end
			ids[#ids + 1] = number
		end
	end
	return kind, ids
end

ns.Slash.RegisterDemo("roll", function(rest)
	local kind, ids = Demo.Read(rest)
	if kind then
		Demo.Start(kind, ids)
		return
	end
	-- Not read: ids is what is wrong, if anything.
	if ids then
		ns.Print(("demo roll: %s."):format(ids))
	end
	for _, line in ipairs(USAGE) do
		ns.Print(line)
	end
end, "/ltm demo roll dung|raid [IDs]: a boss's loot rolled on by a made-up group, you as Player (alone: more)")
