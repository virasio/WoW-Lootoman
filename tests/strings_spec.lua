local Strings = require("tests.helpers.strings")

describe("Strings.Placeholders", function()
	it("lists specifiers by position", function()
		assert.same({ "1:d", "2:s" }, Strings.Placeholders("Sold %d items for %s"))
	end)

	it("accepts reordered positional specifiers", function()
		assert.same({ "1:d", "2:s" }, Strings.Placeholders("%2$s: продано %1$d"))
	end)

	it("reads flags, width and precision", function()
		assert.same({ "1:f", "2:d" }, Strings.Placeholders("%5.2f gold, %-3d items"))
	end)

	it("ignores %%", function()
		assert.same({}, Strings.Placeholders("100%% done"))
	end)

	it("tells swapped types apart", function()
		assert.are_not.same(Strings.Placeholders("%s: %d"), Strings.Placeholders("%d: %s"))
	end)
end)

describe("Strings.FindKeys", function()
	it("finds literal keys in both quote styles", function()
		local keys, nonLiteral = Strings.FindKeys([[print(L["Sell junk"] .. L['Keep'])]])
		assert.same({ "Sell junk", "Keep" }, keys)
		assert.equals(0, nonLiteral)
	end)

	it("finds ns.L keys", function()
		assert.same({ "Repair" }, (Strings.FindKeys([[text = ns.L[ "Repair" ] ]])))
	end)

	it("counts keys that are not literals", function()
		local keys, nonLiteral = Strings.FindKeys([[text = L[key] .. L["a" .. b] ]])
		assert.same({}, keys)
		assert.equals(2, nonLiteral)
	end)

	it("ignores other names ending in L", function()
		assert.same({}, (Strings.FindKeys([[x = URL["a"] or myL["b"] ]])))
	end)
end)
