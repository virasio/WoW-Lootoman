local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("profile control", function()
	local ns, api, main, dropdown, Profiles

	local function start(locale, saved)
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {}, locale = locale })
		ns.Modules:Register({ name = "Feed", defaults = { enabled = true, rows = 5 } })
		Loader.Start(ns, saved)
		main = api.FindCategory("Lootoman")
		dropdown = ns.SettingsPanel.main.profile
		Profiles = ns.Profiles
	end

	-- The profiles in the menu as "stored name=shown name", the chosen one with a star.
	local function profiles()
		local list = {}
		for _, entry in ipairs(api.OpenMenu(dropdown).entries) do
			if entry.kind == "radio" then
				list[#list + 1] = entry.data .. "=" .. entry.text .. (entry.isSelected(entry.data) and "*" or "")
			end
		end
		return list
	end

	local function profile(name)
		for _, entry in ipairs(api.OpenMenu(dropdown).entries) do
			if entry.kind == "radio" and entry.data == name then
				return entry
			end
		end
	end

	local function texts(entries)
		local list = {}
		for index, entry in ipairs(entries) do
			list[index] = entry.text or entry.kind
		end
		return list
	end

	-- Clicks an action in a profile's gear submenu.
	local function act(name, label)
		for _, entry in ipairs(profile(name).entries) do
			if entry.text == label then
				return entry.callback()
			end
		end
		error("no action " .. label)
	end

	local function newProfile()
		local entries = api.OpenMenu(dropdown).entries
		entries[#entries].callback()
	end

	before_each(function()
		start()
	end)

	-- Plays the pointer entering a frame: its OnEnter hooks.
	local function hover(frame)
		for _, hook in ipairs(frame.hooks.OnEnter) do
			hook(frame)
		end
	end

	it("sits on top of the main page: the label, the dropdown under it, then the module switches", function()
		local page = ns.SettingsPanel.main
		assert.same({ "label", "Profile" }, { page.items[1].kind, page.items[1].text })
		assert.same({ "dropdown", dropdown, "divider" }, { page.items[2].kind, page.items[2].region, page.items[3].kind })
		assert.same({ "checkbox", 0 }, { page.items[4].kind, page.items[4].indent })
		assert.is_nil(api.FindCategory("Profiles"))
		hover(dropdown)
		assert.same({ dropdown, true, "Profile", "The profile this character uses. Every character can use its own profile." },
			{ api.tooltip.owner, api.tooltip.shown, api.tooltip.lines[1], api.tooltip.lines[2] })
	end)

	it("has Reset right of the dropdown, for the current profile", function()
		local reset = ns.SettingsPanel.main.reset
		assert.same({ "Reset", { "LEFT", dropdown, "RIGHT", 8, 0 } }, { reset.text, reset.points[1] })
		hover(reset)
		assert.same({ "Reset", "Resets the current profile to the default settings." }, api.tooltip.lines)
		Profiles.Create("Main")
		Profiles.Switch("Main")
		ns.Storage:Set("Feed", "rows", 8)
		reset.scripts.OnClick(reset)
		assert.equals("Main", api.popups[1].data.text_arg1)
		api.AcceptPopup()
		assert.equals(5, ns.Storage:Get("Feed", "rows"))
	end)

	it("hides Blizzard's Defaults button on Lootoman's pages, and only there", function()
		local defaults = api.defaultsButton
		api.SelectCategory(main)
		assert.is_false(defaults.shown)
		api.SelectCategory({ GetParentCategory = function() return nil end })
		assert.is_true(defaults.shown)
		api.SelectCategory(assert(api.FindCategory("Loot feed")))
		assert.is_false(defaults.shown)
		-- Blizzard shows it again when a search is cleared.
		defaults:Show()
		assert.is_false(defaults.shown)
	end)

	it("lists the profiles in one column, the chosen one marked, with Default in the client language", function()
		Profiles.Create("Main")
		assert.same({ "Default=Default*", "Main=Main" }, profiles())
		assert.same({ 2, 1 }, api.OpenMenu(dropdown).grid)
		start("ruRU")
		assert.same({ "Default=По умолчанию*" }, profiles())
	end)

	it("tells Default apart from a profile with the same shown name", function()
		start("ruRU", {
			LootomanDB = { schema = 1, profiles = { Default = {}, ["По умолчанию"] = {} }, profileKeys = {}, global = {} },
		})
		assert.same({ "Default=По умолчанию (Default)*", "По умолчанию=По умолчанию" }, profiles())
	end)

	it("switches to the profile chosen in the menu, and shows its name after a switch made anywhere", function()
		Profiles.Create("Main")
		local mainProfile = profile("Main")
		local generated = dropdown.generated
		mainProfile.setSelected(mainProfile.data)
		assert.equals("Main", Profiles.GetCurrent())
		assert.same({ "Default=Default", "Main=Main*" }, profiles())
		assert.equals(generated + 1, dropdown.generated)
	end)

	it("shows a gear and a delete button over a profile, and the gear opens its actions", function()
		Profiles.Create("Main")
		local mainProfile = profile("Main")
		assert.is_true(mainProfile.submenuDeactivated)
		assert.same({ "Copy", "Rename", "Reset" }, texts(mainProfile.entries))
		assert.same({ "Rename", "Renames this profile for every character that uses it." }, mainProfile.entries[2]:TooltipLines())
		local buttons = mainProfile:Hover()
		local gear, delete = buttons[1], buttons[2]
		assert.same({ "gear", "Copy, rename or reset", "gear anchor" }, { gear.kind, gear.tooltip, gear.anchor[1] })
		-- The delete button sits left of the gear.
		assert.same({ "cancel", "Delete profile", "cancel anchor", gear }, { delete.kind, delete.tooltip, delete.anchor[1], delete.anchor[2] })
		gear.click()
		assert.is_true(mainProfile.submenuOpened)
	end)

	it("can neither rename nor delete Default", function()
		local default = profile("Default")
		assert.same({ "Copy", "Reset" }, texts(default.entries))
		local buttons = default:Hover()
		assert.same({ 1, "Copy or reset" }, { #buttons, buttons[1].tooltip })
	end)

	it("creates a profile from the last menu entry, after a divider, and switches to it", function()
		local entries = api.OpenMenu(dropdown).entries
		assert.same({ "radio", "divider", "button" }, { entries[1].kind, entries[2].kind, entries[3].kind })
		assert.equals("|A:editmode-new-layout-plus|a |cnPURE_GREEN_COLOR:New profile|r", entries[3].text)
		newProfile()
		api.AcceptPopup("Main")
		assert.equals("Main", Profiles.GetCurrent())
	end)

	it("copies a profile, also one this character does not use, and switches to the copy", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		ns.Storage:Set("Feed", "rows", 8)
		Profiles.Switch("Default")
		act("Main", "Copy")
		assert.equals("Main", api.popups[1].data.text_arg1)
		api.AcceptPopup("Copy")
		assert.equals("Copy", Profiles.GetCurrent())
		assert.equals(8, ns.Storage:Get("Feed", "rows"))
	end)

	it("renames a profile, starting from its name", function()
		Profiles.Create("Main")
		act("Main", "Rename")
		assert.equals("Main", api.popups[1].editBox:GetText())
		api.AcceptPopup("Raid")
		assert.same({ "Default", "Raid" }, Profiles.List())
		assert.equals("Default", Profiles.GetCurrent())
	end)

	it("resets a profile after a confirmation", function()
		ns.Storage:Set("Feed", "rows", 8)
		act("Default", "Reset")
		assert.equals("Reset", api.popups[1].data.acceptText)
		assert.equals(8, ns.Storage:Get("Feed", "rows"))
		api.AcceptPopup()
		assert.equals(5, ns.Storage:Get("Feed", "rows"))
	end)

	it("deletes a profile with its delete button after a confirmation, and closes the menu", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		local buttons, menu = profile("Main"):Hover()
		buttons[2].click()
		assert.is_true(menu.closed)
		assert.equals("Main", api.popups[1].data.text_arg1)
		api.AcceptPopup()
		assert.same({ "Default" }, Profiles.List())
		assert.equals("Default", Profiles.GetCurrent())
	end)

	it("explains why a name is not accepted", function()
		newProfile()
		api.AcceptPopup("   ")
		Profiles.Create("Main")
		newProfile()
		api.AcceptPopup("main")
		local printed = ns.Compat.Test.state.printed
		assert.matches("Enter a profile name", printed[1])
		assert.matches("already exists", printed[2])
		assert.equals("Default", Profiles.GetCurrent())
	end)
end)
