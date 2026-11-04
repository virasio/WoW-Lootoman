local _, ns = ...
local L = ns.L

-- Bars of currencies and of items in the bags, anywhere on the screen. They
-- come in named sets shared by every profile (Sets.lua); each profile uses one.
ns.Modules:Register({
	name = "Bars",
	title = L["Currency bars"],
	switchLabel = L["Enable currency bars"],
	description = L["Bars of currencies and of items in your bags, anywhere on the screen."],
	defaults = {
		enabled = true,
		-- The named set of bars the profile uses (Sets.lua).
		set = "Default",
	},
})
