local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("profiles page", function()
	local ns, api, page, Profiles

	local function start(locale, saved)
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {}, locale = locale })
		ns.Modules:Register({ name = "Feed", defaults = { enabled = true, rows = 5 } })
		Loader.Start(ns, saved)
		page = api.FindCategory(ns.L["Profiles"])
		Profiles = ns.Profiles
	end

	local function click(name)
		api.FindButton(page, name).onClick()
	end

	local function options()
		local labels = {}
		for index, option in ipairs(page.initializers[1].options()) do
			labels[index] = option.value .. "=" .. option.label
		end
		return labels
	end

	before_each(function()
		start()
	end)

	it("comes after the module pages", function()
		assert.equals(page, api.categories[#api.categories])
		assert.equals(api.FindCategory("Lootoman"), page.parent)
		assert.same({
			"dropdown:Profile",
			"button:New profile",
			"button:Copy profile",
			"button:Rename profile",
			"button:Reset profile",
			"button:Delete profile",
		}, api.Kinds(page))
	end)

	it("lists the profiles, with Default in the client language", function()
		Profiles.Create("Main")
		assert.same({ "Default=Default", "Main=Main" }, options())
		start("ruRU")
		assert.same({ "Default=По умолчанию" }, options())
	end)

	it("tells Default apart from a profile with the same shown name", function()
		start("ruRU", {
			LootomanDB = { schema = 1, profiles = { Default = {}, ["По умолчанию"] = {} }, profileKeys = {}, global = {} },
		})
		assert.same({ "Default=По умолчанию (Default)", "По умолчанию=По умолчанию" }, options())
	end)

	it("switches the profile from the dropdown, and the dropdown has no default", function()
		Profiles.Create("Main")
		local dropdown = api.settings.LOOTOMAN_PROFILE
		assert.is_nil(dropdown.default)
		dropdown:SetValue("Main")
		assert.equals("Main", Profiles.GetCurrent())
		assert.equals("Main", dropdown:GetValue())
	end)

	it("creates a profile and switches to it", function()
		click("New profile")
		api.AcceptPopup("Main")
		assert.equals("Main", Profiles.GetCurrent())
		assert.equals(1, api.settings.LOOTOMAN_PROFILE.notified)
	end)

	it("copies the current profile and switches to the copy", function()
		ns.Storage:Set("Feed", "rows", 8)
		click("Copy profile")
		assert.equals("Default", api.popups[1].data.text_arg1)
		api.AcceptPopup("Copy")
		assert.equals("Copy", Profiles.GetCurrent())
		assert.equals(8, ns.Storage:Get("Feed", "rows"))
	end)

	it("renames the current profile, starting from its name", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		click("Rename profile")
		assert.equals("Main", api.popups[1].editBox:GetText())
		api.AcceptPopup("Raid")
		assert.same({ "Default", "Raid" }, Profiles.List())
	end)

	it("refuses to rename or delete Default, without a dialog", function()
		click("Rename profile")
		click("Delete profile")
		assert.same({}, api.popups)
		local printed = ns.Compat.Test.state.printed
		assert.equals(2, #printed)
		assert.matches("cannot be renamed or deleted", printed[1])
	end)

	it("resets the current profile after a confirmation", function()
		ns.Storage:Set("Feed", "rows", 8)
		click("Reset profile")
		assert.equals("Reset", api.popups[1].data.acceptText)
		assert.equals(8, ns.Storage:Get("Feed", "rows"))
		api.AcceptPopup()
		assert.equals(5, ns.Storage:Get("Feed", "rows"))
	end)

	it("deletes the current profile after a confirmation", function()
		Profiles.Create("Main")
		Profiles.Switch("Main")
		click("Delete profile")
		assert.equals("Main", api.popups[1].data.text_arg1)
		api.AcceptPopup()
		assert.same({ "Default" }, Profiles.List())
		assert.equals("Default", Profiles.GetCurrent())
	end)

	it("explains why a name is not accepted", function()
		click("New profile")
		api.AcceptPopup("   ")
		Profiles.Create("Main")
		click("New profile")
		api.AcceptPopup("main")
		local printed = ns.Compat.Test.state.printed
		assert.matches("Enter a profile name", printed[1])
		assert.matches("already exists", printed[2])
		assert.equals("Default", Profiles.GetCurrent())
	end)
end)
