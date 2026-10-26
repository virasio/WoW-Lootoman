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
