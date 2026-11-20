local Loader = require("tests.helpers.loader")

-- The loot rolls' demo (Modules/Rolls/Demo.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"
local RING = "|cff0070dd|Hitem:200::::::::40|h[Ring]|h|r"

describe("the loot rolls' demo", function()
	local ns, Test, Demo

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass" })
		Test.SetItems({
			[100] = { name = "Mail Helm", link = HELM, quality = 2, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", icon = 1, stats = {} },
			[200] = { name = "Ring", link = RING, quality = 3, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", icon = 2, stats = {} },
		})
		Test.state.worn = { [1] = HELM, [11] = RING }
		Test.SetUnits({ player = { name = "Tester", class = "WARRIOR", level = 30, guid = Test.state.playerGUID } })
		Loader.Start(ns)
		Demo = ns.Rolls.Demo
	end)

	local function names(card)
		local list = {}
		for _, player in ipairs(card.view.players) do
			list[#list + 1] = player.name
		end
		return list
	end

	it("plays a group roll and a raid roll beside look-alikes of the game's roll frame, with heroes of Azeroth, no group needed", function()
		assert.is_true(Demo.Start())
		local group, raid = Demo.cards[1], Demo.cards[2]
		assert.same({ true, true, "Demo" }, { group.frame:IsShown(), group.panel.frame:IsShown(), group.frame.label:GetText() })
		assert.same({ "Mail Helm", "Ring" }, { group.frame.name:GetText(), raid.frame.name:GetText() })
		assert.equals(5, #group.view.players)
		assert.same({ "Tester", true }, { group.view.players[1].name, group.view.players[1].isSelf })
		-- Heroes of Azeroth, each with the class of his stories.
		local heroes = {}
		for _, hero in ipairs(Demo.HEROES) do
			heroes[hero[1]] = hero[2]
		end
		for index = 2, 5 do
			local player = group.view.players[index]
			assert.equals(heroes[player.name], player.class, player.name)
		end
		assert.equals("SHAMAN", heroes.Thrall)
		assert.equals(20, #raid.view.players)
		-- Twenty different heroes, of the nine classes of WoW Forever only.
		local seen = {}
		for _, player in ipairs(raid.view.players) do
			assert.is_nil(seen[player.name], player.name)
			seen[player.name] = true
			assert.equals(heroes[player.name], player.class)
		end
		assert.is_false(Test.state.group)
		-- The classes are the client's.
		local known = {}
		for _, class in ipairs(ns.Data.rolls.classes) do
			known[class[1]] = true
		end
		for _, player in ipairs(raid.view.players) do
			assert.is_true(known[player.class], player.class)
		end
		assert.same({ "Tester" }, { names(group)[1] })
	end)

	it("goes on step by step to a winner, then goes away", function()
		Demo.Start()
		local group = Demo.cards[1]
		Test.Advance(Demo.STEP)
		local chosen = 0
		for _, player in ipairs(group.view.players) do
			if player.state ~= 4 then
				chosen = chosen + 1
			end
		end
		assert.is_true(chosen >= 1)
		Test.Advance(Demo.LENGTH - Demo.STEP)
		assert.is_table(group.view.winner)
		assert.is_true(group.view.winner.isWinner)
		Test.Advance(3 * Demo.STEP)
		assert.is_false(group.frame:IsShown())
		assert.is_false(group.panel.frame:IsShown())
	end)

	it("marks the player's choice only on the look-alike: nothing goes to the game or the history", function()
		Test.SetGroup(true)
		Demo.Start()
		local group = Demo.cards[1]
		group.buttons[3].scripts.OnClick(group.buttons[3])
		assert.equals(0, group.view.players[1].state)
		-- No real roll comes of it.
		assert.same({}, ns.Rolls.Model.Rolls())
		local open = ns.Rolls.History.Open()
		assert.is_true(open == nil or #open.drops == 0)
	end)

	it("uses the data's items with nothing worn", function()
		Test.state.worn = {}
		Test.SetItems({ [12640] = { name = "Lionheart Helm", link = "|Hitem:12640|h[Lionheart Helm]|h", quality = 4, classID = 4, subclassID = 4 } })
		Demo.Start()
		assert.equals("Lionheart Helm", Demo.cards[1].frame.name:GetText())
		-- The others are asked for.
		assert.same({ 14152, 19019 }, Test.state.requested)
	end)

	it("waits until real rolls are over, and starts out of combat only", function()
		Test.StartRoll(7, { name = "Mail Helm", link = HELM })
		assert.is_false((Demo.Start()))
		assert.matches("rolls in progress", Test.state.printed[#Test.state.printed])
		Test.CancelRoll(7)
		Test.SetCombat(true)
		assert.is_false((Demo.Start()))
		assert.matches("out of combat", Test.state.printed[#Test.state.printed])
		Test.SetCombat(false)
		assert.is_true((Demo.Start()))
	end)

	it("starts from the button on the options page and stops when the module is turned off", function()
		Demo.Start()
		ns.Modules:SetEnabled("Rolls", false)
		assert.is_false(Demo.cards[1].frame:IsShown())
		local labels = {}
		for _, setting in ipairs(ns.Modules:Get("Rolls").mainSettings) do
			labels[#labels + 1] = setting.label or setting.kind
		end
		assert.same({ "custom", "Show Demo" }, labels)
	end)
end)
