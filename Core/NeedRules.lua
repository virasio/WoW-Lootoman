local _, ns = ...
local Bus, Storage = ns.Bus, ns.Storage

-- The player's changes to the classes' rules for needs: which armor types (and
-- up to which level), weapon types and primary stats count as a class's own
-- (Rules/Need.lua judges with them). A rule is about other players, so it is
-- the same for every character and not part of a profile:
-- LootomanDB.sections.needRules = { schema = 1, classes = { [classFile] = {
-- armor = { [subclass] = true, false or a level }, weapons = { [subclass] =
-- bool }, stats = { [STAT] = bool } } } }. Only what differs from the client's
-- defaults (Data/*/Rolls.lua) is kept.
local NeedRules = {}
ns.NeedRules = NeedRules

NeedRules.SECTION = "needRules"
NeedRules.SCHEMA = 1
NeedRules.PARTS = { "armor", "weapons", "stats" }

local function data()
	return ns.Data.rolls
end

local function section()
	local saved = Storage:GetGlobalSection(NeedRules.SECTION)
	saved.schema = saved.schema or NeedRules.SCHEMA
	if type(saved.classes) ~= "table" then
		saved.classes = {}
	end
	return saved
end

local function known(classFile)
	return type(classFile) == "string" and data().canEquip[classFile] ~= nil
end

-- Whether a value may stand for a key of a part: armor types take true, false
-- or a level; weapons and stats true or false.
local function allowed(classFile, part, key, value)
	if not ns.Rules.Need.CanEquip(data(), classFile, part, key) then
		return false
	end
	if type(value) == "boolean" then
		return true
	end
	return part == "armor" and type(value) == "number" and value == math.floor(value) and value >= 1 and value <= data().maxLevel
end

-- The class's default for a key: armor true or a level, else whether it is own.
local function default(classFile, part, key)
	local defaults = data().defaults[classFile]
	if part == "armor" then
		return defaults.armor[key] or false
	elseif part == "weapons" then
		return ns.Rules.Need.CanEquip(data(), classFile, "weapons", key)
	end
	for _, stat in ipairs(defaults.stats) do
		if stat == key then
			return true
		end
	end
	return false
end

-- The class's saved changes, only those still allowed.
local function changes(classFile)
	local saved = section().classes[classFile]
	if type(saved) ~= "table" then
		return nil
	end
	local clean = {}
	for _, part in ipairs(NeedRules.PARTS) do
		if type(saved[part]) == "table" then
			for key, value in pairs(saved[part]) do
				if allowed(classFile, part, key, value) then
					clean[part] = clean[part] or {}
					clean[part][key] = value
				end
			end
		end
	end
	return clean
end

-- A class's rules as Rules/Need.lua takes them, or nil for a class the client
-- does not have.
function NeedRules.Get(classFile)
	if not known(classFile) then
		return nil
	end
	return ns.Rules.Need.Rules(data(), classFile, changes(classFile))
end

-- What a key of a part is for the class now: true, false or a level.
function NeedRules.Value(classFile, part, key)
	local rules = NeedRules.Get(classFile)
	if not rules then
		return false
	end
	return rules[part][key] or false
end

-- Changes one key: value true, false, or for an armor type a level up to which
-- it counts. A value equal to the default forgets the change. False for a
-- value the class cannot have.
function NeedRules.Set(classFile, part, key, value)
	if not known(classFile) or not allowed(classFile, part, key, value) then
		return false
	end
	local classes = section().classes
	local saved = type(classes[classFile]) == "table" and classes[classFile] or {}
	saved[part] = type(saved[part]) == "table" and saved[part] or {}
	if value == default(classFile, part, key) then
		saved[part][key] = nil
	else
		saved[part][key] = value
	end
	if next(saved[part]) == nil then
		saved[part] = nil
	end
	classes[classFile] = next(saved) and saved or nil
	Bus:Send("NeedRulesChanged", classFile)
	return true
end

-- The class's defaults again.
function NeedRules.Reset(classFile)
	section().classes[classFile] = nil
	Bus:Send("NeedRulesChanged", classFile)
end

-- Every class's defaults again.
function NeedRules.ResetAll()
	section().classes = {}
	Bus:Send("NeedRulesChanged", nil)
end

-- Whether the class has changes kept.
function NeedRules.IsChanged(classFile)
	local saved = changes(classFile)
	return saved ~= nil and next(saved) ~= nil
end

-- How many classes have changes, for the bug report.
function NeedRules.ChangedCount()
	local count = 0
	for _, class in ipairs(data().classes) do
		if NeedRules.IsChanged(class[1]) then
			count = count + 1
		end
	end
	return count
end
