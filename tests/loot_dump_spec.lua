local Loader = require("tests.helpers.loader")

-- The dev-only loot dump, used in game to see whether loot values are secret.
describe("loot dump (debug builds)", function()
	local ns, Test

	local function output()
		return table.concat(Test.state.printed, "\n")
	end

	before_each(function()
		ns = Loader.LoadAddon({ debug = true })
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.SetLoot({
			{ kind = "item", name = "Linen Cloth", quantity = 2, quality = 1, link = "[Linen Cloth]", locked = false, isQuestItem = false },
			{ kind = "money", name = "15 Silver", quantity = { secret = true } },
			{ kind = "item", name = "Bone" },
		})
		Test.ClearLootSlot(3)
		Test.state.printed = {}
	end)

	it("prints the loot window and the events, showing secret values as <secret>", function()
		ns.Storage:SetGlobal("debug", true)
		Test.Advance(1.5)
		Test.FireEvent("LOOT_READY", true)
		Test.FireEvent("LOOT_SLOT_CLEARED", { secret = true })
		local text = output()
		assert.matches("1%.50 LOOT_READY%(true%)", text)
		assert.matches("Loot window: 3 slots; in combat false, fishing false, auto loot true", text)
		assert.matches("slot 1: kind=item name=Linen Cloth quantity=2 quality=1 currencyID=nil locked=false isQuestItem=false link=%[Linen Cloth%]", text)
		assert.matches("slot 2: kind=money name=15 Silver quantity=<secret>", text)
		assert.matches("slot 3: empty", text)
		assert.matches("LOOT_SLOT_CLEARED%(<secret>%)", text)
	end)

	it("prints nothing while debug messages are off", function()
		Test.FireEvent("LOOT_READY", true)
		Test.FireEvent("LOOT_CLOSED")
		assert.same({}, Test.state.printed)
	end)
end)
