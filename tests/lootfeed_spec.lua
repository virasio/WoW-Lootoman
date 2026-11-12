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

	it("is on by default, with a settings page for every option, in groups", function()
		assert.is_true(module:IsActive())
		assert.same({
			"checkbox:Enabled",
			"header:What the feed shows", "checkbox:Items", "checkbox:Currencies", "checkbox:Money", "checkbox:Reputation",
			"checkbox:Experience", "dropdown:Minimum quality", "checkbox:Keep usable items",
			"  checkbox:Items that start a quest", "  checkbox:Recipes", "  checkbox:Containers", "  checkbox:Pets", "  checkbox:Mounts",
			"  checkbox:Toys", "  checkbox:Appearance sets", "  checkbox:Heirlooms",
			"header:Rows and timing", "slider:Rows", "dropdown:Fill direction", "slider:Time on screen", "slider:Fade-out time",
			"header:Appearance", "slider:Size", "slider:Background opacity", "checkbox:Glow for rare items",
			"header:Low-space warnings", "checkbox:Warn when few bag slots are free", "slider:Bag slots",
			"checkbox:Warn when few reagent bag slots are free", "slider:Reagent bag slots",
			"button:Row design",
		}, api.Kinds(api.FindCategory("Loot feed")))
	end)

	it("fills sideways only with an Icons layout, and up or down with rows", function()
		local direction
		for _, setting in ipairs(module:Settings()) do
			direction = setting.key == "direction" and setting or direction
		end
		local function offered()
			local list = {}
			for index, choice in ipairs(direction.offered()) do
				list[index] = choice[1]
			end
			return table.concat(list, " ")
		end
		assert.equals("up down", offered())
		local Layouts = ns.Feed.Layouts
		Layouts.Create("Strip", "icons")
		Layouts.Use("Strip")
		assert.equals("up down right left", offered())
		module:Set("direction", "left")
		assert.equals("left", module.feed.options.direction)
		-- Back on rows, the rows' own direction comes back; then the icons' does.
		Layouts.Use("Default")
		assert.same({ "up", "up" }, { module:Get("direction"), module.feed.options.direction })
		module:Set("direction", "down")
		Layouts.Use("Strip")
		assert.same({ "left", "left" }, { module:Get("direction"), module.feed.options.direction })
		Layouts.Use("Default")
		assert.same({ "down", "down" }, { module:Get("direction"), module.feed.options.direction })
		-- Another layout of the same view keeps the direction.
		Layouts.Create("Wide", "large")
		Layouts.Use("Wide")
		assert.equals("down", module:Get("direction"))
		-- A sideways direction left for rows, say from a profile text, becomes bottom to top.
		Layouts.Use("Strip")
		module:Set("otherViewDirection", "right")
		Layouts.Use("Default")
		assert.same({ "up", "up" }, { module:Get("direction"), module.feed.options.direction })
		-- Every direction may come in a profile text.
		assert.is_true(module:Validate("direction", "right"))
	end)

	it("swaps the views' directions also when an import replaces the layout with one of the other view", function()
		local Layouts, Design = ns.Feed.Layouts, ns.Feed.Design
		Layouts.Create("Strip", "icons")
		Layouts.Use("Strip")
		module:Set("direction", "left")
		Layouts.Create("Wide", "large")
		Layouts.Use("Wide")
		module:Set("direction", "down")
		-- "Replace yours": Wide becomes an Icons layout, then a rows layout is chosen.
		Layouts.Put("Wide", { schema = Design.SCHEMA, base = "icons" })
		assert.same({ "left", "left" }, { module:Get("direction"), module.feed.options.direction })
		Layouts.Use("Default")
		assert.same({ "down", "down" }, { module:Get("direction"), module.feed.options.direction })
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

		local function shown()
			local texts = {}
			for index, warning in ipairs(module.feed.warnings) do
				texts[index] = warning.text
			end
			return texts
		end

		it("warn when no more general slots are free than the threshold, 2 by default", function()
			bags(3)
			assert.same({}, shown())
			bags(2)
			assert.same({ "Free bag slots: 2" }, shown())
			bags(0)
			assert.same({ "No free bag slots" }, shown())
			module:Set("warnGeneralAt", 0)
			bags(1)
			assert.same({}, shown())
			module:Set("warnGeneral", false)
			bags(0)
			assert.same({}, shown())
		end)

		it("warn about the reagent bag when turned on and the player has one", function()
			module:Set("warnReagent", true)
			bags(5, 1)
			assert.same({ "Free reagent bag slots: 1" }, shown())
			bags(1, 0)
			assert.same({ "Free bag slots: 1", "No free reagent bag slots" }, shown())
			-- With their counts, for the icons that show them in an Icons layout.
			assert.same({ 1, 0 }, { module.feed.warnings[1].count, module.feed.warnings[2].count })
			bags(5)
			assert.same({}, shown())
		end)

		it("say nothing before the client has told the bags", function()
			assert.same({}, shown())
		end)
	end)

	it("offers the client's item quality names", function()
		local dropdown
		for _, initializer in ipairs(api.FindCategory("Loot feed").initializers) do
			if initializer.setting and initializer.setting.variable == "LOOTOMAN_LOOTFEED_MINQUALITY" then
				dropdown = initializer
			end
		end
		local labels = {}
		for _, data in ipairs(dropdown.options()) do
			labels[#labels + 1] = data.value .. "=" .. data.label
		end
		assert.same({ "0=Poor", "1=Common", "2=Uncommon", "3=Rare", "4=Epic", "5=Legendary" }, labels)
	end)

	it("puts the feed in Edit Mode right of the screen centre, with the same settings in its dialog", function()
		local frame = module.feed.frame
		assert.same({ "Loot feed", { point = "CENTER", x = 300, y = 0 } }, { lib.frames[frame].name, lib.frames[frame].default })
		-- The same groups, with a divider for each header.
		local names = {}
		for _, setting in ipairs(lib.settings[frame]) do
			if setting.kind == "divider" then
				names[#names + 1] = setting.name
			end
		end
		assert.same({ "What the feed shows", "Rows and timing", "Appearance", "Low-space warnings" }, names)
		assert.equals(22, #lib.settings[frame])
		assert.same({ "divider", "Items" }, { lib.settings[frame][1].kind, lib.settings[frame][2].name })
		lib.Fire("enter")
		assert.is_true(frame.shown)
		lib.Fire("exit")
		assert.is_false(frame.shown)
	end)

	it("shows what the player loots", function()
		Test.FireEvent("CHAT_MSG_LOOT", "You receive loot: " .. LINK .. "x2", "Tester")
		Test.SetMoney(150)
		assert.is_true(module.feed.frame.shown)
		module.feed:Draw(Test.state.time)
		local shown = {}
		for _, rowFrame in pairs(module.feed.frameOf) do
			shown[rowFrame.Label.text] = rowFrame.Amount.text
		end
		assert.same({ ["150 copper"] = "", ["Linen Cloth"] = "×2" }, shown)
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

		it("keep an item that starts a quest once the bags hold it, and let it go when the quest is taken", function()
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

		it("puts the kinds under their switch, on the options page only", function()
			local Usable = ns.Rules.Usable
			Test.state.collections = { mount = true }
			local keys = {}
			for _, setting in ipairs(module:Settings()) do
				if setting.parent == "keepUsable" then
					keys[#keys + 1] = setting.key .. (setting.pageOnly and "" or "!")
				end
			end
			assert.same({ "keepQuest", "keepRecipes", "keepContainers", "keepMounts" }, keys)
			assert.same({ "quest", "recipe", "container", "mount" }, Usable.Kinds())
		end)

		it("shows at least 3 rows", function()
			assert.same({ false, true }, { module:Validate("maxRows", 2), module:Validate("maxRows", 3) })
		end)
	end)

	it("reads owned counts again when the bags change", function()
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

	it("leaves experience out until it is turned on", function()
		Test.SetXP(100)
		assert.same({}, module.model:Visible(Test.state.time))
		module:Set("xp", true)
		Test.SetXP(200)
		assert.equals("xp", module.model:Visible(Test.state.time)[1].row.kind)
	end)

	it("applies changed settings at once", function()
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

	it("applies the settings of a profile it switches to", function()
		ns.Profiles.Create("Small")
		ns.Storage.db.profiles.Small.modules = { LootFeed = { maxRows = 4 } }
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
