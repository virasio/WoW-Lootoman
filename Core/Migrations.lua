local _, ns = ...

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
}

-- LootomanCharDB
Migrations.character = {
	-- 1: an empty table; per-character data arrives with later releases.
	function() end,
}

-- Returns the data and a status: "new", "current", "upgraded", or "newer" for
-- data saved by a later version of the addon, which is returned untouched.
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
	for version = schema + 1, target do
		steps[version](data)
		data.schema = version
	end
	return data, status or "upgraded"
end
