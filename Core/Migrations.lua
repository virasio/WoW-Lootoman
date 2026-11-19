local _, ns = ...
local Compat = ns.Compat

-- Every saved table carries a schema version; on load, migrations bring older
-- data up to the current schema. Step n upgrades schema n - 1 to
-- n, so the current schema is the number of steps. Data without a schema is
-- treated as schema 0.
local Migrations = {}
ns.Migrations = Migrations

local function ensureTable(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

-- LootomanDB
Migrations.account = {
	-- 1: profiles (with Default), the profile of each character, account-wide settings.
	function(db)
		ensureTable(ensureTable(db, "profiles"), "Default")
		ensureTable(db, "profileKeys")
		ensureTable(db, "global")
	end,
	-- 2 (0.4): whether the loot feed shows the owned count belongs to the row
	-- layout alone. A profile that turned it off hides it in the layout it uses
	-- (hiding wins where profiles sharing a layout disagree; a profile whose
	-- layout is gone uses Default), and its own switch goes. And the feed shows at least 3 rows: the first place for an item it
	-- keeps, two more.
	function(db)
		local sections = type(db.sections) == "table" and db.sections or nil
		local layouts = sections and type(sections.feedLayouts) == "table" and sections.feedLayouts or {}
		for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
			local modules = type(profile) == "table" and type(profile.modules) == "table" and profile.modules or nil
			local feed = modules and type(modules.LootFeed) == "table" and modules.LootFeed or nil
			if feed then
				local name = type(feed.layout) == "string" and feed.layout or "Default"
				if type(layouts[name]) ~= "table" then
					name = "Default"
				end
				if feed.owned == false then
					-- Default always exists; the layouts' schema is 1.
					layouts = ensureTable(ensureTable(db, "sections"), "feedLayouts")
					local layout = ensureTable(layouts, name)
					layout.schema, layout.base = layout.schema or 1, layout.base or "large"
					local owned = ensureTable(ensureTable(layout, "changes"), "owned")
					owned.shown = false
				end
				feed.owned = nil
				if type(feed.maxRows) == "number" and feed.maxRows < 3 then
					feed.maxRows = 3
				end
				if modules and next(feed) == nil then
					modules.LootFeed = nil
				end
			end
		end
	end,
	-- 3 (0.4.5): the loot feed's settings and its row layout become a feed
	-- look, named and shared by profiles (Migrations.FeedLooks below).
	-- Junk's selling becomes one choice of three, and its large button loses
	-- its size and place (Migrations.JunkFrom below).
	function(db)
		local old = Migrations.FeedLooks(db)
		if old then
			for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
				local modules = type(profile) == "table" and type(profile.modules) == "table" and profile.modules or nil
				local junk = modules and type(modules.Junk) == "table" and modules.Junk or {}
				local values = Migrations.JunkFrom(junk)
				if next(values) then
					profile.modules = modules or {}
					profile.modules.Junk = values
				elseif modules then
					modules.Junk = nil
				end
			end
		end
	end,
	-- 4 (0.5.9): the loot feed's background gets its own switch, off by
	-- default; a look that showed one (an opacity above 0) keeps it on. And a
	-- look's size goes: a look with another size than 12 has its design's
	-- lengths scaled by it (Migrations.FoldSize), so it looks as it did.
	function(db)
		local sections = type(db.sections) == "table" and db.sections or {}
		for _, look in pairs(type(sections.feedLooks) == "table" and sections.feedLooks or {}) do
			local values = type(look) == "table" and type(look.values) == "table" and look.values or nil
			if values and type(values.backgroundOpacity) == "number" and values.backgroundOpacity > 0 then
				values.background = true
			end
			if values and values.size ~= nil then
				Migrations.FoldSize(look, values.size)
				values.size = nil
				if next(values) == nil then
					look.values = nil
				end
			end
		end
	end,
}

-- Junk's settings as 0.4 saved them in a profile or a text, as they are from
-- 0.4.5 on, keeping what 0.4 did where the defaults changed: selling at
-- once when a merchant opened (sellOnOpen, on in 0.4) becomes "auto", else
-- swapped clicks "window", else "button"; the button's style stays small, as
-- 0.4 drew it; turned off, it stays off. The large button's size and place go.
function Migrations.JunkFrom(junk)
	local values = {}
	for key, value in pairs(junk) do
		values[key] = value
	end
	values.sellOnOpen, values.swapClicks, values.tossSize, values.tossSide, values.tossOffset = nil, nil, nil, nil, nil
	local selling
	if junk.sellOnOpen ~= false then
		selling = "auto"
	elseif junk.swapClicks == true then
		selling = "window"
	else
		selling = "button"
	end
	values.selling = selling ~= "window" and selling or nil
	if junk.tossStyle ~= "large" then
		values.tossStyle = "small"
	else
		values.tossStyle = nil
	end
	return values
end

-- The loot feed's settings and their defaults as 0.4 saved them, and the
-- defaults of a feed look from 0.4.5 on (Modules/LootFeed/Looks.lua). Kept here
-- as they were, so a later change of the defaults cannot change the step.
local OLD_FEED = {
	items = true, currencies = true, money = true, reputation = true, xp = false, minQuality = 0,
	keepUsable = true, keepQuest = true, keepRecipes = true, keepContainers = true, keepPets = true,
	keepMounts = true, keepToys = true, keepSets = true, keepHeirlooms = true,
	maxRows = 8, duration = 6, fade = 1, size = 13, backgroundOpacity = 50, glow = true,
	warnGeneral = true, warnGeneralAt = 2, warnReagent = false, warnReagentAt = 2,
}
local NEW_FEED = {
	items = true, currencies = true, money = true, reputation = true, xp = true, minQuality = 0,
	keepUsable = true, keepQuest = true, keepRecipes = false, keepContainers = true, keepPets = false,
	keepMounts = false, keepToys = false, keepSets = false, keepHeirlooms = false,
	maxRows = 5, duration = 6, fade = 1, size = 12, backgroundOpacity = 0, glow = true,
	warnGeneral = true, warnGeneralAt = 3, warnReagent = true, warnReagentAt = 2,
}
-- The fill direction a look of each view starts with from 0.4.5 on.
local NEW_DIRECTION = { rows = "up", icons = "right" }
-- Whether 0.4's built-in designs showed the owned count; all of them counted
-- the bags and the bank. From 0.4.5 on none shows it, and it counts the bags only.
local OLD_OWNED_SHOWN = { large = true, compact = true, minimal = false, icons = true }
local VERTICAL = { up = true, down = true }
local DIRECTIONS = { up = true, down = true, left = true, right = true }
local MAX_LOOK_NAME = 48

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

-- A profile's loot feed values as one string, to find profiles that agree.
local function signature(values)
	local keys = {}
	for key in pairs(values) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local parts = {}
	for index, key in ipairs(keys) do
		parts[index] = key .. "=" .. tostring(values[key])
	end
	return table.concat(parts, ";")
end

-- A look's design from a 0.4 layout: its base and changes, with 0.4's owned
-- count (shown as its base showed it, counting the bags and the bank) where
-- the layout did not say otherwise.
local function designOf(layout)
	local base = type(layout.base) == "string" and layout.base or "large"
	local design = { schema = 1, base = base, changes = copy(type(layout.changes) == "table" and layout.changes or {}) }
	if type(layout.schema) == "number" and layout.schema ~= 1 then
		design.changes = {}
	end
	local owned = type(design.changes.owned) == "table" and design.changes.owned or {}
	if owned.shown == nil and OLD_OWNED_SHOWN[base] then
		owned.shown = true
	end
	if owned.count == nil then
		owned.count = "all"
	end
	design.changes.owned = owned
	return design
end

-- The values a look keeps for a profile's loot feed settings under 0.4's
-- defaults: those that differ from a look's defaults.
local function lookValues(feed, view)
	local values = {}
	for key, old in pairs(OLD_FEED) do
		local value = feed[key]
		if type(value) ~= type(old) then
			value = old
		end
		if value ~= NEW_FEED[key] then
			values[key] = value
		end
	end
	local direction, other = feed.direction, feed.otherViewDirection
	if view == "rows" then
		direction = VERTICAL[direction] and direction or (VERTICAL[other] and other or "up")
	else
		direction = DIRECTIONS[direction] and direction or "up"
	end
	if direction ~= NEW_DIRECTION[view] then
		values.direction = direction
	end
	return values
end

-- A feed look from a loot feed's settings and the row layout it used, as
-- 0.4 kept them in a profile or a profile text: the layout's design with 0.4's
-- owned count (hidden when the settings turned it off, as 0.3.5 did), and the
-- settings it showed, under 0.4's defaults, where they differ from a look's
-- defaults; at least 3 rows.
function Migrations.FeedLookFrom(feed, layout)
	feed = type(feed) == "table" and feed or {}
	layout = type(layout) == "table" and layout or { schema = 1, base = "large" }
	if feed.owned == false then
		layout = copy(layout)
		layout.changes = type(layout.changes) == "table" and layout.changes or {}
		layout.changes.owned = type(layout.changes.owned) == "table" and layout.changes.owned or {}
		layout.changes.owned.shown = false
	end
	local look = designOf(layout)
	local values = lookValues(feed, layout.base == "icons" and "icons" or "rows")
	if type(values.maxRows) == "number" and values.maxRows < 3 then
		values.maxRows = 3
	end
	look.values = next(values) and values or nil
	return look
end

-- 3: every profile's loot feed settings with the layout it used (Default
-- when its layout is gone) become a feed look. Profiles that used one
-- layout with the same settings share a look named after it; others get
-- "Layout (Profile)". Layouts that no profile used become looks with 0.4's
-- defaults, so no design is lost. The moved values leave the profiles; the
-- layouts stay saved, unread.
function Migrations.FeedLooks(db)
	-- Only data that 0.4 or older wrote: their loot feed made its layouts on
	-- its first start. A fresh install is left to the new defaults.
	local hasFeed = type(db.sections) == "table" and type(db.sections.feedLayouts) == "table"
	for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
		hasFeed = hasFeed or (type(profile) == "table" and type(profile.modules) == "table" and type(profile.modules.LootFeed) == "table")
	end
	if not hasFeed then
		return false
	end
	local sections = ensureTable(db, "sections")
	local layouts = type(sections.feedLayouts) == "table" and sections.feedLayouts or {}
	local looks = ensureTable(sections, "feedLooks")
	local groups, order = {}, {}
	local profiles = type(db.profiles) == "table" and db.profiles or {}
	local names = {}
	for name in pairs(profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, profileName in ipairs(names) do
		local profile = profiles[profileName]
		if type(profile) == "table" then
			local modules = type(profile.modules) == "table" and profile.modules or nil
			local feed = modules and type(modules.LootFeed) == "table" and modules.LootFeed or {}
			local layoutName = type(feed.layout) == "string" and type(layouts[feed.layout]) == "table" and feed.layout or "Default"
			local layout = type(layouts[layoutName]) == "table" and layouts[layoutName] or { schema = 1, base = "large" }
			local view = layout.base == "icons" and "icons" or "rows"
			local values = lookValues(feed, view)
			local key = layoutName .. "\0" .. signature(values)
			if not groups[key] then
				groups[key] = { layout = layoutName, design = designOf(layout), values = values, profiles = {} }
				order[#order + 1] = key
			end
			table.insert(groups[key].profiles, profileName)
		end
	end
	-- Per layout: the group of the profile Default keeps the layout's name,
	-- else the one most profiles used, then the first by name.
	local byLayout = {}
	for _, key in ipairs(order) do
		local group = groups[key]
		byLayout[group.layout] = byLayout[group.layout] or {}
		table.insert(byLayout[group.layout], group)
	end
	local taken = {}
	local function free(name)
		local Text = ns.Text
		name = Text.Truncate(name, MAX_LOOK_NAME)
		local candidate, number = name, 1
		while taken[Text.FoldCase(candidate)] do
			number = number + 1
			local suffix = (" %d"):format(number)
			candidate = Text.Truncate(name, MAX_LOOK_NAME - #suffix):gsub("%s+$", "") .. suffix
		end
		taken[Text.FoldCase(candidate)] = true
		return candidate
	end
	local layoutNames = {}
	for layoutName in pairs(byLayout) do
		layoutNames[#layoutNames + 1] = layoutName
	end
	table.sort(layoutNames, function(a, b)
		return a == "Default" or (b ~= "Default" and a < b)
	end)
	for _, layoutName in ipairs(layoutNames) do
		local list = byLayout[layoutName]
		table.sort(list, function(a, b)
			local aDefault, bDefault = a.profiles[1] == "Default", b.profiles[1] == "Default"
			for _, profileName in ipairs(a.profiles) do
				aDefault = aDefault or profileName == "Default"
			end
			for _, profileName in ipairs(b.profiles) do
				bDefault = bDefault or profileName == "Default"
			end
			if aDefault ~= bDefault then
				return aDefault
			elseif #a.profiles ~= #b.profiles then
				return #a.profiles > #b.profiles
			end
			return a.profiles[1] < b.profiles[1]
		end)
		for index, group in ipairs(list) do
			group.name = free(index == 1 and layoutName or ("%s (%s)"):format(layoutName, group.profiles[1]))
		end
	end
	for _, key in ipairs(order) do
		local group = groups[key]
		local look = group.design
		look.values = next(group.values) and group.values or nil
		looks[group.name] = look
		for _, profileName in ipairs(group.profiles) do
			local profile = profiles[profileName]
			local modules = type(profile.modules) == "table" and profile.modules or nil
			local feed = modules and type(modules.LootFeed) == "table" and modules.LootFeed or nil
			if feed then
				for oldKey in pairs(OLD_FEED) do
					feed[oldKey] = nil
				end
				feed.layout, feed.direction, feed.otherViewDirection = nil, nil, nil
			end
			if group.name ~= "Default" then
				profile.modules = modules or {}
				feed = feed or {}
				feed.look = group.name
				profile.modules.LootFeed = feed
			end
			if feed and next(feed) == nil and profile.modules then
				profile.modules.LootFeed = nil
			end
		end
	end
	-- Layouts no profile used.
	local layoutList = {}
	for layoutName, layout in pairs(layouts) do
		if type(layoutName) == "string" and type(layout) == "table" and not byLayout[layoutName] then
			layoutList[#layoutList + 1] = layoutName
		end
	end
	table.sort(layoutList)
	for _, layoutName in ipairs(layoutList) do
		local layout = layouts[layoutName]
		local look = designOf(layout)
		local values = lookValues({}, layout.base == "icons" and "icons" or "rows")
		look.values = next(values) and values or nil
		looks[free(layoutName)] = look
	end
	-- Default always exists.
	if type(looks.Default) ~= "table" then
		looks.Default = designOf({ schema = 1, base = "large" })
		local values = lookValues({}, "rows")
		looks.Default.values = next(values) and values or nil
	end
	return true
end

-- The lengths of the loot feed's built-in designs as 0.5.8 drew them
-- (Modules/LootFeed/Design.lua then), the parts the row's own: what a look's
-- size scaled. Kept here as they were, so the step never changes.
local BASE_LENGTHS = {
	large = { row = { height = 35, gap = 7, width = 300 }, icon = { x = 0, y = 0 },
		name = { fontSize = 13, width = 200, x = 11, y = 0 }, amount = { fontSize = 13, width = 80, x = 6, y = 0 },
		owned = { fontSize = 12, width = 40, x = -4, y = 3 } },
	compact = { row = { height = 24, gap = 3, width = 260 }, icon = { x = 0, y = 0 },
		name = { fontSize = 12, width = 180, x = 6, y = 0 }, amount = { fontSize = 12, width = 60, x = 5, y = 0 },
		owned = { fontSize = 10, width = 30, x = -2, y = 2 } },
	minimal = { row = { height = 16, gap = 2, width = 220 }, icon = { x = 0, y = 0 },
		name = { fontSize = 13, width = 180, x = 0, y = 0 }, amount = { fontSize = 13, width = 60, x = 5, y = 0 },
		owned = { fontSize = 10, width = 30, x = -2, y = 2 } },
	icons = { row = { height = 36, gap = 4, width = 36 }, icon = { x = 0, y = 0 },
		name = { fontSize = 13, width = 20, x = 0, y = 0 }, amount = { fontSize = 13, width = 60, x = -2, y = 2 },
		owned = { fontSize = 10, width = 40, x = -2, y = -2 } },
}
-- The size every look had by default, at which the feed is drawn from 0.5.9 on.
local OLD_SIZE = 12

-- A look's design ({ schema, base, changes }) with every length scaled by
-- size / 12, rounded: drawn at 12, it is as big as it was at that size. The
-- changes keep only what differs from the base.
function Migrations.FoldSize(look, size)
	local base = BASE_LENGTHS[look.base] or BASE_LENGTHS.large
	if type(size) ~= "number" or size <= 0 or size == OLD_SIZE then
		return
	end
	local factor = size / OLD_SIZE
	local changes = type(look.changes) == "table" and look.changes or {}
	for part, lengths in pairs(base) do
		local own = type(changes[part]) == "table" and changes[part] or {}
		for key, default in pairs(lengths) do
			local value = type(own[key]) == "number" and own[key] or default
			local scaled = math.floor(value * factor + 0.5)
			own[key] = scaled ~= default and scaled or nil
		end
		changes[part] = next(own) and own or nil
	end
	look.changes = next(changes) and changes or nil
	look.schema = look.schema or 1
end

-- LootomanCharDB
Migrations.character = {
	-- 1: an empty table, and (0.4.5 to 0.5.9) the session's sales log.
	function() end,
	-- 2: the sales log is gone, with the command that listed it.
	function(data)
		data.session = nil
	end,
}

-- Returns the data and a status: "new", "current", "upgraded", "newer" for
-- data saved by a later version of the addon, or "failed" when a step raised
-- an error. Newer and failed data come back untouched: the steps work on a
-- copy, so a step that breaks halfway leaves nothing half moved for the game
-- to save. The error is reported once, with the schema of the step.
function Migrations.Run(steps, data)
	local target = #steps
	local status
	if type(data) ~= "table" then
		data = {}
		status = "new"
	end
	local schema = tonumber(data.schema) or 0
	if schema > target then
		return data, "newer"
	end
	if schema == target then
		return data, status or "current"
	end
	local upgraded, version = copy(data), schema
	local ok = xpcall(function()
		for step = schema + 1, target do
			version = step
			steps[step](upgraded)
			upgraded.schema = step
		end
	end, function(err)
		Compat.ReportError(("Lootoman: the saved data could not be upgraded to schema %d and is kept as it was: %s")
			:format(version, tostring(err)))
	end)
	if not ok then
		return data, "failed"
	end
	return upgraded, status or "upgraded"
end
