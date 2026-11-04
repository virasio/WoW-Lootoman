local _, ns = ...
local L = ns.L

-- The free-slot bar: the bags' free space as one line of text, in the
-- player's own format and colours (Template.lua).
ns.Modules:Register({
	name = "FreeSlots",
	title = L["Free slots"],
	switchLabel = L["Enable the free-slot bar"],
	description = L["Shows the free slots of your bags as text, in your own format and colours."],
	defaults = {
		enabled = true,
		template = "{free|33ff33} ({reagent|ffd100}) / {general}",
		color = "ffffffff",
		size = 14,
		broker = true,
	},
})
