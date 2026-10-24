local _, ns = ...

-- Exists only when the addon runs from the repository: the packager removes
-- the #@debug@ block from the TOC. It lets us check the module lifecycle in the
-- game before real modules exist. When on, it shows a small frame and reports
-- bag updates in debug messages. Development text is not translated.
local Sample = ns.Modules:Register({
	name = "Sample",
	title = "Sample module (dev)",
	description = "Development only: shows a small frame and reports bag updates in debug messages.",
	defaults = { enabled = false, verbose = true },
})

function Sample:OnEnable()
	if not self.frame then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(240, 24)
		frame:SetPoint("TOP", 0, -120)
		local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetAllPoints()
		text:SetText("Lootoman sample module")
		self.frame = frame
		ns.Debug("Sample module: frame created")
	end
	self.frame:Show()
	self:OnEvent("BAG_UPDATE_DELAYED", function()
		if self:Get("verbose") then
			ns.Debug("Sample module: bags updated")
		end
	end)
end

function Sample:OnDisable()
	if self.frame then
		self.frame:Hide()
	end
end

function Sample:BuildSettings(category)
	ns.SettingsPanel.AddCheckbox(category, self.name, "verbose", "Report bag updates",
		"Prints a debug message on every bag update. Needs /lootoman debug on.")
end
