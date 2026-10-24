local _, ns = ...

-- How a loot feed row looks (plans/0.1.md, C38, C39). A design is data: the
-- row's size and the place and size of each part, in pixels at the base size
-- 13. The size setting (10–16) scales a design, so one design fits every size.
-- Frames draws any design; the row designer (task 14) will edit them.
--
-- Parts, each with shown:
--   icon    x, y from the row's left edge and middle; size. The quality border
--           is drawn around it, a third larger, like the default UI's loot roll.
--   glow    over the icon of rare and better items
--   name    x, y from the row's left edge and middle; fontSize; width, the most
--           it may take before it is cut
--   amount  x, y from the end of the name; fontSize
--   owned   x, y from the icon's bottom-right corner; fontSize
ns.Feed = ns.Feed or {}
local Design = {}
ns.Feed.Design = Design

Design.BASE_SIZE = 13

-- The default: a big icon like the default UI's loot roll, the name and the
-- amount after it, the owned count on the icon.
Design.LARGE = {
	height = 35,
	gap = 7,
	width = 300,
	parts = {
		icon = { shown = true, x = 0, y = 0, size = 35 },
		glow = { shown = true },
		name = { shown = true, x = 46, y = 0, fontSize = 13, width = 200 },
		amount = { shown = true, x = 6, y = 0, fontSize = 13 },
		owned = { shown = true, x = -4, y = 3, fontSize = 12 },
	},
}

local function px(value, scale)
	return math.floor(value * scale + 0.5)
end

-- A design's values in pixels for a size: every length scaled and rounded.
function Design.Layout(design, size)
	local scale = size / Design.BASE_SIZE
	local layout = {
		height = px(design.height, scale),
		gap = px(design.gap, scale),
		width = px(design.width, scale),
		parts = {},
	}
	for name, part in pairs(design.parts) do
		local scaled = {}
		for key, value in pairs(part) do
			scaled[key] = type(value) == "number" and px(value, scale) or value
		end
		layout.parts[name] = scaled
	end
	return layout
end
