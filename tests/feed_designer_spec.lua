local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("loot feed designer", function()
	local ns, Test, ui, module, Designer, window

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
		Designer = module.Designer
	end)

	describe("window", function()
		before_each(function()
			assert.is_true(Designer.Open())
			window = Designer.window
		end)

		it("shows the sample rows, each in its box, and the row in the inspector", function()
			assert.is_true(window.shown)
			assert.equals(5, #window.rows)
			assert.same({ true, 1 }, { window.rows[1].Box.shown, window.rows[1].Box.alpha })
			assert.equals("Row", window.inspectorTitle.text)
			assert.same({ "Row height: 35 in 12..80", "Width: 300 in 120..600", "Gap between rows: 7 in 0..30" }, inspector())
		end)

		it("shows the chosen part's values, within the row's box", function()
			Designer.Select("icon")
			assert.equals("Icon", window.inspectorTitle.text)
			assert.same({ "Shown: true", "Anchor to: row", "Anchor point: LEFT", "Size, percent of the row height: 100 in 20..100",
				"Horizontal offset: 0 in 0..265", "Vertical offset: 0 in 0..0" }, inspector())
			Designer.Select("owned")
			assert.same({ "Shown: true", "Anchor to: icon", "Anchor point: BOTTOMRIGHT", "Text alignment: RIGHT", "Text size: 12 in 6..20",
				"Maximum width: 40 in 20..300", "Horizontal offset: -4 in -23..265", "Vertical offset: 3 in 0..23" }, inspector())
		end)

		it("marks the row, the chosen icon, or the most room the chosen text may take, with a frame", function()
			local row = window.rows[1]
			assert.same({ true, { "TOPLEFT", row, "TOPLEFT", -2, 2 } }, { row.Selected.shown, row.Selected.points[1] })
			Designer.Select("icon")
			assert.same({ "TOPLEFT", row.Icon, "TOPLEFT", -2, 2 }, row.Selected.points[1])
			assert.equals(0.5, row.Box.alpha)
			-- The name's maximum width of 200, not the width of its text.
			Designer.Select("name")
			assert.same({ { "TOPLEFT", row.Label, "TOPLEFT", -2, 2 }, 204 }, { row.Selected.points[1], row.Selected.width })
			Designer.Change("name", "align", "RIGHT")
			assert.same({ "TOPRIGHT", row.Label, "TOPRIGHT", 2, 2 }, row.Selected.points[1])
			-- Money has no amount to mark.
			Designer.Select("amount")
			assert.same({ true, false }, { row.Selected.shown, window.rows[3].Selected.shown })
		end)

		it("changes the design from its sliders and checkboxes, and the feed follows at once", function()
			window.controls[1].slider.callbacks.OnValueChanged[1](nil, 40.4)
			assert.equals(40, module.feed.options.layout.height)
			assert.same({ row = { height = 40 } }, module:DesignSection().changes)
			Designer.Select("icon")
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
			Designer.Select("name")
			local x = window.controls[7].input
			x.text = "-12.6"
			x.scripts.OnEnterPressed(x)
			assert.equals(-13, design().parts.name.x)
			-- Only as wide as the row.
			Designer.Change("row", "width", 320)
			local nameWidth = window.controls[6].input
			nameWidth.text = "9999"
			nameWidth.scripts.OnEnterPressed(nameWidth)
			assert.equals(320, module:DesignSection().changes.name.width)
		end)

		it("anchors a part to the element and point chosen in its dropdowns, and aligns a text", function()
			Designer.Select("name")
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
			Designer.Select("name")
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
			Designer.OnUpdate()
			assert.same({ 21, -6 }, { design().parts.name.x, design().parts.name.y })
			hit.scripts.OnDragStop(hit)
			ui.cursor = { 200, 200 }
			Designer.OnUpdate()
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

	it("is built only out of combat", function()
		Test.SetCombat(true)
		assert.is_false(Designer.Open())
		assert.is_nil(Designer.window)
		assert.matches("out of combat", Test.state.printed[#Test.state.printed])
		Test.SetCombat(false)
		assert.is_true(Designer.Open())
	end)
end)

describe("loot feed designer's layout menu", function()
	local ns, api, Designer, Layouts, module

	local function openMenu()
		return api.OpenMenu(Designer.window.layouts)
	end

	-- "kind:text", with a star on the chosen one.
	local function texts(entries)
		local list = {}
		for index, entry in ipairs(entries) do
			list[index] = entry.kind .. ":" .. (entry.text or "") .. (entry.isSelected and entry.isSelected(entry.data) and "*" or "")
		end
		return list
	end

	-- The menu's entry whose text has this in it.
	local function find(text)
		for _, entry in ipairs(openMenu().entries) do
			if entry.text and entry.text:find(text, 1, true) then
				return entry
			end
		end
	end

	local function layoutEntry(name)
		for _, entry in ipairs(openMenu().entries) do
			if entry.kind == "radio" and entry.data == name then
				return entry
			end
		end
	end

	local function act(name, text)
		for _, entry in ipairs(layoutEntry(name).entries) do
			if entry.text == text then
				return entry.callback()
			end
		end
		error("no action " .. text)
	end

	local function height()
		return module.feed.options.layout.height
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		module = ns.Modules:Get("LootFeed")
		Designer, Layouts = module.Designer, ns.Feed.Layouts
		assert.is_true(Designer.Open())
	end)

	it("lists the layouts, the profile's one chosen, then New layout with the built-in designs, Import and Share", function()
		Layouts.Create("Raid", "compact")
		local root = openMenu()
		assert.same({
			"radio:Default*", "radio:Raid", "divider:",
			"button:|A:editmode-new-layout-plus|a |cnPURE_GREEN_COLOR:New layout|r", "button:Import", "button:Share",
		}, texts(root.entries))
		assert.same({ "button:Large", "button:Compact", "button:Minimal" }, texts(root.entries[4].entries))
		assert.same({ 2, 1 }, root.grid)
	end)

	it("starts a layout from a built-in design, named by the player, and the profile uses it", function()
		local generated = Designer.window.layouts.generated
		find("New layout").entries[2].callback()
		api.AcceptPopup("Raid")
		assert.same({ "Raid", 24 }, { Layouts.Current(), height() })
		assert.is_true(Designer.window.layouts.generated > generated)
		find("New layout").entries[1].callback()
		api.AcceptPopup("raid")
		assert.matches("already exists", ns.Compat.Test.state.printed[#ns.Compat.Test.state.printed])
	end)

	it("uses the layout chosen in it", function()
		Layouts.Create("Raid", "compact")
		local raid = layoutEntry("Raid")
		raid.setSelected(raid.data)
		assert.same({ "Raid", 24 }, { Layouts.Current(), height() })
	end)

	it("copies and renames a layout from its gear, and deletes it after a confirmation", function()
		Layouts.Create("Raid", "compact")
		local buttons = layoutEntry("Raid"):Hover()
		assert.same({ "gear", "Copy, rename or reset", "cancel", "Delete layout" }, { buttons[1].kind, buttons[1].tooltip, buttons[2].kind, buttons[2].tooltip })
		assert.same({ "button:Copy", "button:Rename", "button:Reset" }, texts(layoutEntry("Raid").entries))
		act("Raid", "Copy")
		api.AcceptPopup("Solo")
		assert.same({ "Solo", 24 }, { Layouts.Current(), height() })
		act("Solo", "Rename")
		assert.equals("Solo", api.popups[#api.popups].editBox:GetText())
		api.AcceptPopup("Dungeon")
		assert.equals("Dungeon", Layouts.Current())
		local hovered, menu = layoutEntry("Dungeon"):Hover()
		hovered[2].click()
		assert.is_true(menu.closed)
		assert.equals("Dungeon", api.popups[#api.popups].data.text_arg1)
		api.AcceptPopup()
		assert.same({ "Default", { "Default", "Raid" } }, { Layouts.Current(), Layouts.List() })
	end)

	it("can neither rename nor delete Default", function()
		assert.same({ "button:Copy", "button:Reset" }, texts(layoutEntry("Default").entries))
		local buttons = layoutEntry("Default"):Hover()
		assert.same({ 1, "Copy or reset" }, { #buttons, buttons[1].tooltip })
	end)

	it("returns the layout to its template, from its gear or with Reset beside it, after a confirmation", function()
		ns.Feed.Design.Set(Layouts.CurrentDesign(), "row", "height", 40)
		module:Apply()
		Designer.window.reset.scripts.OnClick(Designer.window.reset)
		assert.equals(40, height())
		api.AcceptPopup()
		assert.same({ 35, { schema = 1, base = "large" } }, { height(), Layouts.Get("Default") })
		ns.Feed.Design.Set(Layouts.CurrentDesign(), "row", "height", 40)
		act("Default", "Reset")
		api.AcceptPopup()
		assert.is_nil(Layouts.Get("Default").changes)
	end)

	it("opens the dialogs of layout texts with Import and Share", function()
		local opened = {}
		ns.Bus:On("OpenImportDialog", "test", function(name, mode) opened[#opened + 1] = name .. ":" .. mode end)
		ns.Bus:On("OpenShareDialog", "test", function(name, mode) opened[#opened + 1] = name .. ":" .. mode end)
		find("Import").callback()
		find("Share").callback()
		assert.same({ "OpenImportDialog:layouts", "OpenShareDialog:layouts" }, opened)
	end)

	it("follows a layout changed elsewhere", function()
		local generated = Designer.window.layouts.generated
		Layouts.Put("Default", { schema = 1, base = "minimal" })
		assert.is_true(Designer.window.layouts.generated > generated)
		assert.equals(16, height())
	end)
end)

describe("loot feed designer, opened from", function()
	it("a button on the feed's options page and in its Edit Mode dialog", function()
		local lib = { SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 } }
		function lib:AddFrame() end
		function lib:AddFrameSettings() end
		function lib:AddFrameSettingsButtons(_, buttons) self.buttons = buttons end
		function lib:RegisterCallback() end
		function lib:IsInEditMode() return false end
		rawset(_G, "LibStub", function(name) return name == "LibEditMode" and lib or nil end)
		local api = SettingsAPI.Install()
		local ns = Loader.LoadAddon({ skip = {} })
		Loader.Start(ns)
		local Designer = ns.Modules:Get("LootFeed").Designer

		local button = api.FindButton(api.FindCategory("Loot feed"), "Row design")
		button.onClick()
		assert.is_true(Designer.window.shown)
		Designer.window:Hide()
		assert.equals("Design rows", lib.buttons[1].text)
		lib.buttons[1].click()
		assert.is_true(Designer.window.shown)
	end)
end)
