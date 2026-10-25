local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("settings panel", function()
	local ns, api, built, page

	-- The main page from the top, as "kind:text" with "  " in front of an indented one.
	local function items()
		local list = {}
		for index, item in ipairs(page.items) do
			list[index] = (item.indent > 0 and "  " or "") .. item.kind .. (item.text and (":" .. item.text) or "")
		end
		return list
	end

	local function item(text)
		for _, entry in ipairs(page.items) do
			if entry.text == text then
				return entry.region
			end
		end
		error("no item " .. text)
	end

	local function click(checkbox, checked)
		checkbox.checked = checked
		checkbox.scripts.OnClick(checkbox)
	end

	before_each(function()
		api = SettingsAPI.Install()
		-- Without the addon's own modules: these tests register their own.
		ns = Loader.LoadAddon({ skip = { "Modules/" } })
		built = {}
		ns.Modules:Register({
			name = "Feed",
			title = "Loot feed",
			switchLabel = "Enable loot feed",
			description = "Shows what you loot.",
			defaults = { enabled = true, fade = false },
			BuildSettings = function(self, category)
				built[#built + 1] = self.name
				ns.SettingsPanel.AddCheckbox(category, self.name, "fade", "Fade out")
			end,
		})
		ns.Modules:Register({
			name = "Bags",
			defaults = { enabled = false, sort = true },
			mainSettings = { { kind = "checkbox", key = "sort", label = "Sort bags", tooltip = "Sorts them." } },
		})
		Loader.Start(ns)
		page = ns.SettingsPanel.main
	end)

	it("adds the Lootoman page to the game options: the addon's own page, with the title on top", function()
		local main = api.FindCategory("Lootoman")
		assert.equals(main, api.addOnCategories[1])
		assert.same({ page.frame, "Lootoman" }, { main.frame, page.title.text })
	end)

	it("lists every module's switch after the profile and a divider, with what belongs to it indented under it", function()
		assert.same({
			"label:Profile", "dropdown", "divider",
			"checkbox:Enable loot feed", "  button:Configure",
			"checkbox:Bags", "  checkbox:Sort bags",
		}, items())
		-- The label after the checkbox, and a click on it counts.
		local switch = item("Enable loot feed")
		assert.same({ "LEFT", switch, "RIGHT", 4, 0 }, switch.label.points[1])
		switch.tooltipFunc()
		assert.same({ "Enable loot feed", "Shows what you loot." }, api.tooltip.lines)
	end)

	it("puts every checkbox in a row of its own across the page, so its hover highlight covers only that row", function()
		-- Blizzard's HoverBackgroundTemplate fills the checkbox's parent's parent.
		for _, text in ipairs({ "Enable loot feed", "Sort bags" }) do
			local checkbox = item(text)
			local row = checkbox.parent
			assert.are_not.equal(page.frame, row, text)
			assert.same({ page.frame, row, 29 }, { row.parent, checkbox.label.parent, row.height }, text)
			assert.same({ "TOPRIGHT", page.frame, "TOPRIGHT", -20 }, { row.points[2][1], row.points[2][2], row.points[2][3], row.points[2][4] }, text)
		end
		assert.equals(44, item("Sort bags").parent.points[1][4])
	end)

	it("binds switches and main settings to the module settings", function()
		local switch = item("Enable loot feed")
		assert.is_true(switch.checked)
		click(switch, false)
		assert.is_false(ns.Modules:Get("Feed"):IsActive())
		assert.is_false(ns.Storage:Get("Feed", "enabled"))
		ns.Storage:Set("Bags", "enabled", true)
		click(item("Sort bags"), false)
		assert.is_false(ns.Storage:Get("Bags", "sort"))
	end)

	it("lets a main setting be changed only while its module is on", function()
		local sort = item("Sort bags")
		assert.same({ false, "GameFontDisable" }, { sort.enabled, sort.label.fontObject })
		click(item("Bags"), true)
		assert.same({ true, "GameFontNormal" }, { sort.enabled, sort.label.fontObject })
	end)

	it("shows the stored values again when shown and when they change elsewhere", function()
		local switch = item("Enable loot feed")
		ns.Storage:Set("Feed", "enabled", false)
		assert.is_false(switch.checked)
		ns.Profiles.Create("Other")
		ns.Profiles.Switch("Other")
		assert.is_true(switch.checked)
		switch.checked = false
		page.frame.OnRefresh()
		assert.is_true(switch.checked)
	end)

	it("opens a module's own page with Configure, and adds a page only for a module with its own options", function()
		local feedPage = api.FindCategory("Loot feed")
		local configure = item("Configure")
		configure.scripts.OnClick(configure)
		assert.equals(feedPage:GetID(), api.opened)
		assert.equals(api.FindCategory("Lootoman"), feedPage.parent)
		assert.same({ "checkbox:Enabled", "checkbox:Fade out" }, api.Kinds(feedPage))
		assert.same({ "Feed" }, built)
		assert.is_nil(api.FindCategory("Bags"))
	end)

	it("refreshes the module page's switch when the main page changes it", function()
		click(item("Enable loot feed"), false)
		assert.equals(1, api.settings.LOOTOMAN_FEED_ENABLED.notified)
		assert.equals(0, api.settings.LOOTOMAN_FEED_FADE.notified)
	end)

	it("refreshes every control when the profile changes", function()
		ns.Profiles.Create("Other")
		ns.Profiles.Switch("Other")
		for _, variable in ipairs({ "LOOTOMAN_FEED_ENABLED", "LOOTOMAN_FEED_FADE" }) do
			assert.equals(1, api.settings[variable].notified, variable)
		end
	end)

	it("opens on the Lootoman category when asked", function()
		ns.Bus:Send("OpenSettings")
		assert.equals(api.FindCategory("Lootoman"):GetID(), api.opened)
	end)
end)

describe("settings panel, a module with a broken main setting", function()
	it("is reported, and the others are still listed", function()
		SettingsAPI.Install()
		local ns = Loader.LoadAddon({ skip = { "Modules/" } })
		ns.Modules:Register({ name = "Broken", defaults = { enabled = true, rows = 1 },
			mainSettings = { { kind = "slider", key = "rows", label = "Rows" } } })
		ns.Modules:Register({ name = "Feed", defaults = { enabled = true } })
		Loader.Start(ns)
		assert.matches("Broken.rows: the main page takes only checkboxes", ns.Compat.Test.state.errors[1])
		local last = ns.SettingsPanel.main.items[#ns.SettingsPanel.main.items]
		assert.equals("Feed", last.text)
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

describe("settings panel groups", function()
	it("build a module page from the list the Edit Mode dialog takes, with a header for every group", function()
		local api = SettingsAPI.Install()
		local ns = Loader.LoadAddon({ skip = { "Modules/" } })
		local Panel = ns.SettingsPanel
		ns.Modules:Register({
			name = "Feed",
			title = "Loot feed",
			defaults = { enabled = true, money = true, rows = 8, direction = "up" },
			BuildSettings = function(self, category, layout)
				Panel.AddSettings(category, layout, self.name, {
					{ kind = "header", label = "Shown" },
					{ kind = "checkbox", key = "money", label = "Money" },
					{ kind = "header", label = "Rows and timing", tooltip = "How rows behave." },
					{ kind = "slider", key = "rows", label = "Rows", min = 1, max = 20, step = 1 },
					{ kind = "dropdown", key = "direction", label = "Direction", choices = { { "up", "Up" }, { "down", "Down" } } },
				})
			end,
		})
		Loader.Start(ns)
		local page = api.FindCategory("Loot feed")
		assert.same({ "checkbox:Enabled", "header:Shown", "checkbox:Money", "header:Rows and timing", "slider:Rows", "dropdown:Direction" },
			api.Kinds(page))
		assert.equals("How rows behave.", page.initializers[4].tooltip)
		assert.error_matches(function() Panel.AddSettings(page, {}, "Feed", { { kind = "radio", key = "money" } }) end,
			"Feed: unknown setting kind radio")
	end)
end)
