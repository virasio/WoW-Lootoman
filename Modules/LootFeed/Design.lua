local _, ns = ...

-- How a loot feed row looks. A design is data: the
-- row's box and the parts inside it, in pixels at the base size 13. The size
-- setting (10–16) scales a design, so one design fits every size. Frames draws
-- any design; the row designer edits the player's one.
--
-- The row: height, width and gap (between rows), its view: "rows" (the
-- default), or "icons" for the compact view of icons only, and a background
-- of its own behind each row (background, its color as "rrggbb" and its
-- opacity in percent). Parts, each with shown:
--   icon                  size, in percent of the row's height
--   glow                  over the icon of rare and better items
--   name, amount, owned   texts: fontSize; width, the most a text may take;
--                         align, LEFT or RIGHT; the amount and the owned count
--                         also a background of their own (background, color
--                         and opacity, as the row's); the owned count what it
--                         counts (count: "all", bags and bank, or "bags")
-- Every part but the glow is anchored to an element (anchor: "row", "icon",
-- "name", "amount" or "owned") at one of its points (point: TOPLEFT …
-- BOTTOMRIGHT), and moved from there by x, y. The part's own point follows
-- from that (OwnPoint): a text attaches by the side of its alignment, an icon
-- inside the row or beside another element, and both by the top or bottom
-- when the chosen point is a top or bottom one.
--
-- A row is a box: Fit moves every part that sticks out back inside, and a text
-- is never wider than its maximum and the room it has to the box's edge, less
-- the texts that follow it, like the amount after the name (Arrange).
--
-- In the icons view the row is a square icon, as high as it is wide. The name
-- is never shown, and the amount and the owned count are anchored to the icon,
-- inside it or beside it: their box is the icon and one icon's size around it.
--
-- A player's design is part of a feed look (Looks.lua):
--   { schema = 1, base = "large", changes = { name = { x = 12 }, row = { height = 40 } } }
-- It keeps only the values that differ from its built-in base design, its
-- template, so later improvements to a built-in design reach every value the
-- player did not change. Changes saved under another schema are dropped.
ns.Feed = ns.Feed or {}
local Design = {}
ns.Feed.Design = Design

Design.BASE_SIZE = 13
Design.SCHEMA = 1
-- Parts move on a grid of this many design pixels.
Design.GRID = 2
-- The least room a text keeps up to the row's edge, so it cannot vanish: about
-- two digits.
Design.MIN_ROOM = 12
Design.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
Design.ELEMENTS = { "row", "icon", "name", "amount", "owned" }
Design.ALIGNS = { "LEFT", "RIGHT" }
Design.TEXTS = { name = true, amount = true, owned = true }
-- What the owned count counts: bags and bank, or the bags only.
Design.COUNTS = { "all", "bags" }
-- The parts that are anchored, in the order they are listed.
Design.PLACED = { "icon", "name", "amount", "owned" }

-- The default: a big icon like the default UI's loot roll, the name and the
-- amount after it, the owned count on the icon.
Design.LARGE = {
	height = 35,
	gap = 7,
	width = 300,
	background = false,
	color = "000000",
	opacity = 60,
	parts = {
		icon = { shown = true, size = 100, anchor = "row", point = "LEFT", x = 0, y = 0 },
		glow = { shown = true },
		name = { shown = true, fontSize = 13, width = 200, align = "LEFT", anchor = "icon", point = "RIGHT", x = 11, y = 0 },
		amount = { shown = true, fontSize = 13, width = 80, align = "LEFT", anchor = "name", point = "RIGHT", x = 6, y = 0,
			background = false, color = "000000", opacity = 60 },
		owned = { shown = false, fontSize = 12, width = 40, align = "RIGHT", anchor = "icon", point = "BOTTOMRIGHT", x = -4, y = 3,
			background = false, color = "000000", opacity = 60, count = "bags" },
	},
}

-- Close to the first version of the feed: a small icon and text.
Design.COMPACT = {
	height = 24,
	gap = 3,
	width = 260,
	background = false,
	color = "000000",
	opacity = 60,
	parts = {
		icon = { shown = true, size = 100, anchor = "row", point = "LEFT", x = 0, y = 0 },
		glow = { shown = true },
		name = { shown = true, fontSize = 12, width = 180, align = "LEFT", anchor = "icon", point = "RIGHT", x = 6, y = 0 },
		amount = { shown = true, fontSize = 12, width = 60, align = "LEFT", anchor = "name", point = "RIGHT", x = 5, y = 0,
			background = false, color = "000000", opacity = 60 },
		owned = { shown = false, fontSize = 10, width = 30, align = "RIGHT", anchor = "icon", point = "BOTTOMRIGHT", x = -2, y = 2,
			background = false, color = "000000", opacity = 60, count = "bags" },
	},
}

-- Only the name and the amount.
Design.MINIMAL = {
	height = 16,
	gap = 2,
	width = 220,
	background = false,
	color = "000000",
	opacity = 60,
	parts = {
		icon = { shown = false, size = 100, anchor = "row", point = "LEFT", x = 0, y = 0 },
		glow = { shown = false },
		name = { shown = true, fontSize = 13, width = 180, align = "LEFT", anchor = "row", point = "LEFT", x = 0, y = 0 },
		amount = { shown = true, fontSize = 13, width = 60, align = "LEFT", anchor = "name", point = "RIGHT", x = 5, y = 0,
			background = false, color = "000000", opacity = 60 },
		owned = { shown = false, fontSize = 10, width = 30, align = "RIGHT", anchor = "icon", point = "BOTTOMRIGHT", x = -2, y = 2,
			background = false, color = "000000", opacity = 60, count = "bags" },
	},
}

-- The compact view: square icons only, the amount on the bottom right corner,
-- where the bags show stack counts, and the owned count small at the top right.
Design.ICONS = {
	view = "icons",
	height = 36,
	gap = 4,
	width = 36,
	background = false,
	color = "000000",
	opacity = 60,
	parts = {
		icon = { shown = true, size = 100, anchor = "row", point = "CENTER", x = 0, y = 0 },
		glow = { shown = true },
		name = { shown = false, fontSize = 13, width = 20, align = "LEFT", anchor = "row", point = "LEFT", x = 0, y = 0 },
		amount = { shown = true, fontSize = 13, width = 60, align = "RIGHT", anchor = "icon", point = "BOTTOMRIGHT", x = -2, y = 2,
			background = false, color = "000000", opacity = 60 },
		owned = { shown = false, fontSize = 10, width = 40, align = "RIGHT", anchor = "icon", point = "TOPRIGHT", x = -2, y = -2,
			background = false, color = "000000", opacity = 60, count = "bags" },
	},
}

Design.BUILT_IN = { large = Design.LARGE, compact = Design.COMPACT, minimal = Design.MINIMAL, icons = Design.ICONS }
-- In the order the designer lists them.
Design.ORDER = { "large", "compact", "minimal", "icons" }

local TEXT_LIMITS = { fontSize = { 8, 24 }, width = { 20, 600 } }

-- The range of every number that is not a place; places keep a part inside
-- the row (Range, Fit).
Design.LIMITS = {
	row = { height = { 12, 80 }, width = { 120, 600 }, gap = { 0, 30 }, opacity = { 0, 100 } },
	icon = { size = { 20, 100 } },
	name = TEXT_LIMITS,
	amount = { fontSize = TEXT_LIMITS.fontSize, width = TEXT_LIMITS.width, opacity = { 0, 100 } },
	owned = { fontSize = { 6, 20 }, width = { 20, 600 }, opacity = { 0, 100 } },
}

-- The values that are lengths, scaled with the size setting; an icon's size is
-- a percentage and is not.
local LENGTHS = { height = true, width = true, gap = true, fontSize = true, x = true, y = true }

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = copy(item)
	end
	return result
end

local function clamp(value, low, high)
	return math.min(math.max(value, low), math.max(low, high))
end

local function horizontal(point)
	return point:match("LEFT$") and "LEFT" or point:match("RIGHT$") and "RIGHT" or ""
end

local function vertical(point)
	return point:match("^TOP") and "TOP" or point:match("^BOTTOM") and "BOTTOM" or ""
end

-- A design's view: "icons" for the compact view, else "rows".
function Design.View(design)
	return design.view == "icons" and "icons" or "rows"
end

-- The box a design's parts stay in, from the row's left edge and its middle:
-- the row, or for icons the icon and one icon's size around it.
local function boxOf(design)
	local half = design.height / 2
	if Design.View(design) == "icons" then
		local size = design.height
		return { left = -size, right = 2 * size, top = half + size, bottom = -half - size }
	end
	return { left = 0, right = design.width, top = half, bottom = -half }
end

local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", [""] = "" }

-- The point of a part that sits on its anchor's point.
function Design.OwnPoint(design, name)
	local part = design.parts[name]
	local side
	if Design.TEXTS[name] then
		side = part.align
	elseif part.anchor == "row" then
		side = horizontal(part.point)
	else
		side = OPPOSITE[horizontal(part.point)]
	end
	local point = vertical(part.point) .. side
	return point ~= "" and point or "CENTER"
end

-- Whether anchoring a part to an element keeps the anchors free of loops.
local function anchorable(design, name, element)
	local steps = 0
	while element ~= "row" do
		if element == name or steps > #Design.PLACED then
			return false
		end
		element = design.parts[element].anchor
		steps = steps + 1
	end
	return true
end

-- The elements a part may be anchored to, in the designer's order.
function Design.Targets(design, name)
	local list = {}
	for _, element in ipairs(Design.ELEMENTS) do
		if element ~= name and anchorable(design, name, element) then
			list[#list + 1] = element
		end
	end
	return list
end

-- The icon's size in the design's pixels.
function Design.IconSize(design)
	return design.parts.icon.pixels or design.height * design.parts.icon.size / 100
end

local function pointOf(rect, point)
	local side, edge = horizontal(point), vertical(point)
	local x = side == "LEFT" and rect.left or side == "RIGHT" and rect.right or (rect.left + rect.right) / 2
	local y = edge == "TOP" and rect.top or edge == "BOTTOM" and rect.bottom or (rect.top + rect.bottom) / 2
	return x, y
end

-- Where every anchored part ends up: { left, right, top, bottom, width }, from
-- the row's left edge and its middle. textWidth(name, room) gives a text's
-- width when it has room up to the box's edge.
local function arrange(design, textWidth)
	local width, height = design.width, design.height
	local box = boxOf(design)
	local rects = { row = { left = 0, right = width, top = height / 2, bottom = -height / 2 } }
	local function place(name)
		if rects[name] then
			return rects[name]
		end
		local part = design.parts[name]
		local x, y = pointOf(place(part.anchor), part.point)
		x, y = x + part.x, y + part.y
		local own = Design.OwnPoint(design, name)
		local side, edge = horizontal(own), vertical(own)
		local partWidth, partHeight
		if Design.TEXTS[name] then
			local room = side == "LEFT" and box.right - x or side == "RIGHT" and x - box.left
				or 2 * math.min(x - box.left, box.right - x)
			partWidth = math.max(0, textWidth(name, room))
			partHeight = part.fontSize
		else
			partWidth = Design.IconSize(design)
			partHeight = partWidth
		end
		local left = side == "LEFT" and x or side == "RIGHT" and x - partWidth or x - partWidth / 2
		local top = edge == "TOP" and y or edge == "BOTTOM" and y + partHeight or y + partHeight / 2
		rects[name] = { left = left, right = left + partWidth, top = top, bottom = top - partHeight, width = partWidth }
		return rects[name]
	end
	for _, name in ipairs(Design.PLACED) do
		place(name)
	end
	return rects
end

-- Where the parts of a row end up with texts of these widths (none: 0). A
-- text takes no more than its width setting and its room: up to the row's
-- edge on the side it grows to, less what follows it on that side.
function Design.Arrange(design, textWidths)
	local parts = design.parts
	-- What follows a part on a side: the parts anchored to that side of it that
	-- grow the same way, with their offsets and what follows them.
	local function tail(name, side)
		local most = 0
		for _, other in ipairs(Design.PLACED) do
			local part = parts[other]
			local width = Design.TEXTS[other] and math.min(textWidths[other] or 0, part.width)
				or (part.shown and Design.IconSize(design) or 0)
			if part.anchor == name and width > 0 and horizontal(part.point) == side
				and horizontal(Design.OwnPoint(design, other)) == OPPOSITE[side] then
				local offset = side == "RIGHT" and part.x or -part.x
				most = math.max(most, offset + width + tail(other, side))
			end
		end
		return most
	end
	return arrange(design, function(name, room)
		local side = parts[name].align == "LEFT" and "RIGHT" or "LEFT"
		return math.min(textWidths[name] or 0, parts[name].width, room - tail(name, side))
	end)
end

-- The parts in the order their anchors allow: a part after the one it is
-- anchored to.
local function anchorOrder(design)
	local order, done = {}, { row = true }
	local function visit(name)
		if not done[name] then
			done[name] = true
			visit(design.parts[name].anchor)
			order[#order + 1] = name
		end
	end
	for _, name in ipairs(Design.PLACED) do
		visit(name)
	end
	return order
end

-- The icons view's fixed parts: the row is the icon, as wide as high; no
-- name; the amount and the owned count on the icon.
local function fixIcons(design)
	local parts = design.parts
	design.width = design.height
	parts.icon.size, parts.icon.anchor, parts.icon.point, parts.icon.x, parts.icon.y = 100, "row", "CENTER", 0, 0
	parts.name.shown = false
	parts.amount.anchor, parts.owned.anchor = "icon", "icon"
end

-- Keeps a design inside its box (boxOf): sizes within their limits and the
-- box, and every part that sticks out moved back in, the parts it is anchored
-- to first. A text keeps at least MIN_ROOM up to the edge it grows to.
function Design.Fit(design)
	local parts = design.parts
	if Design.View(design) == "icons" then
		design.height = clamp(design.height, Design.LIMITS.row.height[1], Design.LIMITS.row.height[2])
		fixIcons(design)
	end
	parts.icon.size = clamp(parts.icon.size, Design.LIMITS.icon.size[1], Design.LIMITS.icon.size[2])
	local box = boxOf(design)
	for name in pairs(Design.TEXTS) do
		local part, limits = parts[name], Design.LIMITS[name]
		part.fontSize = clamp(part.fontSize, limits.fontSize[1], math.min(limits.fontSize[2], box.top - box.bottom))
		part.width = clamp(part.width, limits.width[1], math.min(limits.width[2], box.right - box.left))
	end
	local function least(name)
		return math.min(Design.MIN_ROOM, parts[name].width)
	end
	for _, name in ipairs(anchorOrder(design)) do
		local rect = arrange(design, least)[name]
		local part = parts[name]
		-- Whole pixels, so whole places stay whole.
		if rect.left < box.left then
			part.x = part.x + math.ceil(box.left - rect.left)
		elseif rect.right > box.right then
			part.x = part.x - math.ceil(rect.right - box.right)
		end
		if rect.top > box.top then
			part.y = part.y - math.ceil(rect.top - box.top)
		elseif rect.bottom < box.bottom then
			part.y = part.y + math.ceil(box.bottom - rect.bottom)
		end
	end
	return design
end

local function baseOf(section)
	return Design.BUILT_IN[section.base] or Design.LARGE
end

-- The values of a part of a design, or the design's own ones for "row".
local function valuesOf(design, part)
	if part == "row" then
		return design
	end
	return design.parts[part]
end

-- Whether a value may be set: a known key, not a table, of the same type, and
-- for the anchor, point and align one of their choices (an anchor without
-- loops).
local function valid(design, part, key, value)
	local values = valuesOf(design, part)
	if not values or values[key] == nil or type(value) == "table" or type(values[key]) ~= type(value) then
		return false
	end
	if key == "anchor" then
		return contains(Design.ELEMENTS, value) and value ~= part and anchorable(design, part, value)
	elseif key == "point" then
		return contains(Design.POINTS, value)
	elseif key == "align" then
		return contains(Design.ALIGNS, value)
	elseif key == "count" then
		return contains(Design.COUNTS, value)
	elseif key == "color" then
		return value:match("^%x%x%x%x%x%x$") ~= nil
	end
	return true
end

-- A background's color, "rrggbb", as the numbers 0 to 1 the game takes.
function Design.RGB(color)
	local r, g, b = color:match("^(%x%x)(%x%x)(%x%x)$")
	if not r then
		return 0, 0, 0
	end
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- The numbers 0 to 1 of a color, as a design keeps it: "rrggbb".
function Design.Hex(r, g, b)
	local function byte(value)
		return math.floor(math.min(math.max(value, 0), 1) * 255 + 0.5)
	end
	return ("%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The player's design: its base with the player's changes, inside its row.
-- Changes that are not valid, or from another schema, are left out.
function Design.Current(section)
	local design = copy(baseOf(section))
	if section.schema ~= Design.SCHEMA or type(section.changes) ~= "table" then
		return Design.Fit(design)
	end
	local anchors = {}
	for part, values in pairs(section.changes) do
		if type(values) == "table" and valuesOf(design, part) then
			for key, value in pairs(values) do
				if key == "anchor" then
					anchors[part] = value
				elseif valid(design, part, key, value) then
					valuesOf(design, part)[key] = value
				end
			end
		end
	end
	-- Whether an anchor makes a loop depends on the others: they are taken in
	-- rounds, as long as one more can be.
	local progress = true
	while progress do
		progress = false
		for _, part in ipairs(Design.PLACED) do
			if anchors[part] ~= nil and valid(design, part, "anchor", anchors[part]) then
				design.parts[part].anchor = anchors[part]
				anchors[part] = nil
				progress = true
			end
		end
	end
	return Design.Fit(design)
end

-- The whole numbers a value may take in a design: within its limits and, for
-- a place, as far as the part stays inside the row.
function Design.Range(design, part, key)
	if key == "x" or key == "y" then
		local function fitted(value)
			local trial = copy(design)
			trial.parts[part][key] = value
			return Design.Fit(trial).parts[part][key]
		end
		local low, high = math.ceil(fitted(-10000)), math.floor(fitted(10000))
		return low, math.max(low, high)
	end
	local limit = Design.LIMITS[part][key]
	local low, high = limit[1], limit[2]
	if Design.TEXTS[part] then
		local box = boxOf(design)
		if key == "fontSize" then
			high = math.min(high, box.top - box.bottom)
		elseif key == "width" then
			high = math.min(high, box.right - box.left)
		end
	end
	low, high = math.ceil(low), math.floor(high)
	return low, math.max(low, high)
end

-- Changes one value of the player's design. Numbers stay within their limits
-- and places inside the row; a value the design cannot take is refused with
-- an error. Returns the value as stored.
function Design.Set(section, part, key, value)
	if section.schema ~= Design.SCHEMA then
		section.changes = nil
	end
	local current = Design.Current(section)
	if not valid(current, part, key, value) then
		error(("design value %s.%s cannot be %s"):format(tostring(part), tostring(key), tostring(value)), 2)
	end
	local limit = Design.LIMITS[part] and Design.LIMITS[part][key]
	if limit then
		value = clamp(value, limit[1], limit[2])
	elseif key == "x" or key == "y" then
		value = clamp(value, Design.Range(current, part, key))
	end
	section.schema = Design.SCHEMA
	if type(section.changes) ~= "table" then
		section.changes = {}
	end
	local base = valuesOf(baseOf(section), part)
	local changes = section.changes[part] or {}
	if value == base[key] then
		changes[key] = nil
	else
		changes[key] = value
	end
	section.changes[part] = next(changes) and changes or nil
	return value
end

-- A design from a profile text, as it may be imported: its schema, base and
-- changes (Current leaves out what it cannot use); nil and "newer" for a
-- design of a newer schema.
function Design.Clean(section)
	if type(section.schema) == "number" and section.schema > Design.SCHEMA then
		return nil, "newer"
	end
	return {
		schema = type(section.schema) == "number" and section.schema or nil,
		base = Design.BUILT_IN[section.base] and section.base or nil,
		changes = type(section.changes) == "table" and section.changes or nil,
	}
end

-- Drops the player's changes to the built-in design.
function Design.Reset(section)
	section.changes = nil
end

-- Moving a part with the mouse. Returns move(dx, dy): the distance the
-- pointer went since the drag began, in screen pixels, with scale screen
-- pixels to a design pixel; the part goes there on the grid.
function Design.Drag(section, part, scale)
	local start = Design.Current(section).parts[part]
	-- Halves round away from zero, so up and down, left and right feel alike.
	local function snap(distance)
		local steps = distance / scale / Design.GRID
		steps = steps >= 0 and math.floor(steps + 0.5) or -math.floor(-steps + 0.5)
		return steps * Design.GRID
	end
	return function(dx, dy)
		Design.Set(section, part, "x", start.x + snap(dx))
		Design.Set(section, part, "y", start.y + snap(dy))
	end
end

local function px(value, scale)
	return math.floor(value * scale + 0.5)
end

-- A design's values in pixels for a size: every length scaled and rounded, and
-- the icon's size in pixels worked out from the row's height (icon.pixels).
function Design.Layout(design, size)
	local scale = size / Design.BASE_SIZE
	local layout = { parts = {} }
	for key, value in pairs(design) do
		if key ~= "parts" then
			layout[key] = LENGTHS[key] and px(value, scale) or value
		end
	end
	for name, part in pairs(design.parts) do
		local scaled = {}
		for key, value in pairs(part) do
			scaled[key] = LENGTHS[key] and px(value, scale) or value
		end
		layout.parts[name] = scaled
	end
	layout.parts.icon.pixels = math.floor(layout.height * design.parts.icon.size / 100 + 0.5)
	return layout
end
