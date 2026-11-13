local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("settings panel", function()
	local ns, api, page

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
		ns.Modules:Register({
			name = "Feed",
			title = "Loot feed",
			switchLabel = "Enable loot feed",
			description = "Shows what you loot.",
			defaults = { enabled = true, fade = false },
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
			"row:Profile", "divider",
			"checkbox:Enable loot feed",
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

	it("has no subpages", function()
		assert.same({ "Lootoman" }, { api.addOnCategories[1].name })
		assert.is_nil(api.FindCategory("Loot feed"))
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
		assert.matches("Broken.rows: the main page takes checkboxes, choices, buttons and custom blocks", ns.Compat.Test.state.errors[1])
		local last = ns.SettingsPanel.main.items[#ns.SettingsPanel.main.items]
		assert.equals("Feed", last.text)
	end)
end)

describe("settings panel main page controls", function()
	local ns, page, shownBox

	local function itemOf(text)
		for _, entry in ipairs(page.items) do
			if entry.text == text then
				return entry
			end
		end
		error("no item " .. text)
	end

	before_each(function()
		SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = { "Modules/" } })
		shownBox = true
		ns.Modules:Register({
			name = "Bin",
			title = "Junk",
			switchLabel = false,
			defaults = { enabled = true, button = "full", style = "small", selling = "auto" },
			mainSettings = {
				{ kind = "choice", key = "button", label = "Button", choices = { { "never", "Never" }, { "always", "Always" }, { "full", "Full" } } },
				{ kind = "choice", key = "style", label = "Style", level = 2, choices = { { "small", "Small" }, { "large", "Large" } },
					enabledWhen = function() return ns.Storage:Get("Bin", "button") ~= "never" end },
				{ kind = "choice", key = "selling", label = "Selling",
					choices = { { "auto", "Auto" }, { "button", "Button" }, { "window", "Window" } } },
				{ kind = "button", key = "list", label = "Junk list", click = function() ns.listOpened = true end },
				{ kind = "custom", build = function(built, indent)
					local box = built:AddBox("Watch out", 60, { indent = indent, visible = function() return shownBox end })
					box.inside = true
				end },
			},
		})
		ns.Modules:Register({ name = "Feed", switchLabel = "Show the feed", defaults = { enabled = true } })
		Loader.Start(ns)
		page = ns.SettingsPanel.main
	end)

	it("show a module without a switch under its title, its settings always to change", function()
		local list = {}
		for index, entry in ipairs(page.items) do
			list[index] = entry.kind .. ":" .. tostring(entry.text) .. ":" .. entry.indent
		end
		assert.same({ "row:Profile:0", "divider:nil:0", "title:Junk:0", "choice:Button:24", "choice:Style:48", "choice:Selling:24", "button:Junk list:24",
			"box:Watch out:24", "checkbox:Show the feed:0" }, list)
	end)

	-- The dropdown in a choice's row, and its menu's radios: "text" with a star
	-- on the chosen one.
	local function dropdownOf(text)
		local row = itemOf(text).region
		for _, frame in ipairs(Loader.ui.frames) do
			if frame.parent == row and frame.dropdown then
				return frame
			end
		end
	end

	local function radios(dropdown)
		local list = {}
		for _, entry in ipairs(require("tests.mocks.UI").OpenMenu(dropdown).entries) do
			list[#list + 1] = entry.text .. (entry.isSelected(entry.data) and "*" or "")
		end
		return list
	end

	it("bind a choice's dropdown to its setting, in the Edit Mode dialogs' style, at the rows' control column", function()
		local button = dropdownOf("Button")
		assert.same({ "WowStyle1DropdownTemplate", "Button", 260, 30 }, { button.template, itemOf("Button").region.label.text,
			button.width, button.height })
		assert.equals(ns.SettingsPanel.CONTROL_X - ns.SettingsPanel.LEFT - 24, button.points[1][4])
		assert.same({ "Never", "Always", "Full*" }, radios(button))
		require("tests.mocks.UI").OpenMenu(button).entries[1].setSelected("never")
		assert.equals("never", ns.Storage:Get("Bin", "button"))
		assert.same({ "Never*", "Always", "Full" }, radios(button))
		assert.same({ "Auto*", "Button", "Window" }, radios(dropdownOf("Selling")))
	end)

	it("grey out a control while its condition does not hold", function()
		local style = dropdownOf("Style")
		assert.is_true(style.enabled ~= false)
		ns.Storage:Set("Bin", "button", "never")
		page:Refresh()
		assert.same({ false, "GameFontDisable" }, { style.enabled, itemOf("Style").region.label.fontObject })
	end)

	it("run a button's action", function()
		local button = itemOf("Junk list").region
		button.scripts.OnClick(button)
		assert.is_true(ns.listOpened)
	end)

	it("lay the page out again when a box hides or shows", function()
		local box, feed = itemOf("Watch out"), itemOf("Show the feed")
		assert.is_true(box.region.inside)
		local below = feed.frame.points[1][5]
		shownBox = false
		page:Refresh()
		assert.same({ false, true }, { box.region.shown, feed.frame.points[1][5] > below })
		shownBox = true
		page:Refresh()
		assert.same({ true, below }, { box.region.shown, feed.frame.points[1][5] })
	end)

	it("put a row's label on the left and its control at the same place for every row", function()
		local row = page:NewRow()
		local control = _G.CreateFrame("Frame", nil, row)
		page:AddRow("Profile", control)
		assert.same({ "Profile", { "LEFT", row, "LEFT", 240, 0 } }, { row.label.text, control.points[1] })
	end)
end)
