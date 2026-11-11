local _, ns = ...
local Bus, L, Migrations, Storage, Text = ns.Bus, ns.L, ns.Migrations, ns.Storage, ns.Text

-- Named sets of currency bars, shared by every profile like the loot feed's
-- row layouts. The account-wide section "barSets" holds { [name] = set }:
--
--   set = { schema = 2, bars = {
--       { id = 1, width = 300, gap = 6, size = 22,
--         direction = "right" | "left",            -- fills from the left edge, or from the right
--         background = false, opacity = 50, border = false,
--         entries = { { kind = "currency" | "item" | "money", id = 3008 }, … },   -- nil: the backpack's currencies
--             -- an item also has count = "banks" or "all" when it does not count the bags only;
--             -- or a stack: { kind = "stack", members = { { kind = "currency" | "item", id[, count] }, … },
--             --     showEmpty = false }, its members most important first, 2 to MAX_MEMBERS
--         positions = { [Edit Mode layout] = { point, x, y } } },
--   } }
--
-- The Bars module's setting "set" names the set a profile uses. There is always
-- a set Default, shown in the client language, with one bar to begin with: it
-- shows the currencies the player shows on the backpack until its entries are
-- set. Default cannot be renamed or deleted, and a profile whose set is gone
-- uses it. Renaming a set renames it in every profile; deleting one moves its
-- profiles to Default. Every change sends BarSetChanged(name).
--
-- Schema 2 (0.3.5) adds stacks and an item's count to schema 1 (0.3), whose
-- sets keep their shape: a version that reads schema 1 refuses a newer text
-- instead of dropping its stacks.
--
-- Functions that can fail return nil and an error code, as Profiles do:
-- "empty", "too_long", "exists", "missing" or "default".
local Bars = ns.Modules:Get("Bars")
local Sets = {
	DEFAULT = "Default",
	MAX_NAME_LENGTH = 48,
	SCHEMA = 2,
	-- The most members a stack holds.
	MAX_MEMBERS = 10,
	-- The most bars a set holds.
	MAX_BARS = 20,
	-- A bar's width, gap and size: their defaults and ranges.
	WIDTH = { 300, 60, 1200 },
	GAP = { 6, 0, 40 },
	SIZE = { 22, 12, 48 },
	OPACITY = { 50, 0, 100 },
	-- Money is one entry; its id is always 0.
	KINDS = { currency = true, item = true, money = true },
	DIRECTIONS = { right = true, left = true },
}
Bars.Sets = Sets

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

-- A new bar: the backpack's currencies until its entries are set.
function Sets.NewBar(id)
	return { id = id, width = Sets.WIDTH[1], gap = Sets.GAP[1], size = Sets.SIZE[1], direction = "right",
		background = false, opacity = Sets.OPACITY[1], border = false, positions = {} }
end

local function newSet()
	return { schema = Sets.SCHEMA, bars = { Sets.NewBar(1) } }
end

-- Schema steps of one set (Migrations.Run): step n brings schema n - 1 to n.
Sets.STEPS = {
	-- 1: the sets of 0.3.
	function() end,
	-- 2: stacks and an item's count, which schema 1 has none of.
	function() end,
}

local migrated = false

local function all()
	local sets = Storage:GetGlobalSection("barSets")
	if not migrated then
		migrated = true
		for _, set in pairs(sets) do
			if type(set) == "table" then
				Migrations.Run(Sets.STEPS, set)
			end
		end
	end
	if type(sets[Sets.DEFAULT]) ~= "table" then
		sets[Sets.DEFAULT] = newSet()
	end
	return sets
end

local function changed(name)
	Bus:Send("BarSetChanged", name)
end

-- Default first, then the others in alphabetical order.
function Sets.List()
	local names = {}
	for name, set in pairs(all()) do
		if name ~= Sets.DEFAULT and type(set) == "table" then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return Text.FoldCase(a) < Text.FoldCase(b)
	end)
	table.insert(names, 1, Sets.DEFAULT)
	return names
end

-- A set's table, which the bars and the editor change in place; nil if none.
function Sets.Get(name)
	local set = type(name) == "string" and all()[name]
	if type(set) ~= "table" then
		return nil
	end
	set.bars = type(set.bars) == "table" and set.bars or {}
	return set
end

function Sets.DisplayName(name)
	return name == Sets.DEFAULT and L["Default"] or name
end

-- The set the current profile uses.
function Sets.Current()
	local name = Storage:Get("Bars", "set")
	return Sets.Get(name) and name or Sets.DEFAULT
end

function Sets.Use(name)
	if not Sets.Get(name) then
		return nil, "missing"
	end
	Storage:Set("Bars", "set", name)
	return true
end

-- The name of the player's set that a name would clash with, if any.
function Sets.Taken(name)
	local folded = Text.FoldCase(name)
	if folded == Text.FoldCase(L["Default"]) then
		return Sets.DEFAULT
	end
	for existing in pairs(all()) do
		if Text.FoldCase(existing) == folded then
			return existing
		end
	end
end

-- A free name like the given one: the name itself, or "Name 2", "Name 3", ….
function Sets.FreeName(name)
	local free, number = name, 1
	while Sets.Taken(free) do
		number = number + 1
		local suffix = (" %d"):format(number)
		free = Text.Truncate(name, Sets.MAX_NAME_LENGTH - #suffix):gsub("%s+$", "") .. suffix
	end
	return free
end

local function validate(name, renaming)
	return Text.CheckName(name, all(), Sets.MAX_NAME_LENGTH, renaming)
end

-- A new set with one bar.
function Sets.Create(name)
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = newSet()
	changed(valid)
	return valid
end

function Sets.Copy(source, name)
	if not Sets.Get(source) then
		return nil, "missing"
	end
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = deepCopy(Sets.Get(source))
	changed(valid)
	return valid
end

-- Calls fn(values) for the Bars module's settings of every profile that has them.
local function eachProfileBars(fn)
	for _, profile in pairs(Storage.db.profiles) do
		local values = type(profile) == "table" and type(profile.modules) == "table" and profile.modules.Bars
		if type(values) == "table" then
			fn(values)
		end
	end
end

function Sets.Rename(old, name)
	if old == Sets.DEFAULT then
		return nil, "default"
	end
	if not Sets.Get(old) then
		return nil, "missing"
	end
	local valid, err = validate(name, old)
	if not valid then
		return nil, err
	end
	if valid == old then
		return valid
	end
	local current = Sets.Current()
	local sets = all()
	sets[valid], sets[old] = sets[old], nil
	eachProfileBars(function(values)
		if values.set == old then
			values.set = valid
		end
	end)
	if current == old then
		Bus:Send("SettingChanged", "Bars", "set", valid)
	end
	return valid
end

-- Back to one bar with the backpack's currencies.
function Sets.Reset(name)
	local set = Sets.Get(name)
	if not set then
		return nil, "missing"
	end
	set.bars = newSet().bars
	changed(name)
	return true
end

-- Profiles that used the deleted set move to Default.
function Sets.Delete(name)
	if name == Sets.DEFAULT then
		return nil, "default"
	end
	if not Sets.Get(name) then
		return nil, "missing"
	end
	local current = Sets.Current()
	all()[name] = nil
	eachProfileBars(function(values)
		if values.set == name then
			values.set = nil
		end
	end)
	if current == name then
		Bus:Send("SettingChanged", "Bars", "set", Sets.DEFAULT)
	end
	return true
end

-- Puts a set under a name, a new one or in place of a set's (an import).
function Sets.Put(name, set)
	all()[name] = deepCopy(set)
	changed(name)
end

-- A bar of a set by its id, and its place in the list.
function Sets.Bar(name, id)
	local set = Sets.Get(name)
	for index, bar in ipairs(set and set.bars or {}) do
		if bar.id == id then
			return bar, index
		end
	end
	return nil
end

-- A new bar at the end of a set; its id, or nil and "full".
function Sets.AddBar(name)
	local set = Sets.Get(name)
	if not set then
		return nil, "missing"
	end
	if #set.bars >= Sets.MAX_BARS then
		return nil, "full"
	end
	local id = 0
	for _, bar in ipairs(set.bars) do
		id = math.max(id, bar.id)
	end
	local bar = Sets.NewBar(id + 1)
	bar.entries = {}
	set.bars[#set.bars + 1] = bar
	changed(name)
	return bar.id
end

function Sets.RemoveBar(name, id)
	local _, index = Sets.Bar(name, id)
	if not index then
		return nil, "missing"
	end
	table.remove(Sets.Get(name).bars, index)
	changed(name)
	return true
end

-- After a change made in place on a bar (entries, width, a position).
function Sets.Changed(name)
	changed(name)
end

local POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- An entry kept from a profile text: a known kind and a number, and for an
-- item what it counts if it is not the bags.
local function cleanEntry(entry, kinds)
	if type(entry) ~= "table" or not kinds[entry.kind] or type(entry.id) ~= "number" then
		return nil
	end
	local kept = { kind = entry.kind, id = entry.id }
	if entry.kind == "item" and (entry.count == "banks" or entry.count == "all") then
		kept.count = entry.count
	end
	return kept
end

local MEMBER_KINDS = { currency = true, item = true }

-- A stack's well-formed members, each once, up to MAX_MEMBERS: nil without
-- any, the member itself when one is left.
local function cleanStack(entry)
	local members, seen = {}, {}
	for _, member in ipairs(type(entry.members) == "table" and entry.members or {}) do
		local kept = cleanEntry(member, MEMBER_KINDS)
		if kept then
			local key = kept.kind .. ":" .. kept.id .. ":" .. (kept.count or "bags")
			if not seen[key] and #members < Sets.MAX_MEMBERS then
				seen[key] = true
				members[#members + 1] = kept
			end
		end
	end
	if #members <= 1 then
		return members[1]
	end
	return { kind = "stack", members = members, showEmpty = entry.showEmpty == true }
end

local function number(value, range)
	if type(value) ~= "number" or value ~= value then
		return range[1]
	end
	return math.min(math.max(math.floor(value + 0.5), range[2]), range[3])
end

-- A set from a profile text, as it may be imported: well-formed bars only,
-- numbers in their ranges, known kinds of entries; nil and "newer" for a set
-- from a newer version.
function Sets.Clean(data)
	if type(data.schema) == "number" and data.schema > Sets.SCHEMA then
		return nil, "newer"
	end
	local bars, ids = {}, {}
	for _, bar in ipairs(type(data.bars) == "table" and data.bars or {}) do
		if type(bar) == "table" and type(bar.id) == "number" and not ids[bar.id] and #bars < Sets.MAX_BARS then
			ids[bar.id] = true
			local clean = Sets.NewBar(bar.id)
			clean.width, clean.gap, clean.size = number(bar.width, Sets.WIDTH), number(bar.gap, Sets.GAP), number(bar.size, Sets.SIZE)
			clean.direction = Sets.DIRECTIONS[bar.direction] and bar.direction or "right"
			clean.background, clean.border = bar.background == true, bar.border == true
			clean.opacity = number(bar.opacity, Sets.OPACITY)
			if type(bar.entries) == "table" then
				clean.entries = {}
				for _, entry in ipairs(bar.entries) do
					local kept
					if type(entry) == "table" and entry.kind == "stack" then
						kept = cleanStack(entry)
					else
						kept = cleanEntry(entry, Sets.KINDS)
					end
					clean.entries[#clean.entries + 1] = kept
				end
			end
			for layout, position in pairs(type(bar.positions) == "table" and bar.positions or {}) do
				if type(layout) == "string" and type(position) == "table" and POINTS[position.point]
					and type(position.x) == "number" and type(position.y) == "number" then
					clean.positions[layout] = { point = position.point, x = position.x, y = position.y }
				end
			end
			bars[#bars + 1] = clean
		end
	end
	return { schema = Sets.SCHEMA, bars = bars }
end

-- In profile texts (Share): the set the profile uses, under the module's
-- settings, and the player's sets.
ns.Share.RegisterPart({
	name = "set:Bars",
	module = Bars.name,
	owns = "set",
	label = function(data)
		return L["Use bar set “%s”"]:format(Sets.DisplayName(data.set or Sets.DEFAULT))
	end,
	get = function()
		return { set = Sets.Current() }
	end,
	set = function(profile, data, renamed)
		local name = renamed.barSets and renamed.barSets[data.set]
		if name then
			profile.modules = type(profile.modules) == "table" and profile.modules or {}
			local values = type(profile.modules.Bars) == "table" and profile.modules.Bars or {}
			values.set = name ~= Sets.DEFAULT and name or nil
			profile.modules.Bars = next(values) and values or nil
		end
	end,
	clean = function(data)
		return type(data.set) == "string" and { set = data.set } or nil
	end,
	needs = function(data)
		return "barSets", data.set
	end,
})
ns.Share.RegisterCollection({
	name = "barSets",
	label = L["Bar sets"],
	list = Sets.List,
	get = Sets.Get,
	taken = Sets.Taken,
	freeName = Sets.FreeName,
	put = Sets.Put,
	display = Sets.DisplayName,
	clean = Sets.Clean,
})
