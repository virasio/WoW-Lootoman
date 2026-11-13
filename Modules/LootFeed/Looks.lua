local _, ns = ...
local Bus, Compat, L, Storage, Text = ns.Bus, ns.Compat, ns.L, ns.Storage, ns.Text

-- Feed looks: named sets of every loot feed setting with the row design,
-- shared by every profile; each profile uses one (the loot feed's setting
-- "look"). A player can share a whole feed, or use it on several characters.
-- The account-wide section "feedLooks" holds { [name] = look }:
--
--   { schema = 1, base = "large", changes = { owned = { shown = true } }, values = { maxRows = 8 } }
--
-- schema, base and changes are the row design as Design.lua keeps it, so
-- Design.Current reads a look as it is; values holds the settings that differ
-- from their defaults (Looks.DEFAULTS; the fill direction's default depends on
-- the view). A look has one view, rows or icons, which its design's base
-- decides.
--
-- There is always a look Default, shown in the client language: it cannot be
-- renamed or deleted, and a profile whose look is gone uses it. A new look
-- starts with the Large design and every setting at its default; SetView
-- turns it into the other view, starting its design afresh.
--
-- Functions that can fail return nil and an error code, as Profiles do:
-- "empty", "too_long", "exists", "missing", "default", "view" or "value".
-- FeedLookChanged(name, key) is sent when a look's setting (key) or its design
-- (key nil) changes here, or it is deleted; FeedLookRenamed(old, new) when it
-- is renamed.
ns.Feed = ns.Feed or {}
local Looks = {
	DEFAULT = "Default",
	MAX_NAME_LENGTH = 48,
}
ns.Feed.Looks = Looks
local Design = ns.Feed.Design

-- Every setting of a look and its default; the fill direction's default is
-- the view's (DIRECTION).
Looks.DEFAULTS = {
	items = true,
	currencies = true,
	money = true,
	reputation = true,
	xp = true,
	minQuality = 0,
	keepUsable = true,
	keepQuest = true,
	keepRecipes = false,
	keepContainers = true,
	keepPets = false,
	keepMounts = false,
	keepToys = false,
	keepSets = false,
	keepHeirlooms = false,
	maxRows = 5,
	direction = "up",
	duration = 6,
	fade = 1,
	size = 12,
	backgroundOpacity = 0,
	glow = true,
	warnGeneral = true,
	warnGeneralAt = 3,
	warnReagent = true,
	warnReagentAt = 2,
}

-- The fill direction a look of each view starts with.
Looks.DIRECTION = { rows = "up", icons = "right" }

-- Directions the feed fills in; rows fill only up or down.
Looks.DIRECTIONS = {
	{ "up", L["Bottom to top"] },
	{ "down", L["Top to bottom"] },
	{ "right", L["Left to right"] },
	{ "left", L["Right to left"] },
}
Looks.SIDEWAYS = { left = true, right = true }

-- The setting of each kind of usable item the feed keeps (Rules/Usable.lua),
-- and its label.
Looks.KEEP = {
	quest = { "keepQuest", L["Items that start a quest"] },
	recipe = { "keepRecipes", L["Recipes"] },
	container = { "keepContainers", L["Containers"] },
	pet = { "keepPets", L["Pets"] },
	mount = { "keepMounts", L["Mounts"] },
	toy = { "keepToys", L["Toys"] },
	set = { "keepSets", L["Appearance sets"] },
	heirloom = { "keepHeirlooms", L["Heirlooms"] },
}

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

-- Item quality names come from the client, from Poor to Legendary.
local function qualityChoices()
	local choices = {}
	for quality = 0, 5 do
		choices[#choices + 1] = { quality, Compat.GetGlobalString(("ITEM_QUALITY%d_DESC"):format(quality)) or tostring(quality) }
	end
	return choices
end

local function viewOf(look)
	return Design.View(Design.Current(look))
end

-- The directions a look of this view may fill in.
local function directionsOf(view)
	if view == "icons" then
		return Looks.DIRECTIONS
	end
	return { Looks.DIRECTIONS[1], Looks.DIRECTIONS[2] }
end

-- A look's settings, in groups: header, checkbox, slider and dropdown, as
-- the look window draws them. A setting with a parent (the key of a checkbox
-- before it) sits under it; a kind of usable item the client has no
-- collection for is not offered. view picks the directions offered.
function Looks.Settings(view)
	local list = {
		{ kind = "header", key = "shows", label = L["What the feed shows"] },
		{ kind = "checkbox", key = "items", label = L["Items"] },
		{ kind = "checkbox", key = "currencies", label = L["Currencies"] },
		{ kind = "checkbox", key = "money", label = L["Money"] },
		{ kind = "checkbox", key = "reputation", label = L["Reputation"] },
		{ kind = "checkbox", key = "xp", label = L["Experience"] },
		{ kind = "dropdown", key = "minQuality", label = L["Minimum quality"],
			tooltip = L["Items of a lower quality are not shown."], choices = qualityChoices() },
		{ kind = "header", key = "kept", label = L["Kept usable items"] },
		{ kind = "checkbox", key = "keepUsable", label = L["Keep usable items"],
			tooltip = L["Items this character can use right now stay at the start of the feed, after any warnings, also below the minimum quality, until you click them: left to dismiss, right to use."] },
	}
	for _, kind in ipairs(ns.Rules.Usable.Kinds()) do
		list[#list + 1] = { kind = "checkbox", key = Looks.KEEP[kind][1], label = Looks.KEEP[kind][2], parent = "keepUsable" }
	end
	local rest = {
		{ kind = "header", key = "timing", label = L["Rows and timing"] },
		{ kind = "slider", key = "maxRows", label = L["Number of rows"], tooltip = L["How many rows are shown at once. When there are more, the oldest ones fade out at once."],
			min = 3, max = 20, step = 1, format = "%d" },
		{ kind = "dropdown", key = "direction", label = L["Fill direction"],
			tooltip = L["Where new entries go. Bottom to top: the oldest one stays at the bottom edge and new ones stack above it; the other directions likewise. Left to right and right to left are for the Icons layouts."],
			choices = directionsOf(view) },
		{ kind = "slider", key = "duration", label = L["Time on screen"], tooltip = L["Seconds before a row starts to fade out."],
			min = 2, max = 30, step = 1, format = L["%d s"] },
		{ kind = "slider", key = "fade", label = L["Fade-out time"], min = 0.2, max = 3, step = 0.1, format = L["%.1f s"] },
		{ kind = "header", key = "appearance", label = L["Appearance"] },
		{ kind = "slider", key = "size", label = L["Size"], tooltip = L["The size of the text; the icons and rows follow it."],
			min = 10, max = 16, step = 1, format = "%d" },
		{ kind = "slider", key = "backgroundOpacity", label = L["Background opacity"], min = 0, max = 100, step = 5, format = L["%d %%"] },
		{ kind = "checkbox", key = "glow", label = L["Glow for rare items"], tooltip = L["Rare and better items glow in their quality colour."] },
		{ kind = "header", key = "warnings", label = L["Low-space warnings"] },
		{ kind = "checkbox", key = "warnGeneral", label = L["Warn when few bag slots are free"],
			tooltip = L["Shows a warning at the feed's edge while no more general bag slots are free than the number below."] },
		{ kind = "slider", key = "warnGeneralAt", label = L["Bag slots"], min = 0, max = 20, step = 1, format = "%d", parent = "warnGeneral" },
		{ kind = "checkbox", key = "warnReagent", label = L["Warn when few reagent bag slots are free"],
			tooltip = L["Shows a warning at the feed's edge while no more reagent bag slots are free than the number below."] },
		{ kind = "slider", key = "warnReagentAt", label = L["Reagent bag slots"], min = 0, max = 20, step = 1, format = "%d", parent = "warnReagent" },
	}
	for _, setting in ipairs(rest) do
		list[#list + 1] = setting
	end
	return list
end

local function declared(view, key)
	for _, setting in ipairs(Looks.Settings(view)) do
		if setting.key == key and setting.kind ~= "header" then
			return setting
		end
	end
end

-- Whether a look of this view may hold the value: of its default's type, and
-- one its control can set (a slider's range and step, a dropdown's choices).
local function allows(view, key, value)
	local default = Looks.DEFAULTS[key]
	if default == nil or type(value) ~= type(default) then
		return false
	end
	local setting = declared(view, key)
	if not setting then
		-- A kind of usable item this client has no collection for keeps its value.
		return type(default) == "boolean"
	elseif setting.kind == "slider" then
		return value >= setting.min and value <= setting.max
			and Storage.OnStep(value, setting.min, setting.max, setting.step) == value
	elseif setting.kind == "dropdown" then
		for _, choice in ipairs(setting.choices) do
			if choice[1] == value then
				return true
			end
		end
		return false
	end
	return true
end

local function all()
	local looks = Storage:GetGlobalSection("feedLooks")
	if type(looks[Looks.DEFAULT]) ~= "table" then
		looks[Looks.DEFAULT] = { schema = Design.SCHEMA, base = "large" }
	end
	return looks
end

-- Default first, then the others in alphabetical order.
function Looks.List()
	local names = {}
	for name, look in pairs(all()) do
		if name ~= Looks.DEFAULT and type(look) == "table" then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return Text.FoldCase(a) < Text.FoldCase(b)
	end)
	table.insert(names, 1, Looks.DEFAULT)
	return names
end

-- A look's table, which the look window changes through Set and SetDesign; nil if none.
function Looks.Get(name)
	local look = type(name) == "string" and all()[name]
	return type(look) == "table" and look or nil
end

-- A look's table, or Default's when it has none.
local function lookOf(name)
	return Looks.Get(name) or all()[Looks.DEFAULT]
end

function Looks.DisplayName(name)
	return name == Looks.DEFAULT and L["Default"] or name
end

-- The look the current profile uses.
function Looks.Current()
	local name = Storage:Get("LootFeed", "look")
	return Looks.Get(name) and name or Looks.DEFAULT
end

-- The current profile uses this look from now on.
function Looks.Use(name)
	if not Looks.Get(name) then
		return nil, "missing"
	end
	Storage:Set("LootFeed", "look", name)
	return true
end

-- A look's view: "rows" or "icons".
function Looks.View(name)
	return viewOf(lookOf(name))
end

-- A setting's default in a look: the fill direction's is its view's.
function Looks.Default(name, key)
	if key == "direction" then
		return Looks.DIRECTION[Looks.View(name)]
	end
	return Looks.DEFAULTS[key]
end

-- A look's setting: its own value, or the default when it has none or one it
-- cannot hold (another type, out of range, a direction of the other view).
function Looks.Value(name, key)
	local look = lookOf(name)
	local value
	if type(look.values) == "table" then
		value = look.values[key]
	end
	if value ~= nil and allows(viewOf(look), key, value) then
		return value
	end
	return Looks.Default(name, key)
end

-- Changes a look's setting; a look keeps only values that differ from the defaults.
function Looks.Set(name, key, value)
	local look = Looks.Get(name)
	if not look then
		return nil, "missing"
	end
	if not allows(viewOf(look), key, value) then
		return nil, "value"
	end
	local old = Looks.Value(name, key)
	if value == Looks.Default(name, key) then
		if type(look.values) == "table" then
			look.values[key] = nil
			if next(look.values) == nil then
				look.values = nil
			end
		end
	else
		look.values = type(look.values) == "table" and look.values or {}
		look.values[key] = value
	end
	if value ~= old then
		Bus:Send("FeedLookChanged", name, key)
	end
	return true
end

-- Changes a value of a look's row design (Design.Set: refused with an error
-- when the design cannot take it). Returns the value as stored.
function Looks.SetDesign(name, part, key, value)
	local look = Looks.Get(name)
	if not look then
		return nil, "missing"
	end
	local stored = Design.Set(look, part, key, value)
	Bus:Send("FeedLookChanged", name, nil)
	return stored
end

-- Moving a part of a look's design with the mouse (Design.Drag): move(dx,
-- dy) puts it there, and says so.
function Looks.Drag(name, part, scale)
	local look = Looks.Get(name)
	if not look then
		return function() end
	end
	local move = Design.Drag(look, part, scale)
	return function(dx, dy)
		move(dx, dy)
		Bus:Send("FeedLookChanged", name, nil)
	end
end

-- Turns a look into the other view: its design starts afresh from that
-- view's built-in design, and its fill direction from that view's.
function Looks.SetView(name, view)
	local look = Looks.Get(name)
	if not look then
		return nil, "missing"
	elseif view ~= "rows" and view ~= "icons" then
		return nil, "view"
	end
	look.schema, look.base, look.changes = Design.SCHEMA, view == "icons" and "icons" or "large", nil
	if type(look.values) == "table" then
		look.values.direction = nil
		if next(look.values) == nil then
			look.values = nil
		end
	end
	Bus:Send("FeedLookChanged", name, nil)
	return true
end

-- The name of the player's look that a name would clash with, if any.
function Looks.Taken(name)
	local folded = Text.FoldCase(name)
	if folded == Text.FoldCase(L["Default"]) then
		return Looks.DEFAULT
	end
	for existing in pairs(all()) do
		if Text.FoldCase(existing) == folded then
			return existing
		end
	end
end

-- A free name like the given one: the name itself, or "Name 2", "Name 3", …,
-- with the name shortened so the number fits in the longest name allowed.
function Looks.FreeName(name)
	local free, number = name, 1
	while Looks.Taken(free) do
		number = number + 1
		local suffix = (" %d"):format(number)
		local base = Text.Truncate(name, Looks.MAX_NAME_LENGTH - #suffix):gsub("%s+$", "")
		free = base .. suffix
	end
	return free
end

local function validate(name, renaming)
	return Text.CheckName(name, all(), Looks.MAX_NAME_LENGTH, renaming)
end

-- A new look: the Large design, every setting at its default.
function Looks.Create(name)
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = { schema = Design.SCHEMA, base = "large" }
	return valid
end

function Looks.Copy(source, name)
	if not Looks.Get(source) then
		return nil, "missing"
	end
	local valid, err = validate(name)
	if not valid then
		return nil, err
	end
	all()[valid] = deepCopy(Looks.Get(source))
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

-- Renames a look in every profile that uses it.
function Looks.Rename(old, name)
	if old == Looks.DEFAULT then
		return nil, "default"
	end
	if not Looks.Get(old) then
		return nil, "missing"
	end
	local valid, err = validate(name, old)
	if not valid then
		return nil, err
	end
	if valid == old then
		return valid
	end
	local current = Looks.Current()
	local looks = all()
	looks[valid], looks[old] = looks[old], nil
	eachProfileFeed(function(values)
		if values.look == old then
			values.look = valid
		end
	end)
	Bus:Send("FeedLookRenamed", old, valid)
	if current == old then
		Bus:Send("SettingChanged", "LootFeed", "look", valid)
	end
	return valid
end

-- Back to the start, in its view: every setting at its default, the design afresh.
function Looks.Reset(name)
	local look = Looks.Get(name)
	if not look then
		return nil, "missing"
	end
	look.changes, look.values = nil, nil
	Bus:Send("FeedLookChanged", name, nil)
	return true
end

-- Profiles that used the deleted look move to Default.
function Looks.Delete(name)
	if name == Looks.DEFAULT then
		return nil, "default"
	end
	if not Looks.Get(name) then
		return nil, "missing"
	end
	local current = Looks.Current()
	all()[name] = nil
	eachProfileFeed(function(values)
		if values.look == name then
			values.look = nil
		end
	end)
	Bus:Send("FeedLookChanged", name, nil)
	if current == name then
		Bus:Send("SettingChanged", "LootFeed", "look", Looks.DEFAULT)
	end
	return true
end

-- A look from a profile text, as it may be kept: its design (Design.Clean)
-- and the settings it may hold; nil and "newer" for a design of a newer schema.
function Looks.Clean(data)
	local look, err = Design.Clean(data)
	if not look then
		return nil, err
	end
	local view = viewOf(look)
	if type(data.values) == "table" then
		for key, value in pairs(data.values) do
			if type(key) == "string" and allows(view, key, value) then
				look.values = look.values or {}
				look.values[key] = value
			end
		end
	end
	return look
end

-- Puts a look under a name, a new one or in place of a look's (an import).
function Looks.Put(name, look)
	all()[name] = deepCopy(look)
	Bus:Send("FeedLookChanged", name, nil)
end
