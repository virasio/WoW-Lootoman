local Loader = require("tests.helpers.loader")

-- The loot rolls' demo (Modules/Rolls/Demo.lua).

local HELM = "|cff1eff00|Hitem:100::::::::40|h[Mail Helm]|h|r"
local RING = "|cff0070dd|Hitem:200::::::::40|h[Ring]|h|r"
local DAGGER = "|cff0070dd|Hitem:5616::::::::40|h[Gutwrencher]|h|r"
local STAFF = "|cffa335ee|Hitem:812::::::::60|h[Glowing Brightwood Staff]|h|r"

describe("the loot rolls' demo", function()
	local ns, Test, Demo

	before_each(function()
		ns = Loader.LoadAddon({ gameType = "camelot" })
		Test = ns.Compat.Test
		Test.SetGlobalStrings({ NEED = "Need", GREED = "Greed", PASS = "Pass" })
		Test.SetItems({
			[100] = { name = "Mail Helm", link = HELM, quality = 2, classID = 4, subclassID = 3, equipLoc = "INVTYPE_HEAD", icon = 1, stats = {} },
			[200] = { name = "Ring", link = RING, quality = 3, classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER", icon = 2, stats = {} },
			[5616] = { name = "Gutwrencher", link = DAGGER, quality = 3, classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", icon = 3,
				bindType = 2, stats = { ITEM_MOD_AGILITY_SHORT = 5 } },
			[812] = { name = "Glowing Brightwood Staff", link = STAFF, quality = 4, classID = 2, subclassID = 10, equipLoc = "INVTYPE_2HWEAPON",
				icon = 4, stats = { ITEM_MOD_INTELLECT_SHORT = 29 } },
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
		assert.same({ true, true }, { group.frame:IsShown(), group.panel.frame:IsShown() })
		-- Drawn as the game draws its roll frame: no label of its own; the loot
		-- toast's border, the icon in its quality's border, the name in its colour.
		assert.is_nil(group.frame.label)
		assert.same({ 286, 76 }, { group.frame.border.width, group.frame.border.height })
		assert.same({ "loottoast-itemborder-3", "loottoast-itemborder-4" }, { group.frame.iconBorder.atlas, raid.frame.iconBorder.atlas })
		assert.same({ 0, 0.44, 0.87 }, group.frame.name.color)
		assert.same({ 0.64, 0.21, 0.93 }, raid.frame.name.color)
		assert.same({ "TOPRIGHT", group.frame, "TOPRIGHT", -44, -6 }, group.buttons[3].points[1])
		-- A blue dagger for the group, a purple staff for the raid.
		assert.same({ "Gutwrencher", "Glowing Brightwood Staff" }, { group.frame.name:GetText(), raid.frame.name:GetText() })
		assert.equals(5, #group.view.players)
		-- The player's own line stands under a hero's name too: no real character in the pictures.
		assert.is_true(group.view.players[1].isSelf)
		for _, card in ipairs({ group, raid }) do
			for _, player in ipairs(card.view.players) do
				assert.not_equals("Tester", player.name)
				assert.not_equals(Test.state.playerGUID, player.guid)
			end
		end
		-- Heroes of Azeroth, each with the class of his stories.
		local heroes = {}
		for _, hero in ipairs(Demo.HEROES) do
			heroes[hero[1]] = hero[2]
		end
		for index = 1, 5 do
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
		assert.equals(5, #names(group))
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

	it("waits a moment for an item the game has not loaded, then takes worn gear in its place", function()
		Test.state.items[5616] = nil
		assert.is_true(Demo.Start())
		assert.is_nil(Demo.cards[1])
		assert.same({ 5616 }, { Test.state.requested[1] })
		Test.Advance(Demo.WAIT * Demo.TRIES)
		assert.same({ "Mail Helm", "Glowing Brightwood Staff" }, { Demo.cards[1].frame.name:GetText(), Demo.cards[2].frame.name:GetText() })
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

	it("stops when the module is turned off, and has no place on the options page", function()
		Demo.Start()
		ns.Modules:SetEnabled("Rolls", false)
		assert.is_false(Demo.cards[1].frame:IsShown())
		local kinds = {}
		for _, setting in ipairs(ns.Modules:Get("Rolls").mainSettings) do
			kinds[#kinds + 1] = setting.label or setting.kind
		end
		assert.same({ "custom" }, kinds)
	end)
end)
