local _, ns = ...

-- Whether a need on an item breaks the rules of the needing player's class,
-- and how a player chooses in a group: needing nearly everything, needing a
-- BoE item that does not fit him, being fair again. Pure rules over facts:
-- the item's kind and stats, the player's class and level, the class's rules
-- (Core/NeedRules.lua) and the choices of a group (the roll history).
--
-- A class's rules: { armor = { [subclass] = true or the level up to which it
-- counts }, weapons = { [subclass] = true }, stats = { [STAT] = true } }.
-- An item: { classID, subclassID, equipLoc, quality, stats = { [STAT] = true }
-- or nil while the game has not loaded them }.
ns.Rules = ns.Rules or {}
local Need = {}
ns.Rules.Need = Need

Need.WEAPON, Need.ARMOR = 2, 4
-- Armor subclasses judged by type: cloth, leather, mail, plate; then the
-- shield and the relics (libram, idol, totem), judged as types too.
Need.ARMOR_TYPES = { [1] = true, [2] = true, [3] = true, [4] = true }
Need.SHIELD = 6
Need.RELICS = { [7] = true, [8] = true, [9] = true }
-- Not judged at all: cosmetic armor, other weapons and fishing poles.
local SKIPPED = { [Need.ARMOR] = { [5] = true }, [Need.WEAPON] = { [14] = true, [20] = true } }
-- Pieces of cloth worn by everyone (cloaks): judged by their stats only.
local ANY_CLASS = { INVTYPE_CLOAK = true }

-- The choices on a roll (Enum.EncounterLootDropRollState).
Need.STATE = { NEED = 0, NEED_OFF_SPEC = 1, TRANSMOG = 2, GREED = 3, NONE = 4, PASS = 5 }

function Need.IsNeed(state)
	return state == Need.STATE.NEED or state == Need.STATE.NEED_OFF_SPEC
end

-- A choice was made: need, greed, transmog or pass.
function Need.IsChoice(state)
	return type(state) == "number" and state ~= Need.STATE.NONE
end

-- The strictness presets: needing nearly everything (at least needs needs,
-- at least share of the choices), needing every BoE item (boe BoE needs
-- before this one), and how many fair choices take a mark from last time.
Need.PRESETS = {
	lenient = { needs = 6, share = 0.9, boe = 3, fair = 3 },
	normal = { needs = 4, share = 0.75, boe = 2, fair = 4 },
	strict = { needs = 3, share = 0.6, boe = 1, fair = 6 },
}
Need.PRESET_ORDER = { "lenient", "normal", "strict" }

function Need.Preset(name)
	return Need.PRESETS[name] or Need.PRESETS.normal
end

local function set(list)
	local result = {}
	for _, value in ipairs(list or {}) do
		result[value] = true
	end
	return result
end

-- The primary stats among an item's stats (Compat.GetItemStats): from keys such
-- as ITEM_MOD_INTELLECT_SHORT, and the combined ones of retail items whose
-- stat follows the specialization (ITEM_MOD_AGILITY_INTELLECT_SHORT). nil for
-- stats not loaded yet.
function Need.PrimaryStats(stats, primary)
	if type(stats) ~= "table" then
		return nil
	end
	local known, found = set(primary), {}
	for key, value in pairs(stats) do
		local inner = type(key) == "string" and key:match("^ITEM_MOD_([%u_]+)_SHORT$")
		if inner and (tonumber(value) or 0) > 0 then
			local parts, all = {}, true
			for part in inner:gmatch("[^_]+") do
				parts[#parts + 1] = part
				all = all and known[part] == true
			end
			if all then
				for _, part in ipairs(parts) do
					found[part] = true
				end
			end
		end
	end
	return found
end

-- A class's rules: the data's defaults with the player's changes (changes
-- may be nil), only what the class can equip. A change is { armor = { [sub]
-- = true, false or a level }, weapons = { [sub] = bool }, stats = { [STAT] = bool } }.
function Need.Rules(data, classFile, changes)
	local canEquip = data.canEquip[classFile]
	local defaults = data.defaults[classFile]
	if not canEquip or not defaults then
		return nil
	end
	changes = changes or {}
	local rules = { armor = {}, weapons = {}, stats = {} }
	local function pick(part, allowed, default)
		for _, key in ipairs(allowed) do
			local value, changed = default[key], nil
			if type(changes[part]) == "table" then
				changed = changes[part][key]
			end
			if changed ~= nil then
				value = changed
			end
			if value == true or (type(value) == "number" and value >= 1) then
				rules[part][key] = value
			end
		end
	end
	local defaultWeapons = set(canEquip.weapons)
	pick("armor", canEquip.armor, defaults.armor)
	pick("weapons", canEquip.weapons, defaultWeapons)
	pick("stats", data.stats, set(defaults.stats))
	return rules
end

-- Whether a class may have an armor or weapon type at all (data.canEquip).
function Need.CanEquip(data, classFile, part, key)
	local canEquip = data.canEquip[classFile]
	if not canEquip then
		return false
	end
	if part == "stats" then
		return set(data.stats)[key] == true
	end
	return set(canEquip[part])[key] == true
end

local function judgedType(item)
	if item.classID == Need.ARMOR then
		if ANY_CLASS[item.equipLoc] then
			return nil
		elseif Need.ARMOR_TYPES[item.subclassID] or item.subclassID == Need.SHIELD or Need.RELICS[item.subclassID] then
			return "armor"
		end
	elseif item.classID == Need.WEAPON then
		return "weapons"
	end
	return nil
end

-- What a need on the item breaks for the player ({ class, level }), as a list
-- of reasons (empty when nothing):
--   { kind = "armor", subclass = n }                 not the class's armor
--   { kind = "armor", subclass = n, level = 40 }     its own only up to level 40
--   { kind = "weapon", subclass = n }
--   { kind = "stats", stats = { "INTELLECT" } }     none of its primary stats
-- checks = { armor, weapons, stats (booleans), minQuality }. The second value
-- is true while the item's stats are not loaded and so not judged yet.
function Need.Judge(item, player, rules, checks)
	local reasons = {}
	if type(item) ~= "table" or not rules or not player then
		return reasons, false
	end
	if (item.classID ~= Need.ARMOR and item.classID ~= Need.WEAPON)
		or (SKIPPED[item.classID] and SKIPPED[item.classID][item.subclassID])
		or (checks.minQuality and (item.quality or 0) < checks.minQuality) then
		return reasons, false
	end
	local kind = judgedType(item)
	if kind == "armor" and checks.armor then
		local own = rules.armor[item.subclassID]
		if not own then
			reasons[#reasons + 1] = { kind = "armor", subclass = item.subclassID }
		elseif type(own) == "number" and type(player.level) == "number" and player.level > own then
			reasons[#reasons + 1] = { kind = "armor", subclass = item.subclassID, level = own }
		end
	elseif kind == "weapons" and checks.weapons and not rules.weapons[item.subclassID] then
		reasons[#reasons + 1] = { kind = "weapon", subclass = item.subclassID }
	end
	local pending = false
	if checks.stats then
		if item.stats == nil then
			pending = true
		elseif next(item.stats) then
			local own, theirs = false, {}
			for stat in pairs(item.stats) do
				theirs[#theirs + 1] = stat
				own = own or rules.stats[stat] == true
			end
			if not own then
				table.sort(theirs)
				reasons[#reasons + 1] = { kind = "stats", stats = theirs }
			end
		end
	end
	return reasons, pending
end

-- The behaviour of one player in a group. choices: his choices in time order,
-- { state, excused, boe = bool, fits = bool or nil, link }; an excused need
-- counts nowhere, a roll not chosen yet neither.
local function counted(choice)
	return Need.IsChoice(choice.state) and not (choice.excused and Need.IsNeed(choice.state))
end

-- How many needs among how many choices.
function Need.Counts(choices)
	local needs, total = 0, 0
	for _, choice in ipairs(choices) do
		if counted(choice) then
			total = total + 1
			if Need.IsNeed(choice.state) then
				needs = needs + 1
			end
		end
	end
	return needs, total
end

-- Whether the choices need nearly everything, by the preset.
function Need.NeedsEverything(choices, preset)
	local needs, total = Need.Counts(choices)
	return total > 0 and needs >= preset.needs and needs / total >= preset.share, needs, total
end

-- Whether the choices are fair by now: enough of them, with needs under the
-- preset's share. A mark from last time goes once they are.
function Need.Fair(choices, preset)
	local needs, total = Need.Counts(choices)
	return total >= preset.fair and needs / total < preset.share
end

-- For a need on a BoE item that does not fit the player: what his earlier
-- choices on BoE items in the group say, the strongest first.
--   { kind = "greedFitting", link = … }   he greeded a BoE item that fits him
--   { kind = "everyBoE", needs = n, total = n }   he needed every one, this one too
--   nil                                   nothing to say
function Need.BoEReason(earlier, preset)
	local greeded, needs, total = nil, 0, 0
	for _, choice in ipairs(earlier) do
		if choice.boe and counted(choice) then
			total = total + 1
			if Need.IsNeed(choice.state) then
				needs = needs + 1
			elseif choice.state == Need.STATE.GREED and choice.fits == true then
				greeded = choice
			end
		end
	end
	if greeded then
		return { kind = "greedFitting", link = greeded.link }
	elseif total > 0 and needs == total and needs >= preset.boe then
		return { kind = "everyBoE", needs = needs + 1, total = total + 1 }
	end
	return nil
end
