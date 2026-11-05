local Loader = require("tests.helpers.loader")

-- The dev-only command that prints bag family bits, to check them in game.
describe("bag families (debug builds)", function()
	local ns, Test

	local function output()
		return table.concat(Test.state.printed, "\n")
	end

	local function bag(subType, subClassID)
		return { type = "Container", subType = subType, classID = 1, subClassID = subClassID }
	end

	before_each(function()
		ns = Loader.LoadAddon({ debug = true })
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.SetItems({
			[22250] = { name = "Herb Pouch", kind = bag("Herb Bag", 2), family = 32 },
			-- Not loaded yet: no name, but its kind and family are known.
			[38347] = { kind = bag("Mining Bag", 6), family = 1024 },
			[30745] = { name = "Heavy Toolbox", kind = bag("Engineering Bag", 4), family = 64 },
			[22243] = { name = "Small Soul Pouch", kind = bag("Soul Bag", 1) },
			[12345] = { name = "Linen Bag", kind = bag("Bag", 0), family = 0 },
		})
		Test.SetBags({ [0] = { size = 16 }, [1] = { size = 12, family = 32 } })
		Test.state.printed = {}
	end)

	it("prints each bag's family next to the expected one, and the equipped bags", function()
		Test.RunSlashCommand("LOOTOMAN", "families 12345")
		local text = output()
		assert.matches("22250 Herb Pouch: Herb Pouch, Herb Bag %(class 1%.2%), family 32 %(0x20%), as expected", text)
		assert.matches("38347 Mammoth Mining Bag: %(not loaded yet: run the command again%), Mining Bag %(class 1%.6%), family 1024 %(0x400%), as expected", text)
		assert.matches("30745 Heavy Toolbox: Heavy Toolbox, Engineering Bag %(class 1%.4%), family 64 %(0x40%), EXPECTED 128 %(0x80%) for engineering", text)
		assert.matches("22243 Small Soul Pouch: Small Soul Pouch, Soul Bag %(class 1%.1%), family nil, family not known yet", text)
		assert.matches("22246 Enchanted Mageweave Pouch: no such item on this client", text)
		assert.matches("12345 %(asked for%): Linen Bag, Bag %(class 1%.0%), family 0 %(0x0%)\n", text .. "\n")
		assert.matches("Equipped bag 0: 16 slots, family 0 %(0x0%)", text)
		assert.matches("Equipped bag 1: 12 slots, family 32 %(0x20%)", text)
		assert.matches("2 as expected, 1 different%.", text)
		-- Kept for the saved variables, without the chat prefix.
		local saved = ns.Storage:GetSessionSection("bagFamilies")
		assert.same({ #Test.state.printed, "2 as expected, 1 different." }, { #saved.lines, saved.lines[#saved.lines] })
		assert.equals(ns.Compat.GetProjectID(), saved.project)
	end)

	it("is not there outside debug builds", function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "families")
		assert.not_matches("Bag families", output())
		assert.matches("Commands:", output())
	end)
end)
