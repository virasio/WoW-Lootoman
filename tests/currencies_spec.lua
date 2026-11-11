local Loader = require("tests.helpers.loader")

describe("Currencies provider", function()
	local ns, Currencies, Test

	before_each(function()
		ns = Loader.Start(Loader.LoadAddon({ skip = { "Settings/", "Modules/" } }))
		Currencies, Test = ns.Currencies, ns.Compat.Test
		Test.SetCurrency(3008, { name = "Valorstones", quantity = 500, max = 2000 })
		Test.SetCurrency(3110, { name = "Gilded Crest", quantity = 20, max = 90, totalEarned = 90, capsTotalEarned = true, backpack = 2 })
		Test.SetCurrency(2815, { name = "Resonance Crystals", quantity = 4000, backpack = 1 })
	end)

	it("tell when a currency is at its cap, a seasonal cap by what was earned", function()
		assert.same({ false, true, false }, { Currencies.Info(3008).atCap, Currencies.Info(3110).atCap, Currencies.Info(2815).atCap })
		Test.SetCurrency(3008, { name = "Valorstones", quantity = 2000, max = 2000 })
		assert.is_true(Currencies.Info(3008).atCap)
		assert.is_nil(Currencies.Info(1))
	end)

	it("list the character's currencies and the backpack's in order", function()
		assert.same({ 2815, 3008, 3110 }, Currencies.IDs())
		assert.same({ 2815, 3110 }, Currencies.Backpack())
	end)

	it("count items in the bags, the banks or both", function()
		Test.SetBags({ [0] = { size = 4, items = { [1] = { itemID = 2589, count = 5 }, [3] = { itemID = 2589, count = 2 } } } })
		Test.SetItems({ [2589] = { name = "Linen Cloth", bank = 30, warband = 100 } })
		Test.state.capabilities["Enum.BankType.Account"] = true
		assert.same({ 7, 7, 130, 137 }, { Currencies.ItemCount(2589), Currencies.ItemCount(2589, "bags"),
			Currencies.ItemCount(2589, "banks"), Currencies.ItemCount(2589, "all") })
		assert.same({ bags = 7, bank = 30, warband = 100 }, Currencies.ItemCounts(2589))
		-- A client without a warband bank.
		Test.state.capabilities["Enum.BankType.Account"] = nil
		assert.same({ 30, 37 }, { Currencies.ItemCount(2589, "banks"), Currencies.ItemCount(2589, "all") })
	end)

	it("say when a currency changes, once watched", function()
		local changed = {}
		ns.Bus:On("CurrenciesChanged", "test", function(_, id) changed[#changed + 1] = id end)
		Test.ChangeCurrency(3008, 10)
		Currencies.Watch()
		Test.ChangeCurrency(3008, 10)
		assert.same({ 3008 }, changed)
	end)
end)
