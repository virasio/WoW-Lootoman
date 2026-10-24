local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("settings panel", function()
	local ns, api, built

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
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
