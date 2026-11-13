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

	-- The options panel shows the page.
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
		assert.same({ "checkbox:Enable fast autoloot", "checkbox:Confirm bind-on-pickup items when alone", "box:" },
			{ kinds[3], kinds[4], kinds[5] })
		assert.same({ false, true, "GameFontRed" }, { item().hidden, box.shown, box.header.fontObject })
		assert.equals("Auto Loot is off in the game's settings. For the best experience, turn it on: Options > Gameplay > Controls > Auto Loot, or hold SHIFT key while looting.",
			box.header.text)
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

	it("turns the game's Auto Loot on and stays until the page opens again", function()
		click(box.check, true)
		assert.is_true(Test.state.cvars.autoLootDefault)
		assert.same({ false, true, "Loot Key" }, { item().hidden, box.check.checked, box.keyLabel.text })
		open()
		assert.is_true(item().hidden)
	end)

	it("sets the Auto Loot key and saves it with the key bindings", function()
		keys("CTRL")
		assert.same({ "CTRL", 1 }, { Test.state.modifiedClicks.AUTOLOOTTOGGLE, Test.state.savedBindings })
		assert.matches("hold CTRL key while looting", box.header.text, 1, true)
		keys("NONE")
		assert.equals("Auto Loot is off in the game's settings. For the best experience, turn it on: Options > Gameplay > Controls > Auto Loot.",
			box.header.text)
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
		assert.same({ true, false }, { box.open.shown, box.check:GetParent().shown })
		assert.is_true(item().height < full)
		box.open.scripts.OnClick(box.open)
		assert.same({ api.controls:GetID(), "Auto Loot" }, { api.opened, api.scrolledTo })
		Test.state.secureCVars.autoLootDefault = nil
		Test.state.noBindings = true
		open()
		assert.is_true(box.open.shown)
	end)

	it("fits the box to its header and controls", function()
		local top = 8 + box.header:GetStringHeight() + 8
		assert.same({ "TOPLEFT", box, "TOPLEFT", 10, -top }, box.check:GetParent().points[1])
		assert.equals(top + 28 + 4 + 30 + 10, item().height)
	end)
end)
