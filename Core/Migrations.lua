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
	-- 2 (0.4): one switch for the loot feed's owned count, the profile's. A row
	-- layout that hid its owned part turns the owned count off in every profile
	-- that uses it, and layouts no longer keep that part's switch. And the feed
	-- shows at least 3 rows: the first place for an item it keeps, two more.
	function(db)
		local sections = type(db.sections) == "table" and db.sections or {}
		local layouts = type(sections.feedLayouts) == "table" and sections.feedLayouts or {}
		local function ownedChanges(layout)
			local changes = type(layout) == "table" and type(layout.changes) == "table" and layout.changes or nil
			return changes and type(changes.owned) == "table" and changes.owned or nil, changes
		end
		for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
			if type(profile) == "table" then
				local modules = type(profile.modules) == "table" and profile.modules or nil
				local feed = modules and type(modules.LootFeed) == "table" and modules.LootFeed or nil
				local owned = ownedChanges(layouts[feed and type(feed.layout) == "string" and feed.layout or "Default"])
				if owned and owned.shown == false then
					profile.modules = modules or {}
					profile.modules.LootFeed = feed or {}
					profile.modules.LootFeed.owned = false
				end
				if feed and type(feed.maxRows) == "number" and feed.maxRows < 3 then
					feed.maxRows = 3
				end
			end
		end
		for _, layout in pairs(layouts) do
			local owned, changes = ownedChanges(layout)
			if owned and changes then
				owned.shown = nil
				if next(owned) == nil then
					changes.owned = nil
				end
				if next(changes) == nil then
					layout.changes = nil
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
