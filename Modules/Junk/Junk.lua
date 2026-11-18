local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Getting rid of junk (Rules/Junk.lua decides what it is): a button by the
-- loot window opens the sort window, a bag-like window with the junk on top,
-- to delete things; at a merchant, Lootoman's sell-junk button sells the junk
-- or opens the same window to pick what to sell. Dragging an item between the
-- sections of either window marks it. Turned off, the game's own sell-junk
-- button is back.
local Junk = ns.Modules:Register({
	name = "Junk",
	title = L["Junk"],
	switchLabel = L["Enable Junk Management"],
	description = L["Throw junk away by the loot window or the bags and sell it at merchants, with suggestions of what else can go. Turned off, the game's own sell-junk button is back."],
	-- Only while QuestieDB is not working, decided as the options page is built.
	switchNote = function()
		if not ns.Integrations.QuestieDB.Working() then
			return L["Suggestions about quests are better with QuestieDB, which knows every quest an item is for."]
		end
	end,
	defaults = {
		enabled = true,
		-- The sort window's button on the loot window: "never", "always" or "full".
		tossButton = "full",
		-- Small on the loot window's title bar, or large next to it.
		tossStyle = "large",
		-- The bag button (BagButton.lua): "never", "small" (in the bag window's
		-- title), "large" (above the bag window) or "own" (on its own, placed in
		-- Edit Mode), and the size of the one on its own.
		bagButton = "small",
		bagButtonSize = 37,
		-- At Merchants (SellButton.lua): "auto", "button" or "window".
		selling = "window",
		-- The suggestion rules (Rules/Suggest.lua, Sections.SWITCHES).
		suggestQuestDone = true,
		suggestLeftovers = true,
		suggestUnusable = true,
		suggestKnown = true,
		suggestOutgrown = true,
	},
	-- Under the switch QuestieDB's address (with the note), the junk list, how
	-- the windows open, then the suggestions.
	mainSettings = {
		{ kind = "button", label = L["Copy the QuestieDB Address"],
			tooltip = L["The game cannot open a browser: copy the address and open it in yours."],
			visible = function()
				return not ns.Integrations.QuestieDB.Working()
			end,
			click = function()
				ns.SettingsPanel.CopyText("QuestieDB", L["Copy the address (Ctrl+C, or Cmd+C on a Mac) and open it in your browser."],
					ns.Integrations.QuestieDB.ADDRESS)
			end },
		{ kind = "button", label = L["Set Up the Junk List"],
			tooltip = L["Every item you marked as junk or as not junk, to remove marks."],
			click = function()
				ns.JunkList.Open()
			end },
		{ kind = "choice", key = "tossButton", label = L["Loot Window Button"],
			tooltip = L["The button by the loot window opens a window of your bags with the junk on top, to throw things away."],
			choices = { { "never", L["Never"] }, { "always", L["Always"] }, { "full", L["When the bags are full"] } } },
		{ kind = "choice", key = "tossStyle", label = L["Style"], level = 2,
			choices = { { "small", L["Small, in the window's title"] }, { "large", L["Large, next to the window"] } },
			enabledWhen = function()
				return ns.Storage:Get("Junk", "tossButton") ~= "never"
			end },
		{ kind = "choice", key = "bagButton", label = L["Bag Window Button"],
			tooltip = L["The button by the bag window opens the same window. On its own, it is placed and sized in Edit Mode."],
			choices = { { "never", L["Never"] }, { "small", L["Small, in the title"] },
				{ "large", L["Large, above the window"] }, { "own", L["Large, on its own"] } } },
		{ kind = "choice", key = "selling", label = L["At Merchants"],
			choices = { { "auto", L["Sell automatically"] }, { "button", L["Sell with the sell button"] },
				{ "window", L["The sell button opens the sort window"] } } },
		-- The rules of Rules/Suggest.lua, by their switches (Sections.SWITCHES).
		{ kind = "heading", label = L["Suggestions"], gap = 16 },
		{ kind = "checkboxes", level = 2, columns = 2, items = {
			{ kind = "checkbox", key = "suggestQuestDone", label = L["Quest Done"],
				tooltip = L["Items that start a quest you have done, and quest items no quest of yours needs any more."] },
			{ kind = "checkbox", key = "suggestLeftovers", label = L["Leftovers from Quests"],
				tooltip = L["Items your finished quests wanted, when the auction house pays little more for them than a merchant."] },
			{ kind = "checkbox", key = "suggestUnusable", label = L["Your Class Can't Use It"],
				tooltip = L["Soulbound gear your class cannot use."] },
			{ kind = "checkbox", key = "suggestKnown", label = L["Already Known"],
				tooltip = L["Recipes you know, and mounts, pets, toys and heirlooms you already have."] },
			{ kind = "checkbox", key = "suggestOutgrown", label = L["Outgrown"],
				tooltip = L["Food, drink, potions, elixirs, flasks and bandages for characters %d levels or more below yours."]:format(ns.Rules.Suggest.OUTGROWN) },
		} },
	},
})

-- Texts of 0.1 to 0.4 (format 1) held selling as two switches and the large
-- button's size and place: they become the choices of now, as saved data did
-- (Migrations.JunkFrom).
ns.Share.RegisterUpgrade(1, function(data)
	local sections = type(data.sections) == "table" and data.sections or nil
	local junk = sections and sections["module:Junk"]
	if type(junk) == "table" then
		sections["module:Junk"] = ns.Migrations.JunkFrom(junk)
	end
end)

-- The junk list (the profile's marks) as a part of profile texts, under the
-- module's settings: { junk = { itemID, … }, notJunk = { itemID, … } }. It
-- merges with the profile's marks (what is new is added; an item marked
-- otherwise here keeps its mark and comes back as a conflict for the player
-- to settle: { itemID, mine, theirs }), or replaces them.
local MARK_LISTS = { "junk", "notJunk" }

local function savedMarks(profile)
	local sections = type(profile.sections) == "table" and profile.sections or nil
	return sections and type(sections.marks) == "table" and sections.marks or nil
end

ns.Share.RegisterPart({
	name = "marks",
	module = "Junk",
	label = L["Junk List"],
	ways = { { "merge", L["Merge with my list"] }, { "replace", L["Replace my list"] } },
	get = function(profile)
		local data = { junk = {}, notJunk = {} }
		for itemID, mark in pairs(savedMarks(profile) or {}) do
			if type(itemID) == "number" and data[mark] then
				table.insert(data[mark], itemID)
			end
		end
		table.sort(data.junk)
		table.sort(data.notJunk)
		return data
	end,
	set = function(profile, data, _, way)
		local marks, conflicts = {}, {}
		if way ~= "replace" then
			for itemID, mark in pairs(savedMarks(profile) or {}) do
				if type(itemID) == "number" and ns.Marks.KINDS[mark] then
					marks[itemID] = mark
				end
			end
		end
		for _, mark in ipairs(MARK_LISTS) do
			for _, itemID in ipairs(data[mark]) do
				local mine = marks[itemID]
				if mine == nil then
					marks[itemID] = mark
				elseif mine ~= mark then
					conflicts[#conflicts + 1] = { itemID = itemID, mine = mine, theirs = mark }
				end
			end
		end
		profile.sections = type(profile.sections) == "table" and profile.sections or {}
		profile.sections.marks = marks
		table.sort(conflicts, function(a, b)
			return a.itemID < b.itemID
		end)
		return { conflicts = conflicts }
	end,
	-- The items marked otherwise here than in the text, for the player to settle
	-- (the junk list window).
	imported = function(result)
		if #result.conflicts > 0 and ns.JunkList then
			ns.JunkList.ShowConflicts(result.conflicts)
		end
	end,
	-- Item IDs only, each in one list (the first it is in).
	clean = function(data)
		local cleaned, seen = { junk = {}, notJunk = {} }, {}
		for _, mark in ipairs(MARK_LISTS) do
			for _, itemID in ipairs(type(data[mark]) == "table" and data[mark] or {}) do
				if type(itemID) == "number" and itemID > 0 and itemID == math.floor(itemID) and not seen[itemID] then
					seen[itemID] = true
					table.insert(cleaned[mark], itemID)
				end
			end
		end
		return cleaned
	end,
})

-- The module's parts (the toss button and window, the sale, the sell button
-- and window), started in order with the module and stopped in reverse:
-- part.Enable() and part.Disable(). Disable also undoes a part that started
-- halfway, or did not start.
local parts = {}

function Junk.AddPart(part)
	parts[#parts + 1] = part
end

-- Parts listen through the module, so several of them can listen to the same
-- event or message, and all of it stops with the module.
local listeners = { events = {}, messages = {} }

local function listen(kind, name, fn)
	local list = listeners[kind][name]
	if not list then
		list = {}
		listeners[kind][name] = list
		-- One broken part is reported and the others still hear it. (Lua 5.1's
		-- xpcall passes no arguments on.)
		local function dispatch(...)
			local count, args = select("#", ...), { ... }
			for _, listener in ipairs(list) do
				xpcall(function()
					listener(unpack(args, 1, count))
				end, Compat.ReportError)
			end
		end
		if kind == "events" then
			Junk:OnEvent(name, dispatch)
		else
			Junk:On(name, dispatch)
		end
	end
	list[#list + 1] = fn
end

-- fn(event, ...) for a game event while the module is on.
function Junk.ListenEvent(event, fn)
	listen("events", event, fn)
end

-- fn(message, ...) for a bus message while the module is on.
function Junk.Listen(message, fn)
	listen("messages", message, fn)
end

function Junk:OnEnable()
	for _, part in ipairs(parts) do
		part.Enable()
	end
end

function Junk:OnDisable()
	for index = #parts, 1, -1 do
		xpcall(parts[index].Disable, Compat.ReportError)
	end
	listeners = { events = {}, messages = {} }
end
