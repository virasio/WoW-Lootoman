local _, ns = ...
local Bus, Compat, L, Modules, Profiles, Storage, Text = ns.Bus, ns.Compat, ns.L, ns.Modules, ns.Profiles, ns.Storage, ns.Text

-- Profile texts (techspec §7.1; plans/0.1.md, task 16): parts of the current
-- profile and named items of the whole account as one line of text to copy,
-- and such a text read back.
--
-- Parts: each module's settings ("module:LootFeed": the values that differ
-- from the defaults), and parts under a module, registered by their owners
-- with Share.RegisterPart: the loot feed's position, the layout it uses. A
-- part under a module can be taken only with the module's settings; a part
-- can also need an item of a collection (Use layout needs that layout).
-- Collections: named items of the whole account, registered with
-- Share.RegisterCollection: the loot feed's layouts. On import, an item whose
-- name is taken is kept as both, replaces the player's, or is left for the
-- player's ("both", "replace", "keep").
--
-- The text is "LTM1:" and the encoded table { format = 1, addon = <version>,
-- sections = { [part] = data }, collections = { [collection] = { [item] =
-- data } } } (Compat.Encode).
--
-- Reading never trusts the text: it must be plain data (no deeper than
-- MAX_DEPTH, no more than MAX_VALUES values); a module setting must be known,
-- of its default's type and, where the module checks it (module:Validate), a
-- value its controls can set; other parts and items go through their owner's
-- clean function. What does not pass is left out and counted.
local Share = {
	PREFIX = "LTM",
	FORMAT = 1,
	MAX_LENGTH = 100000,
	MAX_DEPTH = 7,
	MAX_VALUES = 5000,
}
ns.Share = Share

local MODULE_PREFIX = "module:"

local parts, partsByName = {}, {}
local collections, collectionsByName = {}, {}

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

-- A part under a module's settings:
--   name        unique, such as "positions:LootFeed"
--   module      the module's name
--   label       text, or function(data) returning it
--   get(profile)                   its data in a profile table, or nil
--   set(profile, data, renamed)    puts data into a profile table; renamed maps
--                                  imported items to the player's names:
--                                  renamed[collection][item]
--   clean(data)                    what may be imported, or nil
--   owns        optional: a module setting only this part carries
--   needs(data) optional: the collection and item it needs, as two values
function Share.RegisterPart(part)
	assert(not partsByName[part.name], "part " .. tostring(part.name) .. " is already registered")
	parts[#parts + 1] = part
	partsByName[part.name] = part
end

-- Named items of the whole account:
--   name, label
--   list()                 the names, in the order to show them
--   get(name)              an item's data
--   taken(name)            the player's name that an imported one clashes with
--   freeName(name)         a free name like it ("Name 2")
--   put(name, data)        stores an item, new or in place of one
--   display(name)          its name as shown
--   clean(data)            what may be imported, or nil and "newer"
function Share.RegisterCollection(collection)
	assert(not collectionsByName[collection.name], "collection " .. tostring(collection.name) .. " is already registered")
	collections[#collections + 1] = collection
	collectionsByName[collection.name] = collection
end

function Share.GetCollection(name)
	return collectionsByName[name]
end

function Share.Collections()
	return collections
end

local function moduleOf(name)
	local moduleName = name:match("^" .. MODULE_PREFIX .. "(.+)$")
	return moduleName and Modules:Get(moduleName)
end

-- The settings a module part leaves to the parts under it.
local function owned(moduleName)
	local keys = {}
	for _, part in ipairs(parts) do
		if part.module == moduleName and part.owns then
			keys[part.owns] = true
		end
	end
	return keys
end

-- Every part, in order: { name, module, parent }: a module's settings, then
-- the parts under it, whose parent is the module part's name.
function Share.Parts()
	local list = {}
	for _, module in ipairs(Modules:List()) do
		local parent = MODULE_PREFIX .. module.name
		list[#list + 1] = { name = parent, module = module.name }
		for _, part in ipairs(parts) do
			if part.module == module.name then
				list[#list + 1] = { name = part.name, module = module.name, parent = parent }
			end
		end
	end
	return list
end

-- The label of a part with its data.
function Share.Label(name, data)
	local module = moduleOf(name)
	if module then
		return L["%s settings"]:format(module.title)
	end
	local part = partsByName[name]
	if not part then
		return name
	end
	if type(part.label) == "function" then
		return part.label(data or {})
	end
	return part.label
end

-- The collection and item a part with this data needs, if any.
function Share.Needs(name, data)
	local part = partsByName[name]
	if part and part.needs and data then
		return part.needs(data)
	end
end

-- A part's data in the current profile.
function Share.Get(name)
	local profile = Storage:GetProfile()
	local module = moduleOf(name)
	if module then
		local values = deepCopy(type(profile.modules) == "table" and profile.modules[module.name] or nil) or {}
		for key in pairs(owned(module.name)) do
			values[key] = nil
		end
		return values
	end
	local part = partsByName[name]
	return part and part.get(profile) or nil
end

-- The text of the current profile's parts with these names and of these
-- items: choice = { parts = { name, … }, collections = { [collection] = {
-- item, … } } }. Or nil and "encoder" when the client cannot make one.
function Share.Export(choice)
	local data = {
		format = Share.FORMAT,
		addon = Compat.GetAddOnMetadata("Lootoman", "Version"),
		sections = {},
		collections = {},
	}
	for _, name in ipairs(choice.parts or {}) do
		data.sections[name] = Share.Get(name) or {}
	end
	for collectionName, names in pairs(choice.collections or {}) do
		local collection = collectionsByName[collectionName]
		local items = {}
		for _, name in ipairs(names) do
			items[name] = deepCopy(collection.get(name))
		end
		data.collections[collectionName] = items
	end
	local encoded = Compat.Encode(data)
	if not encoded then
		return nil, "encoder"
	end
	return ("%s%d:%s"):format(Share.PREFIX, Share.FORMAT, encoded)
end

local function isNumber(value)
	-- Not NaN and not infinite.
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Whether a value is plain data a profile can hold, within the limits.
local function plain(value, depth, budget)
	budget.left = budget.left - 1
	if budget.left < 0 then
		return false
	end
	local kind = type(value)
	if kind == "boolean" or kind == "string" then
		return true
	elseif kind == "number" then
		return isNumber(value)
	elseif kind ~= "table" or depth > Share.MAX_DEPTH then
		return false
	end
	for key, item in pairs(value) do
		if not (type(key) == "string" or isNumber(key)) or not plain(item, depth + 1, budget) then
			return false
		end
	end
	return true
end

-- A module's settings as they may be imported; result.skipped counts what is
-- left out. Settings that its parts own are left to them.
local function cleanModule(module, data, result)
	local values = {}
	local defaults, owns = Storage.defaults[module.name], owned(module.name)
	for key, value in pairs(data) do
		local default
		if type(key) == "string" and not owns[key] then
			default = defaults[key]
		end
		if default ~= nil and type(value) == type(default)
			and (not module.Validate or module:Validate(key, value)) then
			values[key] = value
		else
			result.skipped = result.skipped + 1
		end
	end
	return values
end

-- A name as the player could have typed it: not empty, without spaces around
-- it, not too long.
local function goodName(name)
	return type(name) == "string" and name:match("^%S") ~= nil and name:match("%S$") ~= nil
		and Text.Length(name) <= Profiles.MAX_NAME_LENGTH
end

-- The items of one collection in a text, as they may be imported.
local function readCollection(collection, items, result)
	local found = { names = {}, items = {}, taken = {} }
	for name, item in pairs(items) do
		local cleaned, why
		if goodName(name) and type(item) == "table" then
			cleaned, why = collection.clean(item)
		end
		if cleaned then
			found.names[#found.names + 1] = name
			found.items[name] = cleaned
			found.taken[name] = collection.taken(name)
		elseif why == "newer" then
			result.newer[#result.newer + 1] = name
		else
			result.skipped = result.skipped + 1
		end
	end
	table.sort(found.names, function(a, b)
		return Text.FoldCase(a) < Text.FoldCase(b)
	end)
	return found
end

-- What a pasted text holds: { names = { part, … }, sections = { [part] =
-- data }, collections = { [collection] = { names = { … }, items = { [item] =
-- data }, taken = { [item] = <player's name> } } }, skipped = <values left
-- out>, newer = { <items from a newer version> } }. Or nil and why not:
-- "empty", "prefix" (not a profile text), "newer" (a newer format), "encoder"
-- (the client cannot read texts), "broken", "nothing" (nothing this version
-- can import).
function Share.Read(text)
	-- A text pasted from a chat or a forum may be broken into lines; the text
	-- itself has no spaces.
	text = type(text) == "string" and text:gsub("%s+", "") or ""
	if text == "" then
		return nil, "empty"
	elseif #text > Share.MAX_LENGTH then
		return nil, "broken"
	end
	local format, body = text:match("^" .. Share.PREFIX .. "(%d+):(.+)$")
	if not format then
		return nil, "prefix"
	elseif tonumber(format) > Share.FORMAT then
		return nil, "newer"
	elseif not Compat.CanEncode() then
		return nil, "encoder"
	end
	local data = Compat.Decode(body)
	if type(data) ~= "table" or not plain(data, 1, { left = Share.MAX_VALUES }) then
		return nil, "broken"
	end
	if not isNumber(data.format) or data.format > Share.FORMAT then
		return nil, "newer"
	end
	local result = { names = {}, sections = {}, collections = {}, skipped = 0, newer = {} }
	local sections = type(data.sections) == "table" and data.sections or {}
	local known = {}
	for _, entry in ipairs(Share.Parts()) do
		known[entry.name] = true
		local section = sections[entry.name]
		if type(section) == "table" then
			local module = moduleOf(entry.name)
			local cleaned
			if module then
				cleaned = cleanModule(module, section, result)
			else
				cleaned = partsByName[entry.name].clean(section)
			end
			if cleaned then
				result.names[#result.names + 1] = entry.name
				result.sections[entry.name] = cleaned
			else
				result.skipped = result.skipped + 1
			end
		end
	end
	for name in pairs(sections) do
		if not known[name] then
			result.skipped = result.skipped + 1
		end
	end
	local found = #result.names
	local items = type(data.collections) == "table" and data.collections or {}
	for collectionName, collectionItems in pairs(items) do
		local collection = collectionsByName[collectionName]
		if collection and type(collectionItems) == "table" then
			result.collections[collectionName] = readCollection(collection, collectionItems, result)
			found = found + #result.collections[collectionName].names
		else
			result.skipped = result.skipped + 1
		end
	end
	if found == 0 and #result.newer == 0 then
		return nil, "nothing"
	end
	return result
end

-- Stores the chosen items of a read text: choices = { [collection] = {
-- [item] = "both" | "replace" | "keep" } }. Returns renamed[collection][item]:
-- the player's name of each.
local function importItems(read, choices)
	local renamed = {}
	for collectionName, chosen in pairs(choices or {}) do
		local collection, found = collectionsByName[collectionName], read.collections[collectionName]
		renamed[collectionName] = {}
		for _, name in ipairs(found and found.names or {}) do
			-- Taken now, not when the text was read: the player may have made one since.
			local how, taken = chosen[name], collection.taken(name)
			local target
			if how and taken and how == "keep" then
				target = taken
			elseif how and taken and how == "replace" then
				target = taken
				collection.put(taken, found.items[name])
			elseif how then
				target = taken and collection.freeName(collection.display(name)) or name
				collection.put(target, found.items[name])
			end
			renamed[collectionName][name] = target
		end
	end
	return renamed
end

-- Puts a read text into the account and a profile. choice = { parts = { name,
-- … }, collections = { [collection] = { [item] = how } }, newName = <name> }:
-- the items first, then the parts into the current profile (they replace
-- what it had) or, with newName, into a new profile the character then uses.
-- Returns the profile's name (nil when no part was chosen) and renamed (see
-- importItems), or nil and an error code of Profiles for the new name.
function Share.Import(read, choice)
	local names = choice.parts or {}
	local target, profile
	if #names > 0 then
		if choice.newName then
			local created, err = Profiles.Create(choice.newName)
			if not created then
				return nil, err
			end
			target, profile = created, Storage.db.profiles[created]
		else
			target, profile = Profiles.GetCurrent(), Storage:GetProfile()
		end
	end
	local renamed = importItems(read, choice.collections)
	for _, name in ipairs(names) do
		local data, module = read.sections[name], moduleOf(name)
		if data and module then
			local values = deepCopy(data)
			-- What the module's parts own stays as it was, unless they are imported too.
			local current = type(profile.modules) == "table" and profile.modules[module.name]
			for key in pairs(owned(module.name)) do
				values[key] = type(current) == "table" and current[key] or nil
			end
			profile.modules = type(profile.modules) == "table" and profile.modules or {}
			profile.modules[module.name] = next(values) and values or nil
		end
	end
	for _, name in ipairs(names) do
		local data, part = read.sections[name], partsByName[name]
		if data and part then
			part.set(profile, deepCopy(data), renamed)
		end
	end
	if profile and profile.modules and next(profile.modules) == nil then
		profile.modules = nil
	end
	if target and choice.newName then
		Profiles.Switch(target)
	elseif target then
		Bus:Send("ProfileChanged", target, target)
	end
	return target, renamed
end
