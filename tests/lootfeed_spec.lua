local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local Formats = require("tests.fixtures.globalstrings")

local LINK = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r"
local QUALITIES = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Just enough of LibEditMode to see what the feed registers.
local function newLibEditMode()
	local lib = { frames = {}, settings = {}, callbacks = {}, SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 } }
	function lib:AddFrame(frame, _, default, name) self.frames[frame] = { default = default, name = name } end
	function lib:AddFrameSettings(frame, settings) self.settings[frame] = settings end
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

	it("is on by default, with a settings page for every option", function()
		assert.is_true(module:IsActive())
		assert.same({
			"checkbox:Enabled", "checkbox:Items", "checkbox:Currencies", "checkbox:Money", "checkbox:Reputation",
			"checkbox:Experience", "dropdown:Minimum quality", "slider:Rows", "dropdown:New rows appear",
			"slider:Time on screen", "slider:Fade-out time",
		}, api.Kinds(api.FindCategory("Loot feed")))
	end)

	it("offers the client's item quality names", function()
		local dropdown
		for _, initializer in ipairs(api.FindCategory("Loot feed").initializers) do
			if initializer.setting.variable == "LOOTOMAN_LOOTFEED_MINQUALITY" then
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
		assert.equals(10, #lib.settings[frame])
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

	it("leaves experience out until it is turned on", function()
		Test.SetXP(100)
		assert.same({}, module.model:Visible(Test.state.time))
		module:Set("xp", true)
		Test.SetXP(200)
		assert.equals("xp", module.model:Visible(Test.state.time)[1].row.kind)
	end)

	it("applies changed settings at once", function()
		module:Set("maxRows", 3)
		assert.equals(88, module.feed.frame.height)
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
		assert.equals(118, module.feed.frame.height)
	end)

	it("stops reading events and hides when turned off", function()
		Test.SetMoney(150)
		ns.Modules:SetEnabled("LootFeed", false)
		assert.is_false(Test.IsRegistered("CHAT_MSG_LOOT"))
		assert.is_false(Test.IsRegistered("PLAYER_MONEY"))
		assert.is_false(module.feed.frame.shown)
		ns.Modules:SetEnabled("LootFeed", true)
		assert.is_true(Test.IsRegistered("CHAT_MSG_LOOT"))
	end)
end)
