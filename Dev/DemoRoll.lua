local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
-- /ltm demo roll plays the loot rolls' demo, for testing and pictures. Two
-- look-alikes of the game's roll frame (Modules/Shared/RollLookalike.lua)
-- stand where the game's frames would, each with its panel, and play for
-- about 15 seconds: a group roll of five heroes of Azeroth, the first in the
-- player's place (their own line), who choose and roll one by one while the
-- leader changes, until there is a winner; and a raid roll of twenty
-- (Modules/Rolls/Demo.lua has the heroes and their made-up past). The
-- look-alikes' buttons only mark the player's choice on the look-alike:
-- nothing goes to the game, nothing into the history. One the game does not
-- give of the data's items is replaced by worn gear. No demo while a real
-- roll is open, or in a fight (its frames are made out of combat).
-- Development text is not translated.
local Demo = ns.Rolls.Demo
local Panel = ns.Rolls.Panel
local STATE = ns.Rules.Need.STATE

Demo.LENGTH = 15
Demo.STEP = 1.5

local cards = {}
local generation = 0
local running = false

-- What the demo plays: its rolls' views, for tests and the marks.
Demo.cards = cards

-- How many times the demo waits for its items, and how long each time.
Demo.TRIES, Demo.WAIT = 5, 0.3

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

-- Why the demo cannot start now, or nil.
function Demo.Blocked()
	if Compat.InCombat() then
		return "demo roll: it starts out of combat."
	elseif #ns.Rolls.Model.Rolls() > 0 then
		return "demo roll: it waits until the rolls in progress are over."
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
		local players = Demo.NewPlayers(group and 5 or Demo.RAID, turn + slot, group)
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

ns.Slash.RegisterDemo("roll", function()
	Demo.Start()
end, "/ltm demo roll: play the loot rolls' demo, with no group")
