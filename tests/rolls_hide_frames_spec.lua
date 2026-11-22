local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- Hide the Game's Roll Frames (Modules/Rolls/Rolls.lua): the game's roll
-- frames kept away, the rolls in the Loot Rolls window.

describe("hiding the game's roll frames", function()
	local ns, Test, settings

	local function start(saved, before)
		settings = SettingsAPI.Install()
		ns = Loader.LoadAddon({ gameType = "camelot", skip = {} })
		Test = ns.Compat.Test
		if before then
			before()
		end
		Loader.Start(ns, saved)
	end

	before_each(function()
		start()
	end)

	it("is an option under the loot rolls, off by default, with its note", function()
		local found
		for _, item in ipairs(ns.SettingsPanel.main.items) do
			if item.text == "Hide the Game's Roll Frames" then
				found = item
			end
		end
		assert.is_table(found)
		assert.equals("You then roll in the Loot Rolls window.", found.region.note:GetText())
		assert.is_false(ns.Storage:Get("Rolls", "hideGameFrames"))
		assert.is_nil(Test.state.gameFramesAway)
	end)

	it("keeps the game's roll frames away once, as it turns on and at the next start", function()
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		assert.same({ 1, true }, { Test.state.gameFramesAway, ns.Rolls.Module.GameFramesAway() })
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		ns.Rolls.Module.RedrawAll()
		assert.equals(1, Test.state.gameFramesAway)
		start({ LootomanDB = Test.state.saved.LootomanDB })
		assert.equals(1, Test.state.gameFramesAway)
	end)

	it("offers a reload when it is turned off, or when the loot rolls are, after the frames went", function()
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		ns.Storage:Set("Rolls", "hideGameFrames", false)
		local popup = settings.popups[#settings.popups]
		assert.same({ "GENERIC_CONFIRMATION", "The game's roll frames come back after a reload. Reload now?", "Reload" },
			{ popup.which, popup.data.text, popup.data.acceptText })
		popup.data.callback()
		assert.equals(1, Test.state.reloaded)
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		local count = #settings.popups
		ns.Modules:SetEnabled("Rolls", false)
		assert.equals(count + 1, #settings.popups)
	end)

	it("asks for nothing when the frames never went", function()
		ns.Storage:Set("Rolls", "hideGameFrames", false)
		ns.Modules:SetEnabled("Rolls", false)
		assert.same({}, settings.popups)
	end)

	it("says so on a client whose roll frames it cannot hold back, and they stay", function()
		start(nil, function()
			Test.state.gameEvent = false
		end)
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		assert.is_false(ns.Rolls.Module.GameFramesAway())
		assert.matches("cannot hold back", Test.state.printed[#Test.state.printed], 1, true)
	end)
end)
