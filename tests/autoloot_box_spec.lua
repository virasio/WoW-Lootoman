local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")
local UI = require("tests.mocks.UI")

describe("the game's Auto Loot box on the options page", function()
	local ns, api, Test, page, box

	local function item()
		for _, entry in ipairs(page.items) do
			if entry.region == box then
				return entry
			end
		end
	end

	-- The options window shows the page: as it opens, or as the player comes
	-- back from another options page.
	local function open()
		page.frame.OnRefresh()
	end

	-- The key dropdown's radios, "text" with a star on the chosen one; picks the
	-- one with the value pick, if given.
	local function keys(pick)
		local list = {}
		for _, entry in ipairs(UI.OpenMenu(box.key).entries) do
			list[#list + 1] = entry.text .. (entry.isSelected(entry.data) and "*" or "")
			if entry.data == pick then
				entry.setSelected(entry.data)
			end
		end
		return list
	end

	local function click(check, checked)
		check.checked = checked
		check.scripts.OnClick(check)
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		Test.state.cvars.autoLootDefault = false
		Loader.Start(ns)
		page = ns.SettingsPanel.main
		box = page.autoLootBox
		open()
	end)

	it("shows under fast autoloot's settings when Auto Loot is off as the page opens, with the game's own controls", function()
		local kinds = {}
		for index, entry in ipairs(page.items) do
			kinds[index] = entry.kind .. ":" .. tostring(entry.text)
		end
		assert.same({ "checkbox:Enable Fast Autoloot", "checkbox:Confirm Bind-on-Pickup Items when Alone", "box:" },
			{ kinds[3], kinds[4], kinds[5] })
		assert.same({ false, true, "GameFontRed" }, { item().hidden, box.shown, box.header.fontObject })
		-- One message, which points nowhere; where the game keeps the settings
		-- is in the grey line at the bottom.
		assert.equals("Auto Loot is off in the game. Fast Autoloot works only together with Auto Loot.", box.header.text)
		assert.same({ "These are standard game settings. You can find them in Options > Gameplay > Controls.", "GameFontDisableSmall", "LEFT" },
			{ box.where.text, box.where.fontObject, box.where.justify })
		assert.same({ false, "Auto Loot", "Auto Loot Key" }, { box.check.checked, box.check.label.text, box.keyLabel.text })
		assert.same({ "ALT key", "CTRL key", "SHIFT key*", "None" }, keys())
		assert.same({ "WowStyle1DropdownTemplate", 260, 30 }, { box.key.template, box.key.width, box.key.height })
		assert.is_false(box.open.shown)
	end)

	it("is not shown when Auto Loot is on as the page opens", function()
		Test.state.cvars.autoLootDefault = true
		open()
		assert.is_true(item().hidden)
	end)

	it("shows as soon as the page is shown with Auto Loot off, after it was shown with Auto Loot on", function()
		Test.state.cvars.autoLootDefault = true
		open()
		assert.is_true(item().hidden)
		-- Turned off on the game's Controls page, then back to this page.
		Test.state.cvars.autoLootDefault = false
		open()
		assert.same({ false, "GameFontRed" }, { item().hidden, box.header.fontObject })
	end)

	it("shows as soon as Auto Loot is off while the page is shown", function()
		Test.state.cvars.autoLootDefault = true
		open()
		Test.state.cvars.autoLootDefault = false
		ns.Storage:Set("AutoLoot", "confirmBind", false)
		assert.is_false(item().hidden)
	end)

	it("stays once Auto Loot is on while the page is shown, and goes when the page is shown anew", function()
		click(box.check, true)
		page:Refresh()
		assert.same({ false, "All set. Next time this box will be hidden." }, { item().hidden, box.header.text })
		open()
		assert.is_true(item().hidden)
	end)

	it("turns the game's Auto Loot on, says in white that all is set, and stays until the page opens again", function()
		click(box.check, true)
		assert.is_true(Test.state.cvars.autoLootDefault)
		assert.same({ false, true, "Loot Key" }, { item().hidden, box.check.checked, box.keyLabel.text })
		assert.same({ "All set. Next time this box will be hidden.", "GameFontHighlight" }, { box.header.text, box.header.fontObject })
		assert.matches("Options > Gameplay > Controls", box.where.text, 1, true)
		click(box.check, false)
		assert.same({ "GameFontRed", "Auto Loot Key" }, { box.header.fontObject, box.keyLabel.text })
		click(box.check, true)
		open()
		assert.is_true(item().hidden)
	end)

	it("is hidden while fast autoloot is off, whatever Auto Loot says, and asks again when it is turned on", function()
		ns.Storage:Set("AutoLoot", "enabled", false)
		assert.is_true(item().hidden)
		open()
		assert.is_true(item().hidden)
		ns.Storage:Set("AutoLoot", "enabled", true)
		assert.is_false(item().hidden)
	end)

	it("hides when fast autoloot is turned off, and stays hidden when it is turned on with Auto Loot on", function()
		click(box.check, true)
		assert.is_false(item().hidden)
		ns.Storage:Set("AutoLoot", "enabled", false)
		assert.is_true(item().hidden)
		ns.Storage:Set("AutoLoot", "enabled", true)
		assert.is_true(item().hidden)
	end)

	it("follows the switch of the profile the character changes to", function()
		ns.Profiles.Create("Quiet")
		ns.Profiles.Switch("Quiet")
		ns.Storage:Set("AutoLoot", "enabled", false)
		assert.is_true(item().hidden)
		ns.Profiles.Switch("Default")
		assert.is_false(item().hidden)
		ns.Profiles.Switch("Quiet")
		assert.is_true(item().hidden)
	end)

	it("sets the Auto Loot key and saves it with the key bindings", function()
		keys("CTRL")
		assert.same({ "CTRL", 1 }, { Test.state.modifiedClicks.AUTOLOOTTOGGLE, Test.state.savedBindings })
		assert.same({ "ALT key", "CTRL key*", "SHIFT key", "None" }, keys())
	end)

	it("changes nothing in combat, and says so", function()
		Test.SetCombat(true)
		click(box.check, true)
		keys("ALT")
		assert.same({ false, false, "SHIFT" }, { Test.state.cvars.autoLootDefault, box.check.checked, Test.state.modifiedClicks.AUTOLOOTTOGGLE })
		assert.matches("The game's Auto Loot settings can be changed out of combat.", Test.state.printed[#Test.state.printed], 1, true)
	end)

	it("offers the game's own setting where an addon may not change Auto Loot or its key", function()
		local full = item().height
		Test.state.secureCVars.autoLootDefault = true
		open()
		assert.same({ true, false, "Open the Game's Setting" }, { box.open.shown, box.check:GetParent().shown, box.open.text })
		-- The same message as with the checkbox, and the grey line under the button.
		assert.same({ "Auto Loot is off in the game. Fast Autoloot works only together with Auto Loot.", "GameFontRed" },
			{ box.header.text, box.header.fontObject })
		local top = 8 + box.header:GetStringHeight() + 8
		assert.same({ "TOPLEFT", box, "TOPLEFT", 10, -(top + 22 + 8) }, box.where.points[1])
		assert.is_true(item().height < full)
		box.open.scripts.OnClick(box.open)
		assert.same({ api.controls:GetID(), "Auto Loot" }, { api.opened, api.scrolledTo })
		-- Back from the game's page with Auto Loot on: the page is shown anew.
		Test.state.cvars.autoLootDefault = true
		open()
		assert.is_true(item().hidden)
		-- The white message, should Auto Loot come on while the page is shown.
		Test.state.cvars.autoLootDefault = false
		open()
		Test.state.cvars.autoLootDefault = true
		page:Refresh()
		assert.same({ false, "All set. Next time this box will be hidden.", "GameFontHighlight" },
			{ item().hidden, box.header.text, box.header.fontObject })
		Test.state.secureCVars.autoLootDefault = nil
		Test.state.noBindings = true
		open()
		assert.is_true(box.open.shown)
	end)

	it("fits the box to its message, its controls and the grey line", function()
		local top = 8 + box.header:GetStringHeight() + 8
		local bottom = top + 28 + 4 + 30 + 8
		assert.same({ "TOPLEFT", box, "TOPLEFT", 10, -top }, box.check:GetParent().points[1])
		assert.same({ { "TOPLEFT", box, "TOPLEFT", 10, -bottom }, { "TOPRIGHT", box, "TOPRIGHT", -10, -bottom } }, box.where.points)
		assert.equals(bottom + box.where:GetStringHeight() + 10, item().height)
	end)
end)
