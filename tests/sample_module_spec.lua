local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The dev-only sample module, with just enough of a frame for it to run.
describe("sample module (debug builds)", function()
	local ns, api, frames

	before_each(function()
		frames = {}
		rawset(_G, "UIParent", {})
		rawset(_G, "CreateFrame", function()
			local frame = { shown = true }
			function frame:SetSize() end
			function frame:SetPoint() end
			function frame:Show() self.shown = true end
			function frame:Hide() self.shown = false end
			function frame:CreateFontString()
				return { SetAllPoints = function() end, SetText = function() end }
			end
			frames[#frames + 1] = frame
			return frame
		end)
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {}, debug = true })
		Loader.Start(ns)
	end)

	it("is off by default and has its own settings page", function()
		local sample = ns.Modules:Get("Sample")
		assert.is_false(sample:IsActive())
		assert.same({ "checkbox:Enabled", "checkbox:Report bag updates" }, api.Kinds(api.FindCategory("Sample module (dev)")))
	end)

	it("shows its frame and listens to bag updates only while on", function()
		local sample = ns.Modules:Get("Sample")
		ns.Modules:SetEnabled("Sample", true)
		assert.equals(1, #frames)
		assert.is_true(frames[1].shown)
		assert.same({ "BAG_UPDATE_DELAYED" }, ns.Bus:GetEvents(sample))

		ns.Modules:SetEnabled("Sample", false)
		assert.is_false(frames[1].shown)
		assert.same({}, ns.Bus:GetEvents(sample))

		ns.Modules:SetEnabled("Sample", true)
		assert.equals(1, #frames)
	end)

	it("reports bag updates in debug messages", function()
		ns.Modules:SetEnabled("Sample", true)
		ns.Storage:SetGlobal("debug", true)
		ns.Compat.Test.FireEvent("BAG_UPDATE_DELAYED")
		local printed = ns.Compat.Test.state.printed
		assert.matches("bags updated", printed[#printed])
	end)

	it("creates its frame only after combat", function()
		ns.Compat.Test.SetCombat(true)
		ns.Modules:SetEnabled("Sample", true)
		assert.equals(0, #frames)
		ns.Compat.Test.SetCombat(false)
		assert.equals(1, #frames)
	end)
end)
