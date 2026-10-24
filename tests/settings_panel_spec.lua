local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("settings panel", function()
	local ns, api, built

	before_each(function()
		api = SettingsAPI.Install()
		-- Without the addon's own modules: these tests register their own.
		ns = Loader.LoadAddon({ skip = { "Modules/" } })
		built = {}
		ns.Modules:Register({
			name = "Feed",
			title = "Loot feed",
			description = "Shows what you loot.",
			defaults = { enabled = true, fade = false },
			BuildSettings = function(self, category)
				built[#built + 1] = self.name
				ns.SettingsPanel.AddCheckbox(category, self.name, "fade", "Fade out")
			end,
		})
		ns.Modules:Register({ name = "Bags", defaults = { enabled = false } })
		Loader.Start(ns)
	end)

	it("adds the Lootoman category to the game options with a switch per module", function()
		local main = api.FindCategory("Lootoman")
		assert.equals(main, api.addOnCategories[1])
		assert.same({ "header:Modules", "checkbox:Loot feed", "checkbox:Bags" }, api.Kinds(main))
		assert.equals("Shows what you loot.", main.initializers[2].tooltip)
	end)

	it("adds a page per module with its switch first, then its own controls", function()
		local page = api.FindCategory("Loot feed")
		assert.equals(api.FindCategory("Lootoman"), page.parent)
		assert.same({ "checkbox:Enabled", "checkbox:Fade out" }, api.Kinds(page))
		assert.same({ "Feed" }, built)
		assert.same({ "checkbox:Enabled" }, api.Kinds(api.FindCategory("Bags")))
	end)

	it("binds switches to the module settings, with the registered default", function()
		local switch = api.settings.LOOTOMAN_FEED_ENABLED_LIST
		assert.is_true(switch.default)
		assert.is_true(switch:GetValue())
		switch:SetValue(false)
		assert.is_false(ns.Modules:Get("Feed"):IsActive())
		assert.is_false(ns.Storage:Get("Feed", "enabled"))
	end)

	it("refreshes the twin switch but not the one being changed", function()
		local listSwitch, pageSwitch = api.settings.LOOTOMAN_FEED_ENABLED_LIST, api.settings.LOOTOMAN_FEED_ENABLED
		local fade = api.settings.LOOTOMAN_FEED_FADE
		listSwitch:SetValue(false)
		assert.equals(0, listSwitch.notified)
		assert.equals(1, pageSwitch.notified)
		assert.equals(0, fade.notified)
	end)

	it("refreshes every control when the profile changes", function()
		ns.Profiles.Create("Other")
		ns.Profiles.Switch("Other")
		for _, variable in ipairs({ "LOOTOMAN_FEED_ENABLED_LIST", "LOOTOMAN_FEED_ENABLED", "LOOTOMAN_FEED_FADE" }) do
			assert.equals(1, api.settings[variable].notified, variable)
		end
	end)

	it("opens on the Lootoman category when asked", function()
		ns.Bus:Send("OpenSettings")
		assert.equals(api.FindCategory("Lootoman"):GetID(), api.opened)
	end)
end)

describe("settings panel controls", function()
	local ns, api, page

	local function control(variable)
		for _, initializer in ipairs(page.initializers) do
			if initializer.setting.variable == variable then
				return initializer
			end
		end
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = { "Modules/" } })
		ns.Modules:Register({
			name = "Feed",
			title = "Loot feed",
			defaults = { enabled = true, rows = 8, fade = 1, direction = "up", mode = 2 },
			BuildSettings = function(self, category)
				local Panel = ns.SettingsPanel
				Panel.AddSlider(category, self.name, "rows", "Rows", "How many rows.", 1, 20, 1, "%d rows")
				Panel.AddSlider(category, self.name, "fade", "Fade-out", nil, 0.2, 3, 0.1, function(value)
					return ("%.1f s"):format(value)
				end)
				Panel.AddDropdown(category, self.name, "direction", "Direction", "Where new rows go.",
					{ { "up", "Up" }, { "down", "Down" } })
				Panel.AddDropdown(category, self.name, "mode", "Mode", nil, { { 1, "Scroll" }, { 2, "Push out" } })
			end,
		})
		Loader.Start(ns)
		page = api.FindCategory("Loot feed")
	end)

	it("adds sliders and dropdowns to the module page, in order", function()
		assert.same({ "checkbox:Enabled", "slider:Rows", "slider:Fade-out", "dropdown:Direction", "dropdown:Mode" },
			api.Kinds(page))
	end)

	it("gives a slider its range, steps, label and tooltip", function()
		local right = rawget(_G, "MinimalSliderWithSteppersMixin").Label.Right
		local rows = control("LOOTOMAN_FEED_ROWS")
		assert.same({ 1, 20, 19 }, { rows.options.minValue, rows.options.maxValue, rows.options.steps })
		assert.equals("8 rows", rows.options.formatters[right](8))
		assert.equals("How many rows.", rows.tooltip)
		assert.equals("1.5 s", control("LOOTOMAN_FEED_FADE").options.formatters[right](1.5))
	end)

	it("binds a slider to its number setting, keeping values on a step", function()
		local fade = control("LOOTOMAN_FEED_FADE").setting
		assert.equals(1, fade.default)
		fade:SetValue(0.1 + 0.2)
		assert.equals(0.3, ns.Storage:Get("Feed", "fade"))
		fade:SetValue(0.26)
		assert.equals(0.3, ns.Storage:Get("Feed", "fade"))
		fade:SetValue(9)
		assert.equals(3, fade:GetValue())
		control("LOOTOMAN_FEED_ROWS").setting:SetValue(12)
		assert.equals(12, ns.Storage:Get("Feed", "rows"))
	end)

	it("offers a dropdown's choices in order and binds it to its setting", function()
		local direction = control("LOOTOMAN_FEED_DIRECTION")
		local choices = {}
		for index, data in ipairs(direction.options()) do
			choices[index] = data.value .. "=" .. data.label
		end
		assert.same({ "up=Up", "down=Down" }, choices)
		assert.equals("up", direction.setting.default)
		direction.setting:SetValue("down")
		assert.equals("down", ns.Storage:Get("Feed", "direction"))
	end)

	it("binds a dropdown to a number setting", function()
		local mode = control("LOOTOMAN_FEED_MODE").setting
		assert.equals(2, mode:GetValue())
		mode:SetValue(1)
		assert.equals(1, ns.Storage:Get("Feed", "mode"))
	end)

	it("refreshes sliders and dropdowns when their value changes elsewhere", function()
		ns.Storage:Set("Feed", "rows", 3)
		ns.Storage:Set("Feed", "direction", "down")
		assert.equals(1, api.settings.LOOTOMAN_FEED_ROWS.notified)
		assert.equals(1, api.settings.LOOTOMAN_FEED_DIRECTION.notified)
	end)

	it("rejects a slider for a setting that is not a number, and a dropdown without its default", function()
		local Panel = ns.SettingsPanel
		assert.error_matches(function() Panel.AddSlider(page, "Feed", "direction", "Bad", nil, 1, 2, 1) end,
			"Feed.direction: a slider needs a number setting")
		assert.error_matches(function() Panel.AddDropdown(page, "Feed", "direction", "Bad", nil, { { "down", "Down" } }) end,
			"Feed.direction: the default is not one of the choices")
	end)
end)
