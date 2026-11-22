local _, ns = ...
local Compat = ns.Compat

-- Exists only when the addon runs from the repository (Dev/Demo.lua):
-- /ltm demo lootrolls opens the Loot Rolls window on made-up drops of a run
-- of five of the demo's heroes, for testing and pictures: the newest still
-- rolled on, two won (by need, by greed) and one all passed, with the first
-- hero needing everything (marked, with the detection on), on either client.
-- With Hide the Game's Roll Frames on, the newest is a roll to choose on, as
-- the window shows a real one: our buttons, which do nothing in the game
-- (a choice moves the row down, under the line), and a timer that runs
-- (TIME); untouched, it ends as a pass would.
-- Never saved. Development text is not translated.
ns.Rolls = ns.Rolls or {}
local DemoLootRolls = {}
ns.Rolls.DemoLootRolls = DemoLootRolls

local DemoHistory, DropRow = ns.Rolls.DemoHistory, ns.Rolls.DropRow
local STATE = ns.Rules.Need.STATE

DemoLootRolls.PLACE = "The Deadmines"
-- How long the roll to choose on runs, in seconds.
DemoLootRolls.TIME = 60

-- The newest drop as a roll to choose on: buttons that only move it down,
-- and a timer of TIME seconds from now.
local function choosable(view)
	local started = Compat.GetTime()
	view.item = { canNeed = true, canGreed = true, canTransmog = false }
	view.choosable = true
	view.timeShare = function()
		local share = 1 - (Compat.GetTime() - started) / DemoLootRolls.TIME
		return share > 0 and share or nil
	end
	local function done()
		if view.choosable then
			view.choosable = nil
			ns.Rolls.LiveWindow.Redraw()
		end
	end
	view.onChoose = done
	Compat.After(DemoLootRolls.TIME, done)
	return view
end

-- The made-up drops' views, the newest first; choosing: the newest is a
-- roll to choose on.
function DemoLootRolls.Views(items, now, choosing)
	local heroes = ns.Rolls.Demo.Heroes()
	local five = {}
	for index = 1, math.min(5, #heroes) do
		five[index] = heroes[index]
	end
	local needy = { [five[1].guid] = true }
	local next = (function()
		local value = 11
		return function(n)
			value = (value * 1103515245 + 12345) % 2147483648
			return math.floor(value / 65536) % n + 1
		end
	end)()
	local group = { id = "demo-lootrolls", started = now - 900, drops = {} }
	for index = 1, 4 do
		local item = items[((index - 1) % #items) + 1]
		group.drops[index] = DemoHistory.NewDrop("lootrolls:" .. index, now - (5 - index) * 120, DemoLootRolls.PLACE, item, five,
			index == 1 and {} or needy, next)
	end
	-- The oldest: all passed.
	local oldest = group.drops[1]
	for _, player in ipairs(oldest.rolls) do
		player.state, player.roll = STATE.PASS, nil
	end
	oldest.winner, oldest.allPassed = nil, true
	-- The newest: still rolled on, two heroes yet to choose.
	local newest = group.drops[4]
	newest.winner, newest.allPassed = nil, nil
	for index = 4, #newest.rolls do
		newest.rolls[index].state, newest.rolls[index].roll = STATE.NONE, nil
	end
	local stand = DemoHistory.StandIn({ group })
	local views = {}
	for index = #group.drops, 1, -1 do
		local view = DropRow.EntryView(group.drops[index], group)
		views[#views + 1] = DropRow.Marked(view, group, stand)
	end
	if choosing then
		choosable(views[1])
	end
	return views
end

function DemoLootRolls.Open()
	local window = ns.Rolls.LiveWindow
	local rolls = ns.Modules:Get("Rolls")
	if not (rolls and rolls:IsActive()) then
		ns.Print("demo lootrolls: the loot rolls are off")
		return false
	end
	return DemoHistory.WithItems("lootrolls", function(items)
		return window.ShowViews(DemoLootRolls.Views(items, Compat.GetServerTime(), ns.Storage:Get("Rolls", "hideGameFrames") == true))
	end)
end

ns.Slash.RegisterDemo("lootrolls", DemoLootRolls.Open, "/ltm demo lootrolls: the Loot Rolls window on made-up drops")
