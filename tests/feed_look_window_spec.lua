local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("loot feed look window", function()
	local ns, Test, ui, module, LookWindow, window

	-- The inspector's visible controls as "label: value", with a number's range
	-- (its slider and its field show the same value).
	local function inspector()
		local list = {}
		for _, control in ipairs(window.controls) do
			if control.label.shown then
				if control.check.shown then
					list[#list + 1] = control.label.text .. ": " .. tostring(control.check.checked)
				elseif control.choice.shown then
					list[#list + 1] = control.label.text .. ": " .. control.value
				else
					assert.is_true(control.input.shown)
					assert.equals(tostring(control.slider.value), control.input.text)
					list[#list + 1] = ("%s: %s in %d..%d"):format(control.label.text, control.input.text,
						control.slider.range[1], control.slider.range[2])
				end
			end
		end
		return list
	end

	-- Opens a dropdown's menu: the texts of its radios, the chosen one with a
	-- star; then picks the radio with the value pick, if given.
	local function menu(dropdown, pick)
		local radios, choosePicked = {}, nil
		dropdown.menu(dropdown, { CreateRadio = function(_, text, isSelected, choose, value)
			radios[#radios + 1] = text .. (isSelected(value) and "*" or "")
			if value == pick then
				choosePicked = function() choose(value) end
			end
		end })
		if choosePicked then
			choosePicked()
		end
		return radios
	end

	local function design()
		return ns.Feed.Design.Current(module:DesignSection())
	end

	before_each(function()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		Test, ui = ns.Compat.Test, Loader.ui
		module = ns.Modules:Get("LootFeed")
		LookWindow = module.LookWindow
	end)

	describe("window", function()
		before_each(function()
			-- At the size the designs were drawn for.
			ns.Feed.Looks.Set("Default", "size", 13)
			assert.is_true(LookWindow.Open())
			window = LookWindow.window
		end)

		it("shows the sample rows, each in its box, and the row in the inspector", function()
			assert.is_true(window.shown)
			assert.equals(7, #window.rows)
			-- Each row takes clicks on its free space, the stuck sample too.
			assert.same({ true, true }, { window.rows[1].mouseClicks, window.rows[7].mouseClicks })
			assert.same({ true, 1 }, { window.rows[1].Box.shown, window.rows[1].Box.alpha })
			assert.equals("Row", window.inspectorTitle.text)
			assert.same({ "Row height: 35 in 12..80", "Width: 300 in 120..600", "Gap between rows: 7 in 0..30" }, inspector())
		end)

		it("shows the chosen part's values, within the row's box", function()
			LookWindow.Select("icon")
			assert.equals("Icon", window.inspectorTitle.text)
			assert.same({ "Shown: true", "Anchor to: row", "Anchor point: LEFT", "Size, percent of the row height: 100 in 20..100",
				"Horizontal offset: 0 in 0..265", "Vertical offset: 0 in 0..0" }, inspector())
			LookWindow.Select("owned")
			assert.same({ "Shown: false", "Counts: bags", "Anchor to: icon", "Anchor point: BOTTOMRIGHT", "Text alignment: RIGHT", "Text size: 12 in 6..20",
				"Maximum width: 40 in 20..300", "Horizontal offset: -4 in -23..265", "Vertical offset: 3 in 0..23", "Background: false",
				"Background opacity: 60 in 0..100" }, inspector())
		end)

		it("counts the bags only, or bags and bank, as the look's owned count says", function()
			LookWindow.Select("owned")
			assert.same({ "Bags and bank", "Bags only*" }, menu(window.controls[2].choice, "all"))
			assert.same({ "all", "all" }, { design().parts.owned.count, module.feed.options.layout.parts.owned.count })
		end)

		it("shows or hides the owned count per look, like any part", function()
			LookWindow.Select("owned")
			window.controls[1].check.checked = true
			window.controls[1].check.scripts.OnClick(window.controls[1].check)
			assert.same({ true, true }, { design().parts.owned.shown, module.feed.options.showOwned })
			ns.Feed.Looks.Create("Strip")
			ns.Feed.LookMenu.Use("Strip")
			assert.is_false(module.feed.options.showOwned)
		end)

		it("sets the amount's own background and its opacity", function()
			LookWindow.Select("amount")
			local list = inspector()
			assert.same({ "Background: false", "Background opacity: 60 in 0..100" }, { list[9], list[10] })
			window.controls[9].check.checked = true
			window.controls[9].check.scripts.OnClick(window.controls[9].check)
			assert.is_true(design().parts.amount.background)
		end)

		it("marks the row, the chosen icon, or the most room the chosen text may take, with a frame", function()
			local row = window.rows[1]
			assert.same({ true, { "TOPLEFT", row, "TOPLEFT", -2, 2 } }, { row.Selected.shown, row.Selected.points[1] })
			LookWindow.Select("icon")
			assert.same({ "TOPLEFT", row.Icon, "TOPLEFT", -2, 2 }, row.Selected.points[1])
			assert.equals(0.5, row.Box.alpha)
			-- The name's maximum width of 200, not the width of its text.
			LookWindow.Select("name")
			assert.same({ { "TOPLEFT", row.Label, "TOPLEFT", -2, 2 }, 204 }, { row.Selected.points[1], row.Selected.width })
			LookWindow.Change("name", "align", "RIGHT")
			assert.same({ "TOPRIGHT", row.Label, "TOPRIGHT", 2, 2 }, row.Selected.points[1])
			-- Money has no amount to mark.
			LookWindow.Select("amount")
			assert.same({ true, false }, { row.Selected.shown, window.rows[3].Selected.shown })
		end)

		it("changes the design from its sliders and checkboxes, and the feed follows at once", function()
			window.controls[1].slider.callbacks.OnValueChanged[1](nil, 40.4)
			assert.equals(40, module.feed.options.layout.height)
			assert.same({ row = { height = 40 } }, module:DesignSection().changes)
			LookWindow.Select("icon")
			window.controls[1].check.checked = false
			window.controls[1].check.scripts.OnClick(window.controls[1].check)
			assert.is_false(design().parts.icon.shown)
		end)

		it("takes a number typed into a field, within its range", function()
			local width = window.controls[2].input
			width.text = "320"
			width.scripts.OnEnterPressed(width)
			assert.equals(320, design().width)
			width.text = "9999"
			width.scripts.OnEditFocusLost(width)
			assert.same({ 600, "600" }, { design().width, width.text })
			width.text = "wide"
			width.scripts.OnEnterPressed(width)
			assert.same({ 600, "600" }, { design().width, width.text })
			width.text = "200"
			width.scripts.OnEscapePressed(width)
			assert.same({ 600, "600" }, { design().width, width.text })
			LookWindow.Select("name")
			local x = window.controls[7].input
			x.text = "-12.6"
			x.scripts.OnEnterPressed(x)
			assert.equals(-13, design().parts.name.x)
			-- Only as wide as the row.
			LookWindow.Change("row", "width", 320)
			local nameWidth = window.controls[6].input
			nameWidth.text = "9999"
			nameWidth.scripts.OnEnterPressed(nameWidth)
			assert.equals(320, module:DesignSection().changes.name.width)
		end)

		it("anchors a part to the element and point chosen in its dropdowns, and aligns a text", function()
			LookWindow.Select("name")
			assert.same({ "Row", "Icon*", "Owned count" }, menu(window.controls[2].choice, "row"))
			assert.equals("row", design().parts.name.anchor)
			assert.equals(9, #menu(window.controls[3].choice, "TOPRIGHT"))
			assert.equals("TOPRIGHT", design().parts.name.point)
			assert.same({ "Left*", "Right" }, menu(window.controls[4].choice, "RIGHT"))
			assert.equals("RIGHT", design().parts.name.align)
			assert.same({ "Shown: true", "Anchor to: row", "Anchor point: TOPRIGHT", "Text alignment: RIGHT" },
				{ unpack(inspector(), 1, 4) })
		end)

		it("does not take the values it shows as changes", function()
			LookWindow.Select("name")
			window.updating = true
			window.controls[5].slider.callbacks.OnValueChanged[1](nil, 20)
			window.updating = false
			assert.is_nil(module:DesignSection().changes)
		end)

		it("moves a part dragged with the mouse, on the grid, and stops when it is dropped", function()
			local hit = window.rows[1].hits.name
			ui.cursor = { 100, 100 }
			hit.scripts.OnDragStart(hit)
			assert.equals("Name", window.inspectorTitle.text)
			ui.cursor = { 110, 95 }
			LookWindow.OnUpdate()
			assert.same({ 21, -6 }, { design().parts.name.x, design().parts.name.y })
			hit.scripts.OnDragStop(hit)
			ui.cursor = { 200, 200 }
			LookWindow.OnUpdate()
			assert.same({ 21, -6 }, { design().parts.name.x, design().parts.name.y })
		end)

		it("chooses a part by clicking it, and the row by clicking its free space or between rows", function()
			local hit = window.rows[1].hits.amount
			hit.scripts.OnClick(hit)
			assert.equals("Amount", window.inspectorTitle.text)
			window.preview.scripts.OnMouseDown(window.preview)
			assert.equals("Row", window.inspectorTitle.text)
			hit.scripts.OnClick(hit)
			window.rows[2].scripts.OnMouseDown(window.rows[2])
			assert.equals("Row", window.inspectorTitle.text)
		end)

		it("offers every part, also a hidden one, in its part list", function()
			assert.same({ "Row*", "Icon", "Name", "Amount", "Owned count" }, menu(window.parts, "owned"))
			assert.equals("Owned count", window.inspectorTitle.text)
		end)

		it("lists only what an Icons layout lets change, with its samples side by side", function()
			ns.Feed.Looks.Create("Strip")
			ns.Feed.Looks.SetView("Strip", "icons")
			ns.Feed.Looks.Set("Strip", "size", 13)
			LookWindow.Open("Strip")
			assert.equals("Icon", window.inspectorTitle.text)
			assert.same({ "Icon size: 36 in 12..80", "Gap between icons: 4 in 0..30" }, inspector())
			assert.same({ "Icon*", "Amount", "Owned count" }, menu(window.parts))
			-- The owned count set as the amount is, on the icon or beside it.
			LookWindow.Select("owned")
			assert.same({ "Shown: false", "Counts: bags", "Anchor point: TOPRIGHT", "Text alignment: RIGHT", "Text size: 10 in 6..20",
				"Horizontal offset: -2 in -60..36", "Vertical offset: -2 in -62..36", "Background: false",
				"Background opacity: 60 in 0..100" }, inspector())
			LookWindow.Select("amount")
			assert.same({ "Shown: true", "Anchor point: BOTTOMRIGHT", "Text alignment: RIGHT", "Text size: 13 in 8..24",
				"Horizontal offset: -2 in -60..36", "Vertical offset: 2 in -36..59", "Background: false",
				"Background opacity: 60 in 0..100" }, inspector())
			-- Icons 36 wide and 4 apart, side by side.
			assert.same({ "TOPLEFT", window.preview, "TOPLEFT", 52, -12 }, window.rows[2].points[1])
			-- The icon stands for the row; the name cannot be chosen.
			local rowFrame = window.rows[1]
			-- The owned count is hidden at first, and so is its hit area.
			assert.same({ true, false, false, true }, { rowFrame.hits.icon.shown, rowFrame.hits.name.shown, rowFrame.hits.owned.shown,
				rowFrame.hits.amount.shown })
			rowFrame.hits.icon.scripts.OnClick(rowFrame.hits.icon)
			assert.equals("Icon", window.inspectorTitle.text)
			-- Back on rows, every part again.
			LookWindow.Open("Default")
			assert.same({ "Row*", "Icon", "Name", "Amount", "Owned count" }, menu(window.parts))
		end)

		it("hides on Escape and with its close button, and the command toggles it", function()
			assert.is_true(ui.PressEscape())
			assert.is_false(window.shown)
			assert.is_false(ui.PressEscape())
			Test.RunSlashCommand("LOOTOMAN", "design")
			assert.is_true(window.shown)
			Test.RunSlashCommand("LOOTOMAN", "design")
			assert.is_false(window.shown)
		end)
	end)

	describe("Feed tab", function()
		local function settingOf(key)
			for _, control in ipairs(window.settings) do
				if control.setting.key == key then
					return control
				end
			end
		end

		before_each(function()
			assert.is_true(LookWindow.Open())
			window = LookWindow.window
		end)

		it("comes up first, with every setting of the look in its groups; a part chosen brings up Row design", function()
			assert.same({ 1, true, false }, { window.selectedTab, window.feedTab.shown, window.designTab.shown })
			local headers = {}
			for _, control in ipairs(window.settings) do
				if control.setting.kind == "header" then
					headers[#headers + 1] = control.text.text
				end
			end
			assert.same({ "What the feed shows", "Kept usable items", "Rows and timing", "Appearance", "Low-space warnings" }, headers)
			window.rows[1].hits.name.scripts.OnClick(window.rows[1].hits.name)
			assert.same({ 2, false, true, "Name" }, { window.selectedTab, window.feedTab.shown, window.designTab.shown, window.inspectorTitle.text })
			window.tab1.scripts.OnClick(window.tab1)
			assert.equals(1, window.selectedTab)
		end)

		it("sets the look's settings, and the feed follows at once", function()
			local xp = settingOf("xp")
			assert.same({ "Experience", true }, { xp.label.text, xp.check.checked })
			xp.check.checked = false
			xp.check.scripts.OnClick(xp.check)
			assert.same({ false, false }, { ns.Feed.Looks.Value("Default", "xp"), module.model.options.kinds.xp })
			local rows = settingOf("maxRows")
			rows.slider.callbacks.OnValueChanged[1](nil, 7.4)
			assert.same({ 7, 7, "7" }, { ns.Feed.Looks.Value("Default", "maxRows"), module.feed.options.maxRows, rows.value.text })
			settingOf("fade").slider.callbacks.OnValueChanged[1](nil, 1.53)
			assert.same({ 1.5, "1.5 s" }, { ns.Feed.Looks.Value("Default", "fade"), settingOf("fade").value.text })
			assert.same({ "Bottom to top*", "Top to bottom" }, menu(settingOf("direction").choice, "down"))
			assert.equals("down", module.feed.options.direction)
		end)

		it("lets a setting under another change only while that one is on", function()
			local recipes = settingOf("keepRecipes")
			assert.is_true(recipes.check.enabled ~= false)
			ns.Feed.Looks.Set("Default", "keepUsable", false)
			assert.is_false(recipes.check.enabled)
			ns.Feed.Looks.Set("Default", "warnGeneral", false)
			assert.is_false(settingOf("warnGeneralAt").slider.enabled)
		end)

		it("does not take the values it shows as changes", function()
			window.updating = true
			settingOf("maxRows").slider.callbacks.OnValueChanged[1](nil, 9)
			window.updating = false
			assert.is_nil(ns.Feed.Looks.Get("Default").values)
		end)
	end)

	describe("on a look the profile does not use", function()
		before_each(function()
			ns.Feed.Looks.Create("Raid")
			ns.Feed.Looks.Set("Raid", "size", 13)
			assert.is_true(LookWindow.Open("Raid"))
			window = LookWindow.window
		end)

		it("names it in its title and changes it, leaving the feed alone", function()
			assert.same({ "Feed look: Raid", "Raid" }, { window.title, LookWindow.Edited() })
			LookWindow.Change("row", "height", 40)
			LookWindow.Set("maxRows", 9)
			assert.same({ { row = { height = 40 } }, 9 }, { ns.Feed.Looks.Get("Raid").changes, ns.Feed.Looks.Value("Raid", "maxRows") })
			assert.same({ 5, nil }, { module.feed.options.maxRows, ns.Feed.Looks.Get("Default").changes })
		end)

		it("follows it when it is renamed, and closes when it is deleted", function()
			ns.Feed.Looks.Rename("Raid", "Party")
			assert.same({ "Feed look: Party", "Party" }, { window.title, LookWindow.Edited() })
			ns.Feed.Looks.Delete("Party")
			assert.is_false(window.shown)
		end)
	end)

	it("is built only out of combat", function()
		Test.SetCombat(true)
		assert.is_false(LookWindow.Open())
		assert.is_nil(LookWindow.window)
		assert.matches("out of combat", Test.state.printed[#Test.state.printed])
		Test.SetCombat(false)
		assert.is_true(LookWindow.Open())
	end)
end)

describe("loot feed look window, opened from", function()
	it("a button on the feed's options page and in its Edit Mode dialog", function()
		local lib = { SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 } }
		function lib:AddFrame() end
		function lib:AddFrameSettings() end
		lib.buttons = {}
		function lib:AddFrameSettingsButtons(frame, buttons) self.buttons[frame] = buttons end
		function lib:RegisterCallback() end
		function lib:IsInEditMode() return false end
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		local api = SettingsAPI.Install()
		local ns = Loader.LoadAddon({ skip = {} })
		Loader.Start(ns)
		local LookWindow = ns.Modules:Get("LootFeed").LookWindow
		local feedButtons = lib.buttons[ns.Modules:Get("LootFeed").feed.frame]

		local button = api.FindButton(api.FindCategory("Loot feed"), "Row design")
		button.onClick()
		assert.is_true(LookWindow.window.shown)
		LookWindow.window:Hide()
		assert.equals("Design rows", feedButtons[1].text)
		feedButtons[1].click()
		assert.is_true(LookWindow.window.shown)
	end)
end)

describe("loot feed look window's buttons and view", function()
	local ns, api, LookWindow, window, Looks

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		LookWindow, Looks = ns.Modules:Get("LootFeed").LookWindow, ns.Feed.Looks
		assert.is_true(LookWindow.Open())
		window = LookWindow.window
	end)

	it("returns the look to its defaults with Reset, after a confirmation", function()
		Looks.SetDesign("Default", "row", "height", 40)
		Looks.Set("Default", "maxRows", 9)
		window.reset.scripts.OnClick(window.reset)
		assert.equals("Default", api.popups[#api.popups].data.text_arg1)
		api.AcceptPopup()
		assert.same({ schema = 1, base = "large" }, Looks.Get("Default"))
	end)

	it("opens the dialog of look texts with Share, this look ticked", function()
		local opened = {}
		ns.Bus:On("OpenShareDialog", "test", function(_, mode, item) opened[#opened + 1] = mode .. ":" .. tostring(item) end)
		window.share.scripts.OnClick(window.share)
		assert.same({ "looks:Default" }, opened)
	end)

	it("turns the look into the other view after a confirmation, its design afresh", function()
		Looks.SetDesign("Default", "row", "height", 40)
		LookWindow.SetView("icons")
		assert.equals("rows", Looks.View("Default"))
		api.AcceptPopup()
		assert.same({ "icons", { schema = 1, base = "icons" } }, { Looks.View("Default"), Looks.Get("Default") })
		assert.equals("Icon", window.inspectorTitle.text)
		-- The same view again asks nothing.
		local asked = #api.popups
		LookWindow.SetView("icons")
		assert.equals(asked, #api.popups)
	end)
end)
