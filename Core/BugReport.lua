local addonName, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- The bug report: one text for the player to copy into an issue (the bug
-- report window shows it), in English as all debug output. Its parts:
--   the head line: the addon's version, the client, the game and the locale;
--   a self-test run afresh, not printed, the character not named;
--   the errors of this session, each with its time and the start of its stack;
--   the extended log's last LOG_LINES lines, or that it is off;
--   the options that differ from their defaults (the profile's and the
--   account's), and what other parts add (the loot feed's look);
--   the related addons loaded, with their versions.
-- At most MAX characters, the log cut first. The character's name and realm
-- appear nowhere: the self-test leaves them out, and anything that still
-- holds them (a log line) has them replaced.
local BugReport = {}
ns.BugReport = BugReport

BugReport.MAX = 30000
BugReport.LOG_LINES = 100
-- The addons a report may need to know about: bags, prices, quests,
-- nameplates and loot, as their folders are named.
BugReport.ADDONS = { "Auctionator", "QuestieDB", "Questie", "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags",
	"ElvUI", "Platynator", "Plater", "Plumber", "SpeedyAutoLoot", "BugSack", "Lueur", "Ogiroll", "KeepOrToss", "Scrap",
	"ForeverLootSparkles" }

-- Lines that other parts add under the options: fn() returns a list of lines.
local parts = {}

function BugReport.AddPart(fn)
	parts[#parts + 1] = fn
end

-- A value of a call that may fail, or "?".
local function safe(fn, ...)
	local ok, value = pcall(fn, ...)
	return ok and tostring(value) or "?"
end

local function head()
	local ok, version, build, _, interface = pcall(Compat.GetBuildInfo)
	if not ok then
		version, build, interface = "?", "?", "?"
	end
	return ("Lootoman %s · %s (%s), interface %s · game %s, project %s · locale %s · %s"):format(
		safe(Compat.GetAddOnMetadata, addonName, "Version"), tostring(version), tostring(build), tostring(interface),
		safe(Compat.GetAddOnMetadata, addonName, "X-Game"), safe(Compat.GetProjectID), tostring(ns.Locales.current),
		safe(Compat.GetDate))
end

local function sorted(map)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- The profile's values and the account's that differ from the defaults: a
-- profile keeps only those.
local function options()
	local lines = {}
	if not Storage.db then
		return { "(the settings did not load)" }
	end
	local modules = Storage:GetProfile().modules or {}
	for _, module in ipairs(sorted(modules)) do
		local values = modules[module]
		if type(values) == "table" then
			for _, key in ipairs(sorted(values)) do
				lines[#lines + 1] = ("%s.%s = %s"):format(module, key, tostring(values[key]))
			end
		end
	end
	for _, key in ipairs(sorted(Storage.db.global or {})) do
		lines[#lines + 1] = ("account.%s = %s"):format(key, tostring(Storage.db.global[key]))
	end
	for _, part in ipairs(parts) do
		local ok, more = pcall(part)
		for _, line in ipairs(ok and type(more) == "table" and more or { "(" .. tostring(more) .. ")" }) do
			lines[#lines + 1] = line
		end
	end
	return #lines > 0 and lines or { "none" }
end

local function addons()
	local lines = {}
	for _, name in ipairs(BugReport.ADDONS) do
		if Compat.IsAddOnLoaded(name) then
			lines[#lines + 1] = ("%s %s"):format(name, tostring(Compat.GetAddOnMetadata(name, "Version") or "?"))
		end
	end
	return #lines > 0 and table.concat(lines, ", ") or "none"
end

local function errors()
	local lines = {}
	for _, entry in ipairs(ns.Diagnostics.SessionErrors()) do
		lines[#lines + 1] = ("%.2f %s"):format(tonumber(entry.at) or 0, tostring(entry.message))
		for line in tostring(entry.stack or ""):gmatch("[^\n]+") do
			lines[#lines + 1] = "    " .. line
		end
	end
	return lines
end

local function log()
	if not (Storage.db and Storage:GetGlobal("debug")) then
		return nil
	end
	local kept, lines = ns.Diagnostics.Section().log, {}
	for index = math.max(1, #kept - BugReport.LOG_LINES + 1), #kept do
		lines[#lines + 1] = kept[index]
	end
	return lines
end

-- The character's name and realm, as whole words anywhere in the text,
-- replaced (a realm named as a word in a function's name stays there).
local function anonymous(text)
	local ok, key = pcall(Compat.GetCharacterKey)
	if not ok or type(key) ~= "string" then
		return text
	end
	local name, realm = key:match("^(.-)%-(.+)$")
	for _, value in ipairs({ { key, "<character>" }, { name, "<name>" }, { realm, "<realm>" } }) do
		if value[1] and #value[1] > 1 then
			text = text:gsub("%f[%w]" .. value[1]:gsub("%p", "%%%0") .. "%f[%W]", value[2])
		end
	end
	return text
end

-- The report's text.
function BugReport.Build()
	local selfTest = ns.SelfTest.Run({ anonymous = true })
	local errorLines = errors()
	local logLines = log()
	local function assemble(logShown)
		local text = {
			head(),
			"",
			"Self-test",
		}
		for index = 2, #selfTest do
			text[#text + 1] = selfTest[index]
		end
		text[#text + 1] = ""
		text[#text + 1] = ("Errors this session (%d)"):format(#ns.Diagnostics.SessionErrors())
		for _, line in ipairs(errorLines) do
			text[#text + 1] = "  " .. line
		end
		text[#text + 1] = ""
		if logShown then
			text[#text + 1] = ("Extended log (the last %d lines)"):format(#logShown)
			for _, line in ipairs(logShown) do
				text[#text + 1] = "  " .. line
			end
		else
			text[#text + 1] = "Extended log: off"
		end
		text[#text + 1] = ""
		text[#text + 1] = "Options that differ from the defaults"
		for _, line in ipairs(options()) do
			text[#text + 1] = "  " .. line
		end
		text[#text + 1] = ""
		text[#text + 1] = "Related addons loaded: " .. addons()
		return anonymous(table.concat(text, "\n"))
	end
	local Text = ns.Text
	local text = assemble(logLines)
	-- Too long: the log's oldest lines go first, then the end of the text.
	while Text.Length(text) > BugReport.MAX and logLines and #logLines > 0 do
		local drop = math.max(1, math.floor(#logLines / 4))
		for _ = 1, drop do
			table.remove(logLines, 1)
		end
		text = assemble(logLines)
	end
	if Text.Length(text) > BugReport.MAX then
		text = Text.Truncate(text, BugReport.MAX - 6) .. "\n(cut)"
	end
	return text
end
