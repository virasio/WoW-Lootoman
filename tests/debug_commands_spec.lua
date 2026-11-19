local Loader = require("tests.helpers.loader")

-- The printed lines of a client without the chat prefix.
local function lines(Test)
	local found = {}
	for _, line in ipairs(Test.state.printed) do
		found[#found + 1] = (line:gsub("^|cff%x+Lootoman|r: ", ""))
	end
	return found
end

describe("debug junk", function()
	local ns, Test

	local function run(text)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug junk " .. text)
		return lines(Test)
	end

	before_each(function()
		rawset(_G, "Auctionator", nil)
		ns = Loader.Start(Loader.LoadAddon())
		Test = ns.Compat.Test
		Test.SetItems({
			[1] = { name = "Broken Tooth", link = "|cff9d9d9d|Hitem:1::|h[Broken Tooth]|h|r", quality = 0, sellPrice = 7 },
			[3] = { name = "Linen Cloth", link = "|cffffffff|Hitem:3::|h[Linen Cloth]|h|r", quality = 1, sellPrice = 13 },
			[4] = { name = "Sword", link = "|cff1eff00|Hitem:4::|h[Sword]|h|r", quality = 2, sellPrice = 5000, equippable = true,
				usable = false, requiredLevel = 10 },
		})
		Test.SetBags({ [0] = { size = 4, items = {
			[1] = { itemID = 1, link = "item:1", name = "Broken Tooth", quality = 0, count = 3 },
			[2] = { itemID = 4, link = "item:4", name = "Sword", quality = 2, count = 1, bound = true },
		} } })
		Test.state.playerLevel = 40
	end)

	it("tells a gray item in the bags: junk, its stacks and prices, no suggestion", function()
		assert.same({
			"debug junk: |cff9d9d9d|Hitem:1::|h[Broken Tooth]|h|r (item 1), quality 0",
			"  Junk: yes, gray; mark none",
			"  In the bags: bag 0 slot 1 ×3",
			"  Suggested: no; a quest in the log wants it: no",
			"  Usable now: no",
			"  Prices, copper: merchant 21, auction none, worth 21",
		}, run("|cff9d9d9d|Hitem:1::|h[Broken Tooth]|h|r"))
	end)

	it("tells a marked item that is not in the bags", function()
		ns.Marks.Set(3, "notJunk")
		local shown = run("3")
		assert.same({ "  Junk: no, marked not junk; mark notJunk", "  In the bags: no; suggestions look only at what the bags hold",
			"  Prices, copper: merchant 13, auction none, worth 13" }, { shown[2], shown[3], shown[5] })
	end)

	it("tells the suggestion rule of an item the rules suggest, also with junk management off", function()
		ns.Modules:SetEnabled("Junk", false)
		local shown = run("item:4")
		assert.same({ "  Junk: no; mark none", "  Suggested: unusable; a quest in the log wants it: no" }, { shown[2], shown[4] })
	end)

	it("asks for an unknown item, and says what it takes without one", function()
		assert.same({ "debug junk: item 4000 is not loaded yet; try again in a moment." }, run("4000"))
		assert.same({ 4000 }, Test.state.requested)
		assert.same({ "/ltm debug junk takes an item's link or ID." }, run("something"))
	end)
end)

describe("debug bags", function()
	it("lists each bag, the totals of each kind, the look's thresholds and its warning's text", function()
		local ns = Loader.Start(Loader.LoadAddon())
		local Test = ns.Compat.Test
		Test.state.playerBags, Test.state.reagentBag = { 0, 1 }, 5
		Test.SetBags({
			[0] = { size = 16, items = { [1] = { itemID = 1, count = 1 } } },
			[1] = { size = 4, family = 8, items = {} },
			[5] = { size = 2, items = { [1] = { itemID = 2, count = 1 }, [2] = { itemID = 3, count = 1 } } },
		})
		ns.Bus:Send("InventoryChanged")
		ns.Modules:Get("LootFeed"):Set("warnReagent", true)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug bags")
		assert.same({
			"debug bags: bag 0, general, family 0: 15 of 16 free",
			"debug bags: bag 1, profession, family 8: 4 of 4 free",
			"debug bags: bag 5, reagent, family 0: 0 of 2 free",
			"  All: 19 of 22 free (3 used); general 15 of 16; reagent 0 of 2; profession 4 of 4",
			"  Look “Default”: all bags off at 5; general on at 3; reagent on at 2, reached",
			"  Warning text: |cffffffff15|r|cffffffff+|r|cff1eff000|r",
		}, lines(Test))
	end)
end)

describe("debug target", function()
	it("is only where the highlights are, and tells the target's kind, why it lights and the game settings", function()
		local retail = Loader.Start(Loader.LoadAddon())
		retail.Compat.Test.RunSlashCommand("LOOTOMAN", "debug target")
		assert.equals("Debug commands:", lines(retail.Compat.Test)[1])

		local ns = Loader.LoadAddon({ gameType = "camelot" })
		local Test = ns.Compat.Test
		Test.state.cursorFiles = { GatherHerbs = 3, UnableGatherHerbs = 4 }
		Test.state.gatheringSkills = { herbs = false, ore = false }
		Test.state.consoleVars = { SoftTargetInteract = "0" }
		Loader.Start(ns)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug target")
		assert.equals("debug target: no soft target.", lines(Test)[1])
		Test.state.softInteract = { isObject = true, isDead = false, cursor = 3, inReach = true, name = "Peacebloom", objectID = 1617 }
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug target")
		local shown = lines(Test)
		assert.same({ "debug target: Peacebloom (object 1617, cursor 3); living false, dead false, in reach true; quest related nil, objective nil",
			"  Kind: herbs, not lit: no profession" }, { shown[1], shown[2] })
		assert.matches("^  Game settings: SoftTargetInteract=3 %(held%), SoftTargetInteractRange=", shown[3])
		ns.Modules:Get("Highlights"):Set("gatherable", false)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "debug target")
		assert.equals("  Kind: herbs: sparkles, ready", lines(Test)[2])
	end)
end)
