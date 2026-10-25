local _, ns = ...

-- Every saved table carries a schema version; on load, migrations bring older
-- data up to the current schema (techspec §5). Step n upgrades schema n - 1 to
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
	-- 2: the loot feed's row design moves from each profile to named layouts of
	-- the whole account (plans/0.1.md, task 16). A profile's design with changes
	-- becomes a layout named after the profile, which the profile then uses
	-- (Default's becomes the layout Default, which every profile uses unless set).
	function(db)
		for name, profile in pairs(db.profiles) do
			local sections = type(profile) == "table" and type(profile.sections) == "table" and profile.sections
			local design = sections and sections.feedDesign
			if type(design) == "table" and ((type(design.changes) == "table" and next(design.changes) ~= nil)
				or (design.base ~= nil and design.base ~= "large")) then
				ensureTable(ensureTable(db, "sections"), "feedLayouts")[name] =
					{ schema = design.schema, base = design.base, changes = design.changes }
				if name ~= "Default" then
					ensureTable(ensureTable(profile, "modules"), "LootFeed").layout = name
				end
			end
			if sections then
				sections.feedDesign = nil
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
