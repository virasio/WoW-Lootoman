local _, ns = ...
local Bus, L, Storage, Text = ns.Bus, ns.L, ns.Storage, ns.Text

-- Named layouts of the loot feed's rows (plans/0.1.md, task 16, Q14–Q17, C42),
-- shared by every profile as in Platynator. The account-wide section
-- "feedLayouts" holds { [name] = design } (Design.lua: { schema, base,
-- changes }); the loot feed's setting "layout" names the one a profile uses.
--
-- There is always a layout Default, shown in the client language: it cannot be
-- renamed or deleted, and a profile whose layout is gone uses it. A new layout
-- starts from a built-in design, its template. Renaming a layout renames it in
-- every profile; deleting one moves its profiles to Default.
--
-- Functions that can fail return nil and an error code, as Profiles do:
-- "empty", "too_long", "exists", "missing", "default" or "template".
-- FeedLayoutChanged(name) is sent when a layout's design changes here.
ns.Feed = ns.Feed or {}
local Layouts = {
	DEFAULT = "Default",
	MAX_NAME_LENGTH = 48,
}
ns.Feed.Layouts = Layouts
local Design = ns.Feed.Design

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

local function all()
	local layouts = Storage:GetGlobalSection("feedLayouts")
	if type(layouts[Layouts.DEFAULT]) ~= "table" then
		layouts[Layouts.DEFAULT] = { schema = Design.SCHEMA, base = "large" }
	end
	return layouts
end

-- Default first, then the others in alphabetical order.
function Layouts.List()
	local names = {}
	for name, layout in pairs(all()) do
		if name ~= Layouts.DEFAULT and type(layout) == "table" then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return Text.FoldCase(a) < Text.FoldCase(b)
	end)
	table.insert(names, 1, Layouts.DEFAULT)
	return names
end

-- A layout's design table, which the designer changes in place; nil if none.
function Layouts.Get(name)
	local layout = type(name) == "string" and all()[name]
	return type(layout) == "table" and layout or nil
end

function Layouts.DisplayName(name)
	return name == Layouts.DEFAULT and L["Default"] or name
end

-- The layout the current profile uses.
function Layouts.Current()
	local name = Storage:Get("LootFeed", "layout")
	return Layouts.Get(name) and name or Layouts.DEFAULT
end

function Layouts.CurrentDesign()
	return Layouts.Get(Layouts.Current())
end

-- The current profile uses this layout from now on.
function Layouts.Use(name)
	if not Layouts.Get(name) then
		return nil, "missing"
	end
	Storage:Set("LootFeed", "layout", name)
	return true
end

-- The name of the player's layout that a name would clash with, if any.
function Layouts.Taken(name)
	local folded = Text.FoldCase(name)
	if folded == Text.FoldCase(L["Default"]) then
		return Layouts.DEFAULT
	end
	for existing in pairs(all()) do
		if Text.FoldCase(existing) == folded then
			return existing
		end
	end
end

-- A free name like the given one: the name itself, or "Name 2", "Name 3", …
function Layouts.FreeName(name)
	local free, number = name, 1
	while Layouts.Taken(free) do
		number = number + 1
		free = ("%s %d"):format(name, number)
	end
	return free
end

local function validate(name, renaming)
	return Text.CheckName(name, all(), Layouts.MAX_NAME_LENGTH, renaming)
end

-- A new layout from a built-in design (Design.BUILT_IN).
function Layouts.Create(name, template)
	if not Design.BUILT_IN[template] then
		return nil, "template"
	end
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = { schema = Design.SCHEMA, base = template }
	return valid
end

function Layouts.Copy(source, name)
	if not Layouts.Get(source) then
		return nil, "missing"
	end
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = deepCopy(Layouts.Get(source))
	return valid
end

-- Calls fn(values) for the loot feed's settings of every profile that has them.
local function eachProfileFeed(fn)
	for _, profile in pairs(Storage.db.profiles) do
		local values = type(profile) == "table" and type(profile.modules) == "table" and profile.modules.LootFeed
		if type(values) == "table" then
			fn(values)
		end
	end
end

function Layouts.Rename(old, name)
	if old == Layouts.DEFAULT then
		return nil, "default"
	end
	if not Layouts.Get(old) then
		return nil, "missing"
	end
	local valid, err = validate(name, old)
	if not valid then
		return nil, err
	end
	if valid == old then
		return valid
	end
	local current = Layouts.Current()
	local layouts = all()
	layouts[valid], layouts[old] = layouts[old], nil
	eachProfileFeed(function(values)
		if values.layout == old then
			values.layout = valid
		end
	end)
	if current == old then
		Bus:Send("SettingChanged", "LootFeed", "layout", valid)
	end
	return valid
end

-- Back to its template.
function Layouts.Reset(name)
	local layout = Layouts.Get(name)
	if not layout then
		return nil, "missing"
	end
	Design.Reset(layout)
	Bus:Send("FeedLayoutChanged", name)
	return true
end

-- Profiles that used the deleted layout move to Default.
function Layouts.Delete(name)
	if name == Layouts.DEFAULT then
		return nil, "default"
	end
	if not Layouts.Get(name) then
		return nil, "missing"
	end
	local current = Layouts.Current()
	all()[name] = nil
	eachProfileFeed(function(values)
		if values.layout == name then
			values.layout = nil
		end
	end)
	if current == name then
		Bus:Send("SettingChanged", "LootFeed", "layout", Layouts.DEFAULT)
	end
	return true
end

-- Puts a design under a name, a new one or in place of a layout's (an import).
function Layouts.Put(name, design)
	all()[name] = deepCopy(design)
	Bus:Send("FeedLayoutChanged", name)
end
