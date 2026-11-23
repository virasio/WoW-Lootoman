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

	it("works only with the Loot Rolls window on: greyed without it, and its turning off offers the reload", function()
		local check
		for _, item in ipairs(ns.SettingsPanel.main.items) do
			if item.text == "Hide the Game's Roll Frames" then
				check = item
			end
		end
		-- Under the window's option, further in.
		assert.equals(48, check.indent)
		ns.Storage:Set("Rolls", "liveWindow", false)
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		assert.same({ false, false, false }, { check.region.enabled, ns.Rolls.Module.GameFramesAway(), ns.Rolls.Module.HidesGameFrames() })
		assert.is_nil(Test.state.gameFramesAway)
		-- The window on again: the frames go.
		ns.Storage:Set("Rolls", "liveWindow", true)
		assert.same({ true, 1 }, { check.region.enabled, Test.state.gameFramesAway })
		ns.Storage:Set("Rolls", "liveWindow", false)
		assert.equals("The game's roll frames come back after a reload. Reload now?", settings.popups[#settings.popups].data.text)
	end)

	it("greys Show Who Rolled What and hides the panels beside the game's frames while they are away", function()
		local panels
		for _, item in ipairs(ns.SettingsPanel.main.items) do
			if item.text == "Show Who Rolled What" then
				panels = item.region
			end
		end
		assert.is_true(panels.enabled)
		ns.Storage:Set("Rolls", "hideGameFrames", true)
		assert.is_false(panels.enabled)
		-- Still greyed after turning it off, until the reload brings the frames back.
		ns.Storage:Set("Rolls", "hideGameFrames", false)
		assert.is_false(panels.enabled)
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
