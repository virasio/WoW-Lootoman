local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("loot feed look menu", function()
	local ns, api, dropdown, Looks, module

	local function openMenu()
		return api.OpenMenu(dropdown)
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

	local function lookEntry(name)
		for _, entry in ipairs(openMenu().entries) do
			if entry.kind == "radio" and entry.data == name then
				return entry
			end
		end
	end

	local function act(name, text)
		for _, entry in ipairs(lookEntry(name).entries) do
			if entry.text == text then
				return entry.callback()
			end
		end
		error("no action " .. text)
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon()
		Loader.Start(ns)
		module = ns.Modules:Get("LootFeed")
		Looks = ns.Feed.Looks
		dropdown = _G.CreateFrame("DropdownButton", nil, nil, "WowStyle1DropdownTemplate")
		dropdown:SetupMenu(ns.Feed.LookMenu.Build)
	end)

	it("lists the looks, the profile's one chosen, then New look, Import and Share", function()
		Looks.Create("Raid")
		local root = openMenu()
		assert.same({
			"radio:Default*", "radio:Raid", "divider:",
			"button:|A:editmode-new-layout-plus|a |cnPURE_GREEN_COLOR:New look|r", "button:Import", "button:Share",
		}, texts(root.entries))
		assert.same({ 2, 1 }, root.grid)
	end)

	it("starts a new look, named by the player, and the profile uses it", function()
		find("New look").callback()
		api.AcceptPopup("Raid")
		assert.same({ "Raid", { schema = 1, base = "large" } }, { Looks.Current(), Looks.Get("Raid") })
		find("New look").callback()
		api.AcceptPopup("raid")
		assert.matches("already exists", ns.Compat.Test.state.printed[#ns.Compat.Test.state.printed])
	end)

	it("uses the look chosen in it", function()
		Looks.Create("Raid")
		local raid = lookEntry("Raid")
		raid.setSelected(raid.data)
		assert.equals("Raid", Looks.Current())
	end)

	it("copies and renames a look from its gear, and deletes it after a confirmation", function()
		Looks.Create("Raid")
		Looks.Set("Raid", "maxRows", 9)
		local buttons = lookEntry("Raid"):Hover()
		assert.same({ "gear", "Edit, copy, rename or reset", "cancel", "Delete look" }, { buttons[1].kind, buttons[1].tooltip, buttons[2].kind, buttons[2].tooltip })
		assert.same({ "button:Edit", "button:Copy", "button:Rename", "button:Reset" }, texts(lookEntry("Raid").entries))
		act("Raid", "Copy")
		api.AcceptPopup("Solo")
		assert.same({ "Solo", 9 }, { Looks.Current(), module.feed.options.maxRows })
		act("Solo", "Rename")
		assert.equals("Solo", api.popups[#api.popups].editBox:GetText())
		api.AcceptPopup("Dungeon")
		assert.equals("Dungeon", Looks.Current())
		local hovered, menu = lookEntry("Dungeon"):Hover()
		hovered[2].click()
		assert.is_true(menu.closed)
		assert.equals("Dungeon", api.popups[#api.popups].data.text_arg1)
		api.AcceptPopup()
		assert.same({ "Default", { "Default", "Raid" } }, { Looks.Current(), Looks.List() })
	end)

	it("can neither rename nor delete Default", function()
		assert.same({ "button:Edit", "button:Copy", "button:Reset" }, texts(lookEntry("Default").entries))
		local buttons = lookEntry("Default"):Hover()
		assert.same({ 1, "Edit, copy or reset" }, { #buttons, buttons[1].tooltip })
	end)

	it("opens the window of a look with Edit, leaving the look the profile uses", function()
		Looks.Create("Raid")
		act("Raid", "Edit")
		local window = module.LookWindow.window
		assert.same({ true, "Raid", "Default" }, { window.shown, module.LookWindow.Edited(), Looks.Current() })
	end)

	it("returns the look to its defaults from its gear, after a confirmation", function()
		Looks.SetDesign("Default", "row", "height", 40)
		Looks.Set("Default", "maxRows", 9)
		act("Default", "Reset")
		assert.equals(9, module.feed.options.maxRows)
		api.AcceptPopup()
		assert.same({ 5, { schema = 1, base = "large" } }, { module.feed.options.maxRows, Looks.Get("Default") })
	end)

	it("opens the dialogs of look texts with Import and Share", function()
		local opened = {}
		ns.Bus:On("OpenImportDialog", "test", function(name, mode) opened[#opened + 1] = name .. ":" .. mode end)
		ns.Bus:On("OpenShareDialog", "test", function(name, mode) opened[#opened + 1] = name .. ":" .. mode end)
		find("Import").callback()
		find("Share").callback()
		assert.same({ "OpenImportDialog:looks", "OpenShareDialog:looks" }, opened)
	end)

end)

