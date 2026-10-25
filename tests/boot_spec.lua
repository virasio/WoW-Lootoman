local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The whole addon starts on every client it supports, as the release package
-- has it (without the development files) and as the repository has it (with
-- them), options included: a wrong TOC order or a missing file fails here.
describe("the addon", function()
	for _, gameType in ipairs({ "standard", "camelot" }) do
		for _, debug in ipairs({ false, true }) do
			local files = debug and "with the development files" or "as packaged"
			it(("starts on the %s client %s"):format(gameType, files), function()
				SettingsAPI.Install()
				rawset(_G, "StaticPopup_Hide", function() end)
				local ns = Loader.LoadAddon({ gameType = gameType, debug = debug, skip = {} })
				local ready = false
				ns.Bus:On("Ready", "test", function() ready = true end)
				Loader.Start(ns)
				assert.is_true(ready)
				assert.same({}, ns.Compat.Test.state.errors)
				assert.is_table(ns.SettingsPanel.main)
				for _, module in ipairs(ns.Modules:List()) do
					assert.is_true(module:IsActive(), module.name .. " did not start")
				end
			end)
		end
	end
end)
