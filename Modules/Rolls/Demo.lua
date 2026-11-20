local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The demo: two look-alikes of the game's roll frame, drawn as the game draws
-- it (its loot toast art and border, the item's icon in its quality border,
-- the name in its quality colour, the need, greed and pass buttons, the
-- timer), stand where the game's frames would, each with its panel, and play
-- for about 15 seconds. A group roll: five heroes of Azeroth, the first in
-- the player's place (his own line), choose and roll one by one, the leader changes, and there is a winner. A
-- raid roll: twenty heroes. Each hero has the class his stories give him,
-- among the classes the client has. It needs no group and no real roll:
-- everything in it is made up. /ltm debug demoroll plays it, for testing and
-- pictures, not as a player's feature; Edit Mode shows its look-alikes still, where the moved
-- frames will stand. The look-alikes' buttons only mark the player's choice on the
-- look-alike: nothing goes to the game, and nothing into the history. The
-- items are the data's: a blue dagger for the group, a purple staff for the
-- raid, asked of the game and waited for a moment; one the game does not give
-- is replaced by worn gear. No demo while a real roll is open, or in a fight
-- (its frames are made out of combat).
ns.Rolls = ns.Rolls or {}
local Demo = {}
ns.Rolls.Demo = Demo

local Panel = ns.Rolls.Panel
local STATE = ns.Rules.Need.STATE

-- The demo's players: heroes of Azeroth, each with the class of his stories.
Demo.HEROES = {
	{ L["Thrall"], "SHAMAN" }, { L["Jaina"], "MAGE" }, { L["Varian"], "WARRIOR" }, { L["Uther"], "PALADIN" },
	{ L["Sylvanas"], "HUNTER" }, { L["Tyrande"], "PRIEST" }, { L["Malfurion"], "DRUID" }, { L["Valeera"], "ROGUE" },
	{ L["Gul'dan"], "WARLOCK" }, { L["Rexxar"], "HUNTER" }, { L["Anduin"], "PRIEST" }, { L["Khadgar"], "MAGE" },
	{ L["Tirion"], "PALADIN" }, { L["Garrosh"], "WARRIOR" }, { L["Velen"], "PRIEST" }, { L["Alleria"], "HUNTER" },
	{ L["Muradin"], "WARRIOR" }, { L["Hamuul"], "DRUID" }, { L["Kel'Thuzad"], "WARLOCK" }, { L["Shaw"], "ROGUE" },
	{ L["Broll"], "DRUID" }, { L["Turalyon"], "PALADIN" }, { L["Drek'Thar"], "SHAMAN" }, { L["Antonidas"], "MAGE" },
	{ L["Garona"], "ROGUE" }, { L["Nobundo"], "SHAMAN" }, { L["Arthas"], "DEATHKNIGHT" }, { L["Darion"], "DEATHKNIGHT" },
	{ L["Chen"], "MONK" }, { L["Aysa"], "MONK" }, { L["Illidan"], "DEMONHUNTER" }, { L["Kayn"], "DEMONHUNTER" },
	{ L["Wrathion"], "EVOKER" }, { L["Ebyssian"], "EVOKER" },
}
Demo.LENGTH = 15
Demo.STEP = 1.5
Demo.RAID = 20

local cards = {}
local generation = 0
local running = false

-- What the demo plays: its rolls' views, for tests and the marks.
Demo.cards = cards

-- How many times the demo waits for its items, and how long each time.
Demo.TRIES, Demo.WAIT = 5, 0.3

-- The demo's two items, the group's then the raid's (Modules/Shared/RollLookalike.lua).
function Demo.Items()
	return ns.RollLookalike.Items()
end

-- The heroes whose class the client has: { name, class, guid }.
function Demo.Heroes()
	local list = {}
	for index, hero in ipairs(Demo.HEROES) do
		if ns.Data.rolls.canEquip[hero[2]] then
			list[#list + 1] = { name = hero[1], class = hero[2], guid = "Demo-" .. index }
		end
	end
	return list
end

-- A look-alike of the game's roll frame (Modules/Shared/RollLookalike.lua)
-- with its panel; its buttons mark the player's choice on it.
local function newCard()
	local card = ns.RollLookalike.New()
	card.onChoose = function(_, state)
		Demo.Choose(card, state)
	end
	card.panel = Panel.New()
	card.panel.onRightClick = function(owner, player, view)
		ns.Rolls.SuspiciousNeeds.Menu(owner, player, view)
	end
	return card
end

-- The leader now: the highest need's roll, else the highest greed's.
local function leaderOf(players)
	local best
	for _, wanted in ipairs({ "need", "greed" }) do
		for _, player in ipairs(players) do
			local matches = (wanted == "need" and ns.Rules.Need.IsNeed(player.state)) or (wanted == "greed" and player.state == STATE.GREED)
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

-- The view of a card, as the model would give it for a real roll.
local function viewOf(card)
	local view = card.view
	local leader = view.winner or leaderOf(view.players)
	for _, player in ipairs(view.players) do
		player.isLeader = not view.winner and player == leader
	end
	view.leader = leader
	return view
end

function Demo.Draw(card)
	local view = viewOf(card)
	if ns.Rolls.Marks then
		ns.Rolls.Marks.Add(view, card.context)
	end
	Panel.Show(card.panel, card.frame, view)
end

-- The player's choice on a look-alike: only the demo hears it.
function Demo.Choose(card, state)
	for _, player in ipairs(card.view.players) do
		if player.isSelf and player.state == STATE.NONE then
			player.state = state
			player.roll = state ~= STATE.PASS and 50 or nil
			Demo.Draw(card)
		end
	end
end

-- count heroes, from a turn of the clock so each demo differs. In the group
-- roll the first stands for the player (his line marked as one's own), with a
-- hero's name too: the demo is for pictures, and names no real character.
local function newPlayers(count, turn, withSelf)
	local players, heroes = {}, Demo.Heroes()
	for index = 1, math.min(#heroes, count) do
		local hero = heroes[((index + turn) % #heroes) + 1]
		players[index] = { name = hero.name, class = hero.class, guid = hero.guid, level = 30 + ((index * 7 + turn) % 30), state = STATE.NONE,
			isSelf = withSelf and index == 1 or nil }
	end
	return players
end

-- Makes a player of the card another hero, of the class given, who is not on
-- the card yet; false when there is none.
local function becomeHero(card, player, class)
	local taken = {}
	for _, other in ipairs(card.view.players) do
		taken[other.guid] = true
	end
	for _, hero in ipairs(Demo.Heroes()) do
		if hero.class == class and not taken[hero.guid] then
			player.name, player.class, player.guid = hero.name, hero.class, hero.guid
			return true
		end
	end
	return false
end

-- What each made-up player does, step by step: { player, state, roll }.
local function script(players, steps)
	local moves = {}
	local states = { STATE.NEED, STATE.GREED, STATE.PASS, STATE.NEED, STATE.GREED, STATE.NEED }
	local index = 0
	for _, player in ipairs(players) do
		if not player.isSelf then
			index = index + 1
			local state = states[((index - 1) % #states) + 1]
			moves[#moves + 1] = { player = player, state = state, roll = state ~= STATE.PASS and ((index * 37) % 100) + 1 or nil,
				step = ((index - 1) % steps) + 1 }
		end
	end
	return moves
end

local function finish(card)
	local view = card.view
	local winner = leaderOf(view.players)
	if winner then
		winner.isWinner = true
		view.winner = winner
	else
		view.allPassed = true
	end
	Demo.Draw(card)
end

local function play(card, moves, steps, mine)
	for step = 1, steps do
		Compat.After(step * Demo.STEP, function()
			if generation ~= mine then
				return
			end
			for _, move in ipairs(moves) do
				if move.step == step then
					move.player.state, move.player.roll = move.state, move.roll
				end
			end
			card.frame.timer:SetValue(Demo.LENGTH - step * Demo.STEP)
			Demo.Draw(card)
		end)
	end
	Compat.After((steps + 1) * Demo.STEP, function()
		if generation == mine then
			finish(card)
		end
	end)
end

-- Excuses a need of the demo, or takes it back: only the demo hears it.
function Demo.SetExcused(view, guid, excused)
	for _, card in ipairs(cards) do
		if card.view == view then
			card.excused = card.excused or {}
			card.excused[guid] = excused or nil
			if card.context then
				card.context.excused = card.excused
			end
			Demo.Draw(card)
		end
	end
end

-- The demo's marked needs, as the Suspicious Needs window lists them.
function Demo.Rows()
	local rows = {}
	for _, card in ipairs(cards) do
		local view = card.view
		for _, player in ipairs(view and view.players or {}) do
			if player.mark then
				rows[#rows + 1] = {
					name = player.name,
					class = player.class,
					link = view.link,
					reasons = player.notes or { L["Excused"] },
					excused = player.excused == true,
					set = function(excused)
						Demo.SetExcused(view, player.guid, excused)
					end,
				}
			end
		end
	end
	return rows
end

-- The made-up group leaves: its marked needs show as after a real group.
function Demo.Leave()
	if ns.Storage:Get("Rolls", "ninja") and ns.Storage:Get("Rolls", "summary") and #Demo.Rows() > 0 then
		ns.Rolls.SuspiciousNeeds.Open(Demo.Rows)
	end
end

-- No history in the demo: its marks come from its own made-up past.
local NO_HISTORY = {
	Open = function() return nil end,
	Choices = function() return {} end,
	LastShared = function() return nil end,
}

-- The demo's marks, for the detection when it is on. In the group roll the
-- first made-up player needs an item that does not fit his class (a warrior
-- past 40 on mail, when the item is mail) after greeding a BoE item that
-- fits; the fourth carries a mark from a made-up last group. In the raid
-- roll, three of those who need are marked as needing nearly everything.
function Demo.Context(card, group, otherLink)
	local context = { history = NO_HISTORY, reasons = {}, levels = {}, excused = card.excused or {} }
	card.excused = context.excused
	local facts = ns.Rolls.Marks.Facts(card.view.link)
	local made = {}
	for _, player in ipairs(card.view.players) do
		if not player.isSelf then
			made[#made + 1] = player
		end
	end
	if group then
		local first, fourth = made[1], made[4]
		if first and facts then
			if facts.classID == ns.Rules.Need.ARMOR and facts.subclassID == 3 then
				becomeHero(card, first, "WARRIOR")
				first.level = 45
			else
				local breaking = ns.Rolls.Marks.BreakingClass(facts, first.level)
				if breaking and breaking ~= first.class then
					becomeHero(card, first, breaking)
				end
			end
			if facts.bindType == ns.Rolls.Marks.BOE then
				context.reasons[first.guid] = { { kind = "greedFitting", link = otherLink } }
			end
		end
		if fourth then
			context.reasons[fourth.guid] = { { kind = "lastTime", needs = 6, total = 7, day = Compat.FormatDay(Compat.GetServerTime() - 86400),
				place = Compat.GetPlace() } }
		end
	else
		local marked = 0
		for index, player in ipairs(made) do
			if index % 3 == 1 and marked < 3 then
				marked = marked + 1
				context.reasons[player.guid] = { { kind = "everything", needs = 5, total = 6 } }
			end
		end
	end
	for _, player in ipairs(card.view.players) do
		context.levels[player.guid] = player.level
	end
	return context
end

-- Edit Mode shows the roll frames' look-alikes (the roll frames' module's)
-- where the moved frames will stand; while the loot rolls are on, a panel of
-- made-up choices stands beside each, at its right, on the look-alikes'
-- strata and level, so Edit Mode's selection covers them too.
local previews = {}

function Demo.Preview(frames, strata, level)
	local items = Demo.Items()
	for slot, frame in ipairs(frames) do
		local panel = previews[slot] or Panel.New()
		previews[slot] = panel
		if strata then
			panel.frame:SetFrameStrata(strata)
			panel.frame:SetFrameLevel(level or 1)
		end
		local group = slot == 1
		local view = { rollID = "preview" .. slot, link = items[slot], bound = true, demo = true,
			players = newPlayers(group and 5 or Demo.RAID, slot, group) }
		local card = { view = view }
		card.context = Demo.Context(card, group, items[group and 2 or 1])
		ns.Rolls.Marks.Add(view, card.context)
		Panel.Show(panel, frame, view, "right")
	end
end

function Demo.EndPreview()
	for _, panel in ipairs(previews) do
		Panel.Hide(panel)
	end
end

-- Why the demo cannot start now, or nil.
function Demo.Blocked()
	if Compat.InCombat() then
		return L["The demo starts out of combat."]
	elseif #ns.Rolls.Model.Rolls() > 0 then
		return L["The demo waits until the rolls in progress are over."]
	end
	return nil
end

-- Starts the demo (again). Returns false, with why, when it cannot.
function Demo.Start(static, tries)
	local blocked = Demo.Blocked()
	if blocked then
		ns.Print(blocked)
		return false, blocked
	end
	Demo.Stop()
	generation = generation + 1
	running = true
	local mine = generation
	local items, missing = Demo.Items()
	-- The game loads an item it has not seen this session a moment later.
	tries = tries or 1
	if missing and not static and tries < Demo.TRIES then
		Compat.After(Demo.WAIT, function()
			if generation == mine then
				Demo.Start(static, tries + 1)
			end
		end)
		return true
	end
	local turn = math.floor(Compat.GetTime())
	for slot = 1, 2 do
		local card = cards[slot] or newCard()
		cards[slot] = card
		local link = items[slot]
		local info = ns.RollLookalike.Fill(card, link, Demo.LENGTH)
		local group = slot == 1
		local players = newPlayers(group and 5 or Demo.RAID, turn + slot, group)
		card.view = { rollID = "demo" .. slot, link = link, item = info, bound = true, demo = true, players = players }
		card.context = Demo.Context(card, group, items[group and 2 or 1])
		ns.RollLookalike.Place(card, slot)
		card.frame:Show()
		if Demo.OnStart then
			Demo.OnStart(card, slot)
		end
		Demo.Draw(card)
		if not static then
			local steps = math.floor(Demo.LENGTH / Demo.STEP) - 2
			play(card, script(players, steps - 1), steps, mine)
		end
	end
	if not static then
		Compat.After(Demo.LENGTH + Demo.STEP, function()
			if generation == mine then
				Demo.Leave()
			end
		end)
		Compat.After(Demo.LENGTH + 2 * Demo.STEP, function()
			if generation == mine then
				Demo.Stop()
			end
		end)
	end
	return true
end

function Demo.Stop()
	generation = generation + 1
	running = false
	for _, card in ipairs(cards) do
		card.frame:Hide()
		Panel.Hide(card.panel)
	end
end

function Demo.IsRunning()
	return running
end
