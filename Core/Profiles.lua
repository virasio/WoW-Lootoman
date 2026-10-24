local _, ns = ...
local Bus, Storage = ns.Bus, ns.Storage

-- Named sets of settings (techspec §7.1). Each character uses one profile;
-- characters without one use Default, which cannot be renamed or deleted.
--
-- Functions that can fail return nil and an error code: "empty", "too_long",
-- "exists", "missing" or "default". ProfileChanged(newName, oldName) is sent
-- whenever the settings of the current character may have changed.
local Profiles = {
	MAX_NAME_LENGTH = 48,
}
ns.Profiles = Profiles

local DEFAULT = Storage.DEFAULT_PROFILE

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Characters, not bytes: Cyrillic letters take two bytes in UTF-8.
local function length(text)
	return select(2, text:gsub("[^\128-\191]", ""))
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Profile names are unique regardless of letter case.
local function findName(name)
	local lower = name:lower()
	for existing in pairs(Storage.db.profiles) do
		if existing:lower() == lower then
			return existing
		end
	end
end

local function validate(name, renaming)
	name = trim(name or "")
	if name == "" then
		return nil, "empty"
	end
	if length(name) > Profiles.MAX_NAME_LENGTH then
		return nil, "too_long"
	end
	local existing = findName(name)
	if existing and existing ~= renaming then
		return nil, "exists"
	end
	return name
end

-- Default first, then the others in alphabetical order.
function Profiles.List()
	local names = {}
	for name in pairs(Storage.db.profiles) do
		if name ~= DEFAULT then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	table.insert(names, 1, DEFAULT)
	return names
end

function Profiles.GetCurrent()
	return Storage:GetProfileName()
end

function Profiles.Exists(name)
	return Storage.db.profiles[name] ~= nil
end

function Profiles.Create(name)
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	Storage.db.profiles[valid] = {}
	return valid
end

function Profiles.Copy(source, name)
	if not Profiles.Exists(source) then
		return nil, "missing"
	end
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	Storage.db.profiles[valid] = deepCopy(Storage.db.profiles[source])
	return valid
end

function Profiles.Switch(name)
	if not Profiles.Exists(name) then
		return nil, "missing"
	end
	local old = Profiles.GetCurrent()
	Storage.db.profileKeys[Storage.character] = name ~= DEFAULT and name or nil
	if name ~= old then
		Bus:Send("ProfileChanged", name, old)
	end
	return true
end

function Profiles.Rename(old, name)
	if old == DEFAULT then
		return nil, "default"
	end
	if not Profiles.Exists(old) then
		return nil, "missing"
	end
	local valid, err = validate(name, old)
	if not valid then
		return nil, err
	end
	if valid == old then
		return valid
	end
	local current = Profiles.GetCurrent()
	local db = Storage.db
	db.profiles[valid], db.profiles[old] = db.profiles[old], nil
	for character, profile in pairs(db.profileKeys) do
		if profile == old then
			db.profileKeys[character] = valid
		end
	end
	if current == old then
		Bus:Send("ProfileChanged", valid, old)
	end
	return valid
end

function Profiles.Reset(name)
	if not Profiles.Exists(name) then
		return nil, "missing"
	end
	Storage.db.profiles[name] = {}
	if name == Profiles.GetCurrent() then
		Bus:Send("ProfileChanged", name, name)
	end
	return true
end

-- Characters that used the deleted profile move to Default.
function Profiles.Delete(name)
	if name == DEFAULT then
		return nil, "default"
	end
	if not Profiles.Exists(name) then
		return nil, "missing"
	end
	local current = Profiles.GetCurrent()
	local db = Storage.db
	db.profiles[name] = nil
	for character, profile in pairs(db.profileKeys) do
		if profile == name then
			db.profileKeys[character] = nil
		end
	end
	if current == name then
		Bus:Send("ProfileChanged", DEFAULT, name)
	end
	return true
end
