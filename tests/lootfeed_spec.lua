local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local Formats = require("tests.fixtures.globalstrings")

local LINK = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r"
local QUALITIES = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Just enough of LibEditMode to see what the feed registers.
local function newLibEditMode()
	local lib = { frames = {}, settings = {}, callbacks = {}, SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2, Divider = "divider" } }
	function lib:AddFrame(frame, _, default, name) self.frames[frame] = { default = default, name = name } end
	function lib:AddFrameSettings(frame, settings) self.settings[frame] = settings end
	function lib:AddFrameSettingsButtons(frame, buttons)
		self.buttons = self.buttons or {}
		self.buttons[frame] = buttons
	end
	function lib:RegisterCallback(event, callback)
		self.callbacks[event] = self.callbacks[event] or {}
		table.insert(self.callbacks[event], callback)
	end
	function lib:IsInEditMode() return self.editing == true end
	function lib.Fire(event)
		lib.editing = event == "enter"
		for _, callback in ipairs(lib.callbacks[event] or {}) do
			callback()
		end
	end
	return lib
end

describe("loot feed module", function()
	local ns, api, lib, Test, module

	before_each(function()
		lib = newLibEditMode()
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		local strings = {}
		for name, value in pairs(Formats.enUS) do
			strings[name] = value
		end
		for quality, name in ipairs(QUALITIES) do
			strings[("ITEM_QUALITY%d_DESC"):format(quality - 1)] = name
		end
		Test.SetGlobalStrings(strings)
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 132889, quality = 1, stackSize = 200 } })
		Loader.Start(ns)
		module = ns.Modules:Get("LootFeed")
	end)

	it("is on by default, its look under its switch on the main page; its settings belong to its look", function()
		assert.is_true(module:IsActive())
		assert.is_nil(api.FindCategory("Loot feed"))
		local page = ns.SettingsPanel.main
		local switch, look = page.items[#page.items - 1], page.items[#page.items]
		assert.same({ "checkbox", "Show the Loot Feed", "row", "Feed Look", 24 }, { switch.kind, switch.text, look.kind, look.text, look.indent })
		assert.equals(ns.Feed.LookMenu.Build, page.look.menu)
		assert.same({ "Default", 5, true, 3 }, { ns.Storage:Get("LootFeed", "look"), module:Get("maxRows"), module:Get("xp"), module:Get("warnGeneralAt") })
		-- It follows the look renamed elsewhere.
		local generated = page.look.generated
		ns.Feed.Looks.Create("Raid")
		ns.Feed.Looks.Use("Raid")
		ns.Feed.Looks.Rename("Raid", "Party")
		assert.is_true(page.look.generated > generated)
		-- Greyed out while the feed is off.
		ns.Modules:SetEnabled("LootFeed", false)
		page:Refresh()
		assert.is_false(page.look.enabled)
	end)

	it("follows the look the profile uses, and its view's fill directions", function()
		local Looks = ns.Feed.Looks
		Looks.Create("Strip")
		Looks.SetView("Strip", "icons")
		Looks.Use("Strip")
		assert.same({ "right", "icons" }, { module.feed.options.direction, ns.Feed.Design.View(module.feed.options.layout) })
		module:Set("direction", "left")
		assert.equals("left", module.feed.options.direction)
		Looks.Use("Default")
		assert.equals("up", module.feed.options.direction)
		assert.has_error(function() module:Set("direction", "left") end)
		module:Set("direction", "down")
		assert.same({ "down", "down" }, { module:Get("direction"), module.feed.options.direction })
	end)

	it("takes a change of its look at once, in every profile that uses it", function()
		local Looks = ns.Feed.Looks
		ns.Profiles.Create("Alt")
		Looks.Set("Default", "maxRows", 7)
		assert.equals(7, module.model.options.maxRows)
		ns.Profiles.Switch("Alt")
		assert.equals(7, module.model.options.maxRows)
		-- Its design too.
		Looks.SetDesign("Default", "row", "height", 40)
		assert.equals(37, module.feed.options.layout.height)
	end)

	describe("low-space warnings", function()
		-- General bags with this many free slots, and a reagent bag with that many.
		local function bags(general, reagent)
			local items = {}
			for slot = 1, 10 - general do
				items[slot] = { itemID = 2589, count = 1 }
			end
			local reagentItems = {}
			for slot = 1, 5 - (reagent or 5) do
				reagentItems[slot] = { itemID = 2589, count = 1 }
			end
			Test.SetBags({ [0] = { size = 10, items = items }, [5] = reagent and { size = 5, items = reagentItems } or nil })
		end

		-- The warning's amount, or nil without one.
		local function shown()
			return module.feed.warning and module.feed.warning.amount or nil
		end

		it("warn, by default, only when no more general slots are free than 3, with every bag's count", function()
			bags(4, 0)
			assert.is_nil(shown())
			bags(3, 0)
			-- General white, reagent green: today's "3+0".
			assert.equals("|cffffffff3|r|cffffffff+|r|cff1eff000|r", shown())
			assert.same({ "General bags: 3 of 10 free", "Reagent bag: 0 of 5 free" }, module.feed.warning.lines)
			module:Set("warnGeneralAt", 0)
			bags(1)
			assert.is_nil(shown())
			module:Set("warnGeneral", false)
			bags(0)
			assert.is_nil(shown())
		end)

		it("warn about all bags together, or the reagent bag, when those are turned on", function()
			module:Set("warnGeneral", false)
			module:Set("warnTotal", true)
			bags(4, 2)
			assert.is_nil(shown())
			bags(3, 2)
			assert.is_not_nil(shown())
			module:Set("warnTotal", false)
			module:Set("warnReagent", true)
			bags(8, 2)
			assert.is_not_nil(shown())
			-- Without a reagent bag, its threshold never warns.
			bags(8)
			assert.is_nil(shown())
		end)

		it("write the amount from the look's template, a typo as typed", function()
			module:Set("slotsText", "{general} / {general.total} {herb}")
			bags(2)
			assert.equals("|cffffffff2|r|cffffffff / |r|cffffffff10|r|cffffffff {herb}|r", shown())
		end)

		it("open the toss window with a click while junk management is on", function()
			bags(2)
			local opened = 0
			ns.Bus:On("OpenTossWindow", "test", function() opened = opened + 1 end)
			assert.is_true(module.feed.warning.clickable)
			module.feed.onWarningClick()
			assert.equals(1, opened)
			ns.Modules:SetEnabled("Junk", false)
			assert.is_false(module.feed.warning.clickable)
		end)
	end)

	it("puts the feed in Edit Mode right of the screen centre, with no settings in the library's dialog", function()
		local frame = module.feed.frame
		assert.same({ "Loot Feed", { point = "CENTER", x = 300, y = 0 } }, { lib.frames[frame].name, lib.frames[frame].default })
		assert.is_nil(lib.settings[frame])
		assert.is_nil(lib.buttons and lib.buttons[frame])
		lib.Fire("enter")
		assert.is_true(frame.shown)
		lib.Fire("exit")
		assert.is_false(frame.shown)
	end)

	it("shows what the player loots", function()
		Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LINK .. "x2", "Tester")
		Test.SetMoney(150)
		assert.is_true(module.feed.frame.shown)
		-- The second row comes in a moment after the first.
		module.feed:Draw(Test.state.time + 0.2)
		local shown = {}
		for _, rowFrame in pairs(module.feed.frameOf) do
			shown[rowFrame.Label.text] = rowFrame.Amount.text
		end
		assert.same({ ["150 copper"] = "", ["Linen Cloth"] = "×2" }, shown)
	end)

	it("lets item rows take clicks while the chat-link modifier is held", function()
		Loader.ui.modifiers.CHATLINK = true
		Test.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		assert.is_true(module.feed.linkModifier)
		Loader.ui.modifiers.CHATLINK = nil
		Test.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
		assert.is_false(module.feed.linkModifier)
	end)

	describe("junk in one row", function()
		local RAG = "|cff9d9d9d|Hitem:700::|h[Rag]|h|r"
		local BONE = "|cff9d9d9d|Hitem:701::|h[Bone]|h|r"
		local TOOTH = "|cff9d9d9d|Hitem:702::|h[Tooth]|h|r"
		local BOX = "|cff9d9d9d|Hitem:703::|h[Box]|h|r"

		before_each(function()
			Test.SetItems({
				[2589] = { name = "Linen Cloth", icon = 132889, quality = 1, stackSize = 200 },
				[700] = { name = "Rag", icon = 1, quality = 0 }, [701] = { name = "Bone", icon = 2, quality = 0 },
				[702] = { name = "Tooth", icon = 3, quality = 0 }, [703] = { name = "Box", icon = 4, quality = 0 },
			})
		end)

		local function loot(link, count)
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. link .. (count and ("x" .. count) or ""), "Tester")
		end

		local function junkRow()
			for _, row in ipairs(module.model.rows) do
				if row.parts then
					return row
				end
			end
		end

		it("gathers gray items and items marked as junk into one row, each counted", function()
			ns.Marks.Set(2589, "junk")
			loot(RAG, 2)
			loot(BONE)
			loot(LINK, 3)
			loot(RAG)
			local row = junkRow()
			assert.same({ "Junk", 7, 1 }, { row.name, row.amount, #module.model.rows })
			assert.same({ { 700, 3 }, { 701, 1 }, { 2589, 3 } }, { { row.parts[1].key, row.parts[1].amount },
				{ row.parts[2].key, row.parts[2].amount }, { row.parts[3].key, row.parts[3].amount } })
		end)

		it("leaves apart a gray item marked not junk, an item not loaded yet, and everything with the setting off", function()
			ns.Marks.Set(701, "notJunk")
			loot(BONE)
			loot("|Hitem:799::|h[Unknown]|h")
			assert.is_nil(junkRow())
			assert.equals(2, #module.model.rows)
			module:Set("junkRow", false)
			loot(RAG)
			assert.is_nil(junkRow())
		end)

		it("drops junk below the minimum quality as before", function()
			module:Set("minQuality", 1)
			loot(TOOTH)
			assert.same({}, module.model.rows)
		end)

		it("takes out an item the character can use once the bags hold it, as a kept row", function()
			loot(RAG)
			loot(BOX)
			assert.equals(2, #junkRow().parts)
			Test.SetBags({ [0] = { size = 16, items = { { itemID = 703, count = 1, use = { openable = true } } } } })
			local row = junkRow()
			assert.same({ 1, 1, 700 }, { #row.parts, row.amount, row.parts[1].key })
			local kept
			for _, other in ipairs(module.model.rows) do
				if other.id == 703 then
					kept = other
				end
			end
			assert.equals("container", kept.sticky)
		end)
	end)

	describe("usable items", function()
		local LETTER = "|cffffffff|Hitem:500::|h[Letter]|h|r"
		local CLAM = "|cffffffff|Hitem:600::|h[Clam]|h|r"

		before_each(function()
			Test.SetItems({
				[500] = { name = "Letter", icon = 1, quality = 1, stackSize = 20, owned = 1 },
				[600] = { name = "Clam", icon = 2, quality = 0, stackSize = 20, owned = 3 },
			})
		end)

		local function holding(items)
			local slots = {}
			for index, item in ipairs(items) do
				slots[index] = item
			end
			Test.SetBags({ [0] = { size = 16, items = slots } })
		end

		local function rowOf(id)
			for _, row in ipairs(module.model.rows) do
				if row.id == id then
					return row
				end
			end
		end

		it("keep an item that starts a quest once the bags hold it, and let it fade when the quest is taken", function()
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LETTER, "Tester")
			-- Not in the bags yet.
			assert.is_nil(rowOf(500).sticky)
			local letter = { itemID = 500, count = 1, use = { questID = 9 } }
			holding({ letter })
			assert.equals("quest", rowOf(500).sticky)
			Test.Advance(10)
			local views = module.model:Visible(Test.state.time)
			assert.same({ true, "Letter" }, { views[#views].stuck, views[#views].row.name })
			letter.use.questTaken = true
			Test.FireEvent("QUEST_ACCEPTED", 9)
			assert.same({}, module.model:Stuck())
			-- Still in the bags: it fades out as any row.
			assert.is_true(rowOf(500).fadeEnd > Test.state.time)
		end)

		it("keep an item again that becomes usable before its row is gone, and let one that left the bags go at once", function()
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LETTER, "Tester")
			local letter = { itemID = 500, count = 1, use = { questID = 9, questTaken = true } }
			holding({ letter })
			assert.is_nil(rowOf(500).sticky)
			letter.use.questTaken = false
			module:CheckAll()
			Test.Advance(10)
			module.model:Update(Test.state.time)
			assert.equals(1, #module.model:Stuck())
			-- Not usable for a moment: it fades, and sticks again before it is gone.
			letter.use.questTaken = true
			module:CheckAll()
			assert.same({}, module.model:Stuck())
			letter.use.questTaken = false
			module:CheckAll()
			module.model:Update(Test.state.time)
			assert.equals(1, #module.model:Stuck())
			-- Gone from the bags: the row goes at once.
			holding({})
			assert.is_nil(rowOf(500))
		end)

		it("keep a usable item below the minimum quality, and count down what is left as it is used", function()
			module:Set("minQuality", 1)
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. CLAM .. "x3", "Tester")
			assert.is_nil(rowOf(600))
			local clams = { itemID = 600, count = 3, use = { openable = true } }
			holding({ clams })
			local row = rowOf(600)
			assert.same({ "container", 3 }, { row.sticky, row.amount })
			Test.Advance(10)
			module:CheckAll()
			Test.state.items[600].owned = 2
			clams.count = 2
			holding({ clams })
			assert.equals(2, row.amount)
			-- The last one used: the row goes.
			holding({})
			assert.same({}, module.model:Stuck())
		end)

		it("count down only the looted ones when the bags held some before", function()
			-- Ten clams in the bags, three looted.
			local clams = { itemID = 600, count = 10, use = { openable = true } }
			Test.state.items[600].owned = 10
			holding({ clams })
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. CLAM .. "x3", "Tester")
			local row = rowOf(600)
			assert.same({ "container", 3 }, { row.sticky, row.amount })
			Test.state.items[600].owned, clams.count = 13, 13
			holding({ clams })
			Test.Advance(10)
			module.model:Update(Test.state.time)
			module:CheckAll()
			assert.same({ row }, module.model:Stuck())
			-- Two opened: one left; more looted adds to it.
			Test.state.items[600].owned, clams.count = 11, 11
			holding({ clams })
			assert.equals(1, row.amount)
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. CLAM .. "x2", "Tester")
			Test.state.items[600].owned, clams.count = 13, 13
			holding({ clams })
			assert.equals(3, row.amount)
			-- The looted ones used: the row goes, with the ten from before still in the bags.
			Test.state.items[600].owned, clams.count = 10, 10
			holding({ clams })
			assert.same({}, module.model:Stuck())
			assert.is_nil(rowOf(600))
		end)

		it("keep a kept row while the bags' scan is behind a moved item", function()
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LETTER, "Tester")
			holding({ { itemID = 500, count = 1, use = { questID = 9 } } })
			Test.Advance(10)
			module.model:Update(Test.state.time)
			assert.equals(1, #module.model:Stuck())
			-- The letter's slot holds something else now, before the next scan.
			Test.state.bags[0].items[1] = { itemID = 2589, count = 1 }
			module:CheckAll()
			assert.equals(1, #module.model:Stuck())
		end)

		it("keep only the kinds turned on, and nothing with the switch off", function()
			module:Set("keepQuest", false)
			Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LETTER, "Tester")
			holding({ { itemID = 500, count = 1, use = { questID = 9 } } })
			assert.is_nil(rowOf(500).sticky)
			module:Set("keepQuest", true)
			assert.equals("quest", rowOf(500).sticky)
			module:Set("keepUsable", false)
			assert.is_nil(rowOf(500).sticky)
			-- Nor while the feed shows no items: a kept row goes.
			module:Set("keepUsable", true)
			Test.Advance(10)
			module.model:Update(Test.state.time)
			assert.equals(1, #module.model:Stuck())
			module:Set("items", false)
			assert.same({}, module.model:Stuck())
		end)

		it("puts the kinds under their switch, only those whose collections the client has", function()
			local Usable = ns.Rules.Usable
			Test.state.collections = { mount = true }
			local keys = {}
			for _, setting in ipairs(ns.Feed.Looks.Settings("rows")) do
				if setting.parent == "keepUsable" then
					keys[#keys + 1] = setting.key
				end
			end
			assert.same({ "keepQuest", "keepRecipes", "keepContainers", "keepMounts" }, keys)
			assert.same({ "quest", "recipe", "container", "mount" }, Usable.Kinds())
		end)

		it("shows at least 3 rows", function()
			assert.same({ nil, true }, { ns.Feed.Looks.Set("Default", "maxRows", 2), ns.Feed.Looks.Set("Default", "maxRows", 3) })
		end)
	end)

	it("reads owned counts again when the bags change, once the look shows them", function()
		ns.Feed.Looks.SetDesign("Default", "owned", "shown", true)
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 132889, quality = 1, stackSize = 200, owned = 0 } })
		Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LINK, "Tester")
		module.feed:Draw(Test.state.time)
		local row = next(module.feed.frameOf) and select(2, next(module.feed.frameOf))
		assert.is_false(row.Owned.shown)
		Test.SetItems({ [2589] = { name = "Linen Cloth", icon = 132889, quality = 1, stackSize = 200, owned = 7 } })
		Test.FireEvent("BAG_UPDATE_DELAYED")
		module.feed:Draw(Test.state.time)
		assert.same({ true, "7" }, { row.Owned.shown, row.Owned.text })
	end)

	it("shows experience, unless turned off", function()
		module:Set("xp", false)
		Test.SetXP(100)
		assert.same({}, module.model:Visible(Test.state.time))
		module:Set("xp", true)
		Test.SetXP(200)
		assert.equals("xp", module.model:Visible(Test.state.time)[1].row.kind)
	end)

	it("applies changed settings at once", function()
		module:Set("size", 13)
		module:Set("maxRows", 3)
		assert.equals(119, module.feed.frame.height)
		module:Set("size", 16)
		assert.equals(369, module.feed.frame.width)
		module:Set("backgroundOpacity", 80)
		assert.equals(0.8, module.feed.frame.Background.gradient[2].a)
		assert.equals(3, module.model.options.maxRows)
		module:Set("direction", "down")
		assert.equals("down", module.feed.options.direction)
		module:Set("money", false)
		Test.SetMoney(500)
		assert.same({}, module.model:Visible(Test.state.time))
	end)

	it("applies the look of a profile it switches to", function()
		local Looks = ns.Feed.Looks
		Looks.Create("Small")
		Looks.Set("Small", "maxRows", 4)
		Looks.Set("Small", "size", 13)
		ns.Profiles.Create("Small")
		ns.Storage.db.profiles.Small.modules = { LootFeed = { look = "Small" } }
		ns.Profiles.Switch("Small")
		assert.equals(161, module.feed.frame.height)
	end)

	it("stops reading events and hides when turned off", function()
		Test.SetMoney(150)
		ns.Modules:SetEnabled("LootFeed", false)
		assert.is_false(Test.IsRegistered("CHAT_MSG_LOOT"))
		-- Other modules may still listen to money; the feed does not.
		assert.same({}, ns.Bus:GetEvents(module))
		assert.is_false(module.feed.frame.shown)
		ns.Modules:SetEnabled("LootFeed", true)
		assert.is_true(Test.IsRegistered("CHAT_MSG_LOOT"))
	end)
end)
