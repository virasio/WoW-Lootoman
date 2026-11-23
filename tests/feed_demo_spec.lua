local Loader = require("tests.helpers.loader")
local Formats = require("tests.fixtures.globalstrings")

local LINEN = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r"
local RAG = "|cff9d9d9d|Hitem:700::|h[Rag, Torn]|h|r"

describe("made-up loot in the feed, in the repository's version", function()
	local ns, Test, module

	local function run(text)
		Test.RunSlashCommand("LOOTOMAN", "demo loot " .. text)
	end

	-- The printed lines without the chat prefix.
	local function lines()
		local found = {}
		for _, line in ipairs(Test.state.printed) do
			found[#found + 1] = (line:gsub("^|cff%x+Lootoman|r: ", ""))
		end
		return found
	end

	-- The rows of the model, oldest first, as "kind name amount".
	local function rows()
		local found = {}
		for index = #module.model.rows, 1, -1 do
			local row = module.model.rows[index]
			found[#found + 1] = ("%s %s %s"):format(row.kind, tostring(row.name), tostring(row.amount))
		end
		return found
	end

	before_each(function()
		ns = Loader.LoadAddon({ debug = true })
		Test = ns.Compat.Test
		Test.SetGlobalStrings(Formats.enUS)
		Test.SetItems({
			[2589] = { name = "Linen Cloth", link = LINEN, icon = 132889, quality = 1, stackSize = 200 },
			[700] = { name = "Rag, Torn", link = RAG, icon = 1, quality = 0 },
		})
		Test.state.currencies[1220] = { name = "Order Resources", icon = 7, quality = 1, quantity = 100, discovered = true }
		Loader.Start(ns)
		module = ns.Modules:Get("LootFeed")
		module:Set("xp", true)
		module:Set("stagger", 0)
	end)

	it("without pieces says which it takes", function()
		run("")
		local text = table.concat(lines(), "\n")
		assert.equals("/ltm demo loot takes pieces split by spaces:", lines()[1])
		for _, piece in ipairs({ "2589x5", "currency%[1220%]%+50", "exp%+2000", "rep%[\"Stormwind\"%]%+200", "gold%+0%.0015" }) do
			assert.matches(piece, text)
		end
		assert.same({}, module.model.rows)
	end)

	it("puts each piece into the feed as real loot: items, counts, links, currency, experience, reputation, money", function()
		run("2589  2589x4 " .. LINEN .. " x2 currency[1220]+50 exp+2000 rep[\"Stormwind\"]+200 REP['Ironforge']-25 gold+0.0015")
		-- The three Linen Cloth merge into one row, as looted items do.
		assert.same({ "item Linen Cloth 7", "currency Order Resources 50", "xp nil 2000", "reputation Stormwind 200",
			"reputation Ironforge -25", "money nil 15" }, rows())
		assert.equals(150, module.model.rows[5].total)
		assert.same({}, lines())
	end)

	it("keeps a link whose name holds a space whole, and junk goes into its row", function()
		run(RAG .. "x3 2589")
		local junk = module.model.rows[2]
		assert.same({ "Junk", 3, 700 }, { junk.name, junk.amount, junk.parts and junk.parts[1].key })
		assert.equals("item Linen Cloth 1", rows()[2])
	end)

	it("keeps a faction's name with spaces whole, and takes a count after a space", function()
		run("rep[\"Steamwheedle Cartel\"]+75 2589 x3")
		assert.same({ "reputation Steamwheedle Cartel 75", "item Linen Cloth 3" }, rows())
		assert.same({}, lines())
	end)

	it("names a piece it cannot read and goes on with the others", function()
		run("dance 2589x0 currency[9]+5 gold+0.00001 exp+2000")
		assert.same({
			"demo loot: cannot read “dance”: not a piece the command knows.",
			"demo loot: cannot read “2589x0”: a count of at least 1.",
			"demo loot: cannot read “currency[9]+5”: no currency 9.",
			"demo loot: cannot read “gold+0.00001”: less than a copper.",
		}, lines())
		assert.same({ "xp nil 2000" }, rows())
	end)

	it("asks for an item the client has not loaded, and shows it when it comes", function()
		run("4000x2 4000")
		assert.same({ { 4000 }, {} }, { Test.state.requested, module.model.rows })
		Test.state.items[4000] = { name = "Silk Cloth", link = "|cffffffff|Hitem:4000::|h[Silk Cloth]|h|r", icon = 5, quality = 1 }
		Test.FireEvent("ITEM_DATA_LOAD_RESULT", 4000, true)
		assert.same({ "item Silk Cloth 3" }, rows())
		assert.is_false(Test.IsRegistered("ITEM_DATA_LOAD_RESULT"))
		Test.Advance(ns.Feed.Demo.LOAD_TIME)
		assert.same({}, lines())
	end)

	it("names an item that does not exist, and one that does not load in time", function()
		run("4001 4002")
		Test.FireEvent("ITEM_DATA_LOAD_RESULT", 4001, false)
		assert.same({ "demo loot: item 4001 does not exist." }, lines())
		Test.Advance(ns.Feed.Demo.LOAD_TIME)
		assert.same({ "demo loot: item 4001 does not exist.", "demo loot: item 4002 did not load in 5 seconds." }, lines())
		assert.same({}, rows())
		assert.is_false(Test.IsRegistered("ITEM_DATA_LOAD_RESULT"))
	end)

	it("says so while the loot feed is off", function()
		ns.Modules:SetEnabled("LootFeed", false)
		run("2589")
		assert.same({ "demo loot: the loot feed is off." }, lines())
	end)
end)
