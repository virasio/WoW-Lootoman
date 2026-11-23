local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The made-up roll history and the Suspicious Needs window on it, in the
-- repository's version (Dev/DemoRollHistory.lua, Dev/DemoExceptions.lua).

local function link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::40|h[%s]|h|r"):format(color or "0070dd", id, name)
end

local ITEMS = {
	[5191] = { name = "Cruel Barb", link = link(5191, "Cruel Barb"), quality = 3, classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON", bindType = 1, stats = {} },
	[6460] = { name = "Cobrahn's Grasp", link = link(6460, "Cobrahn's Grasp"), quality = 3, classID = 4, subclassID = 3, equipLoc = "INVTYPE_WAIST", bindType = 1, stats = {} },
	[17075] = { name = "Vis'kag the Bloodletter", link = link(17075, "Vis'kag the Bloodletter", "a335ee"), quality = 4, classID = 2, subclassID = 7,
		equipLoc = "INVTYPE_WEAPON", bindType = 1, stats = {} },
}

describe("the made-up roll history", function()
	local ns, Test, Window, settings

	before_each(function()
		settings = SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = "camelot", skip = {}, debug = true })
		Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass" })
		Test.SetItems(ITEMS)
		Test.SetUnits({ player = { name = "Tester", class = "WARRIOR", level = 60, guid = Test.state.playerGUID } })
		Loader.Start(ns)
		Window = ns.Rolls.HistoryWindow
	end)

	local function open(argument)
		Test.RunSlashCommand("LOOTOMAN", "demo rollhistory" .. (argument and (" " .. argument) or ""))
		-- The items it lacks are asked for, and it waits for them a few times.
		for _ = 1, ns.Rolls.DemoHistory.TRIES do
			Test.Advance(ns.Rolls.DemoHistory.WAIT)
		end
		return Window.Frame()
	end

	it("opens the window on two runs of the dungeon's five and a raid of forty, you as Player, with the items the client has, never saved", function()
		local frame = open()
		assert.same({ true, "Roll History (Demo)" }, { frame:IsShown(), frame.title })
		assert.is_true(#Test.state.requested > 0)
		local groups = ns.Rolls.DemoHistory.history.Groups()
		assert.same({ 3, 6, 5, 5, 5, 40 }, { #groups, #groups[1].drops, #groups[2].drops, #groups[3].drops, #groups[1].drops[1].rolls,
			#groups[3].drops[1].rolls })
		local names = {}
		for index, player in ipairs(groups[2].drops[1].rolls) do
			names[index] = player.name
		end
		assert.same({ "Varian", "Tyrande", "Jaina", "Shaw", "Player" }, names)
		local passing = 0
		for _, group in ipairs(groups) do
			for _, entry in ipairs(group.drops) do
				assert.is_truthy(ITEMS[tonumber(entry.link:match("item:(%d+)"))])
				for _, player in ipairs(entry.rolls) do
					assert.is_nil(player.name:find("Tester", 1, true))
					if player.name:match("^Test%d+$") then
						passing = passing + 1
						assert.equals(5, player.state)
					end
				end
			end
		end
		assert.equals(26 * 5, passing)
		-- Newest first: the raid.
		assert.equals(groups[3], frame.group)
		-- Player's line is the character's own.
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		assert.is_true(frame.dropRows[1].panel.lines[5].self:IsShown())
		assert.same({}, ns.Rolls.History.Groups())
		assert.is_nil(Test.state.saved.LootomanCharDB.sections.rollHistory and Test.state.saved.LootomanCharDB.sections.rollHistory.groups[1])
		-- The real history again, without a title of its own.
		Window.Open()
		assert.same({ "Roll History", true }, { frame.title, frame.empty:IsShown() })
	end)

	it("marks Shaw for needing everything, and the mark comes back in the second run", function()
		ns.Storage:Set("Rolls", "ninja", true)
		local frame = open()
		frame.groupButtons[2].scripts.OnClick(frame.groupButtons[2], "LeftButton")
		local line = frame.dropRows[1].panel.lines[4]
		assert.equals("Shaw", line.player.name)
		assert.is_truthy(line.text:GetText():find("RaidTargetingIcon", 1, true))
		line.scripts.OnEnter(line)
		local said = table.concat(Loader.ui.tooltip.lines, "\n")
		assert.matches("Last time", said)
		-- The exception in the first run is ticked.
		frame.groupButtons[3].scripts.OnClick(frame.groupButtons[3], "LeftButton")
		assert.is_true(frame.dropRows[2].checks[1]:GetChecked())
	end)

	it("keeps exceptions and deletions to itself", function()
		ns.Storage:Set("Rolls", "ninja", true)
		local frame = open()
		local groups = ns.Rolls.DemoHistory.history.Groups()
		frame.groupButtons[3].scripts.OnClick(frame.groupButtons[3], "LeftButton")
		local check = frame.dropRows[2].checks[1]
		check:SetChecked(false)
		check.scripts.OnClick(check)
		assert.is_nil(groups[1].drops[2].rolls[4].excused)
		frame.clear.scripts.OnClick(frame.clear)
		settings.popups[#settings.popups].data.callback()
		assert.same({}, groups)
		assert.same({}, ns.Rolls.History.Groups())
	end)

	it("fills up to the history's limits, full, drawn with a pool of rows no bigger than what shows", function()
		local frame = open("full")
		local groups = ns.Rolls.DemoHistory.history.Groups()
		local drops = 0
		for _, group in ipairs(groups) do
			drops = drops + #group.drops
		end
		assert.same({ ns.Rolls.History.MAX_GROUPS, ns.Rolls.History.MAX_DROPS }, { #groups, drops })
		local most = 0
		for _, button in ipairs(frame.groupButtons) do
			button.scripts.OnClick(button, "LeftButton")
			most = math.max(most, frame.dropCount)
		end
		assert.equals(most, #frame.dropRows)
		assert.equals(ns.Rolls.History.MAX_GROUPS, #frame.groupButtons)
	end)

	describe("the Suspicious Needs window on it", function()
		local function exceptions(kind)
			Test.state.printed = {}
			Test.RunSlashCommand("LOOTOMAN", "demo exceptions " .. kind)
			for _ = 1, ns.Rolls.DemoHistory.TRIES do
				Test.Advance(ns.Rolls.DemoHistory.WAIT)
			end
			return ns.Rolls.SuspiciousNeeds.Frame()
		end

		it("lists the dungeon run's marked needs, Shaw's, one excused already; a tick touches only the made-up group", function()
			ns.Storage:Set("Rolls", "ninja", true)
			local frame = exceptions("dung")
			assert.is_true(frame:IsShown())
			assert.is_true(frame.count >= 2)
			local excused = 0
			for index = 1, frame.count do
				local row = frame.rows[index]
				assert.matches("Shaw", row.who:GetText())
				excused = excused + (row.exception:GetChecked() and 1 or 0)
			end
			assert.equals(1, excused)
			local group = ns.Rolls.DemoExceptions.group
			local row = frame.rows[1]
			row.exception:SetChecked(not row.exception:GetChecked())
			row.exception.scripts.OnClick(row.exception)
			local ticked = 0
			for _, entry in ipairs(group.drops) do
				for _, player in ipairs(entry.rolls) do
					ticked = ticked + (player.excused and 1 or 0)
				end
			end
			assert.is_true(ticked ~= 1)
			assert.same({}, ns.Rolls.History.Groups())
		end)

		it("lists the raid's three who need everything", function()
			ns.Storage:Set("Rolls", "ninja", true)
			local frame = exceptions("raid")
			local who = {}
			for index = 1, frame.count do
				who[frame.rows[index].who:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")] = true
			end
			assert.same({ ["Gul'dan"] = true, Rexxar = true, Jaina = true }, who)
		end)

		it("says so with the detection off, and gives its lines alone", function()
			assert.is_nil(exceptions("dung"))
			assert.equals("demo exceptions: its marks need Detect Ninja Looters on.", Test.state.printed[1]:gsub("^|cff%x+Lootoman|r: ", ""))
			exceptions("")
			assert.matches("^/ltm demo exceptions dung", (Test.state.printed[1]:gsub("^|cff%x+Lootoman|r: ", "")))
		end)
	end)
end)
