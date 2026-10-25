local Loader = require("tests.helpers.loader")
local Formats = require("tests.fixtures.globalstrings")

local LINK = "|cffffffff|Hitem:2589::::::::80:::::|h[Linen Cloth]|h|r"

describe("Sources.ToPattern", function()
	local ToPattern

	before_each(function()
		ToPattern = Loader.LoadAddon().Feed.Sources.ToPattern
	end)

	it("turns a chat format into an anchored pattern with its argument order", function()
		assert.same({ "^You receive loot: (.+)x(%-?%d+)$", { 1, 2 }, {} }, { ToPattern("You receive loot: %sx%d") })
	end)

	it("escapes magic characters and reads numbers with decimals", function()
		local pattern = ToPattern("Reputation with %s increased by %d. (+%.1f bonus)")
		assert.equals("^Reputation with (.+) increased by (%-?%d+)%. %(%+(%-?[%d%.,]+) bonus%)$", pattern)
	end)

	it("keeps positional arguments in their order", function()
		assert.same({ "^(.+): (%-?%d+)$", { 2, 1 }, {} }, { ToPattern("%2$s: %1$d") })
	end)

	it("reads a declined word inside a Russian declension marker, and says so", function()
		assert.same({ "^Отношение (.+) к вам улучшилось на (%-?%d+)%.$", { 1, 2 }, { [1] = true } },
			{ ToPattern("Отношение |3-7(%s) к вам улучшилось на %d.") })
	end)
end)

describe("loot feed sources", function()
	local ns, Test, entries

	local function start(locale)
		Test.SetGlobalStrings(Formats[locale or "enUS"])
		entries = {}
		ns.Feed.Sources.Start("feed", function(entry) entries[#entries + 1] = entry end)
	end

	local function chat(event, text)
		Test.FireEvent(event, text, "Tester")
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test = ns.Compat.Test
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 132889, quality = 1, stackSize = 200 } })
	end)

	describe("items", function()
		it("come from the player's loot messages", function()
			start()
			chat("CHAT_MSG_LOOT", "You receive loot: " .. LINK .. "x2")
			chat("CHAT_MSG_LOOT", "You receive loot: " .. LINK)
			assert.same({
				{ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", icon = 132889, quality = 1, amount = 2 },
				{ kind = "item", id = 2589, link = LINK, name = "Linen Cloth", icon = 132889, quality = 1, amount = 1 },
			}, entries)
		end)

		it("also come from received, created and bonus roll items", function()
			start()
			chat("CHAT_MSG_LOOT", "You receive item: " .. LINK .. "x5")
			chat("CHAT_MSG_LOOT", "You create: " .. LINK .. "x3.")
			chat("CHAT_MSG_LOOT", "You receive bonus loot: " .. LINK)
			assert.same({ 5, 3, 1 }, { entries[1].amount, entries[2].amount, entries[3].amount })
		end)

		it("come from Russian messages", function()
			start("ruRU")
			chat("CHAT_MSG_LOOT", "Ваша добыча: " .. LINK .. "x2.")
			chat("CHAT_MSG_LOOT", "Вы получили предмет: " .. LINK .. ".")
			assert.same({ 2, 1 }, { entries[1].amount, entries[2].amount })
			assert.equals(2589, entries[2].id)
		end)

		it("leave other players' loot and messages that are not loot out", function()
			start()
			chat("CHAT_MSG_LOOT", "Ana receives loot: " .. LINK .. ".")
			chat("CHAT_MSG_LOOT", { secret = true })
			assert.same({}, entries)
			assert.same({}, Test.state.errors)
		end)

		it("keep an item the client has not loaded, with what its link tells", function()
			start()
			local link = "|cffa335ee|Hitem:12345::::::::80:::::|h[Unknown Blade]|h|r"
			chat("CHAT_MSG_LOOT", "You receive loot: " .. link)
			assert.same({ kind = "item", id = 12345, link = link, name = "Unknown Blade", amount = 1 }, entries[1])
		end)
	end)

	describe("reputation", function()
		it("comes from gains, losses and warband changes, with bonus text", function()
			start()
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 250.")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 250. (+25.0 bonus)")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your Warband's reputation with The Assembly of the Deeps increased by 75.")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Defias Brotherhood decreased by 10.")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Darnassus increased.")
			local results = {}
			for index, entry in ipairs(entries) do
				results[index] = entry.name .. " " .. tostring(entry.amount)
			end
			assert.same({ "Stormwind 250", "Stormwind 250", "The Assembly of the Deeps 75", "Defias Brotherhood -10", "Darnassus nil" }, results)
			assert.equals("reputation", entries[1].kind)
			assert.is_nil(entries[1].declined)
		end)

		it("comes from Russian messages, with the faction as the message declines it", function()
			start("ruRU")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Отношение Штормграда к вам улучшилось на 250.")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Отношение фракции \"Штормград\" к вам улучшилось.")
			chat("CHAT_MSG_COMBAT_FACTION_CHANGE", "Отношение Ассамблеи Глубин к вашему отряду ухудшилось на 5.")
			assert.same({ "Штормграда", 250, true }, { entries[1].name, entries[1].amount, entries[1].declined })
			assert.same({ "Штормград" }, { entries[2].name, entries[2].amount, entries[2].declined })
			assert.same({ "Ассамблеи Глубин", -5, true }, { entries[3].name, entries[3].amount, entries[3].declined })
		end)
	end)

	describe("currencies", function()
		before_each(function()
			Test.SetCurrency(3008, { name = "Valorstones", icon = 5868902, quality = 3, quantity = 10, discovered = true })
			Test.SetCurrency(1, { name = "Hidden", quantity = 0, discovered = false })
			start()
		end)

		it("come from gains of discovered currencies, with the new total", function()
			Test.ChangeCurrency(3008, 5)
			assert.same({ { kind = "currency", id = 3008, name = "Valorstones", icon = 5868902, quality = 3, amount = 5, total = 15 } }, entries)
		end)

		it("leave spending, undiscovered currencies and updates without a change out", function()
			Test.ChangeCurrency(3008, -3)
			Test.ChangeCurrency(1, 2)
			Test.FireEvent("CURRENCY_DISPLAY_UPDATE")
			assert.same({}, entries)
		end)
	end)

	describe("money", function()
		it("comes from gains, not from spending", function()
			start()
			Test.SetMoney(150)
			Test.SetMoney(100)
			Test.SetMoney(120)
			assert.same({ { kind = "money", amount = 150 }, { kind = "money", amount = 20 } }, entries)
		end)

		it("leaves trades at merchants, mail, trade, auction house and banks out", function()
			start()
			local windows = {
				{ "MERCHANT_SHOW", "MERCHANT_CLOSED" }, { "MAIL_SHOW", "MAIL_CLOSED" }, { "TRADE_SHOW", "TRADE_CLOSED" },
				{ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }, { "BANKFRAME_OPENED", "BANKFRAME_CLOSED" },
				{ "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED" },
			}
			local money = 0
			for _, window in ipairs(windows) do
				Test.FireEvent(window[1])
				money = money + 100
				Test.SetMoney(money)
				Test.FireEvent(window[2])
			end
			assert.same({}, entries)
			Test.SetMoney(money + 7)
			assert.same({ { kind = "money", amount = 7 } }, entries)
		end)
	end)

	describe("experience", function()
		it("comes from gains, also across a level-up", function()
			start()
			Test.SetXP(100)
			Test.SetXP(950)
			Test.SetXP(50, 1200)
			assert.same({ 100, 850, 100 }, { entries[1].amount, entries[2].amount, entries[3].amount })
			assert.equals("xp", entries[1].kind)
		end)

		it("leaves other units and updates without a gain out", function()
			start()
			Test.state.xp = { 100, 1000 }
			Test.FireEvent("PLAYER_XP_UPDATE", "target")
			assert.same({}, entries)
			Test.state.xp = { 0, 1000 }
			Test.SetXP(0)
			assert.same({}, entries)
		end)
	end)

	it("leaves items that fast autoloot skipped out of the feed", function()
		start()
		ns.Bus:Send("LootSkipped", { kind = "skipped", name = "Hearthstone", amount = 1 })
		assert.same({}, entries)
	end)

	it("reports formats the client does not have, and works with the others", function()
		local strings = {}
		for name, value in pairs(Formats.enUS) do
			strings[name] = value
		end
		strings.LOOT_ITEM_BONUS_ROLL_SELF = nil
		Test.SetGlobalStrings(strings)
		entries = {}
		ns.Feed.Sources.Start("feed", function(entry) entries[#entries + 1] = entry end)
		assert.same({ "LOOT_ITEM_BONUS_ROLL_SELF" }, ns.Feed.Sources.MissingFormats())
		chat("CHAT_MSG_LOOT", "You receive loot: " .. LINK)
		assert.equals(1, #entries)
	end)
end)
