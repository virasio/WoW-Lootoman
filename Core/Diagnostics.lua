local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- The journal: what a bug report needs, kept in the saved data so it can be
-- read after a /reload instead of copied from the chat. The errors that pass
-- through Compat.ReportError, always, the last ERRORS of them with the start
-- of their stack; while the extended log is on, the last LOG_SIZE debug lines;
-- and the last self-test's lines. Each entry has the session time. An
-- account-wide section, no part of any profile text; it holds the character's
-- name and realm as the self-test prints them, and stays in the player's own
-- saved data. /ltm debug log clear empties it.
--
--   { schema = 1, selfTest = { at, client, lines = { … } }, log = { "12.34 text", … },
--     errors = { { at = 12.34, message = "…", stack = "…" }, … } }
local Diagnostics = {}
ns.Diagnostics = Diagnostics

Diagnostics.SECTION = "diagnostics"
Diagnostics.LOG_SIZE = 300
Diagnostics.ERRORS = 20
Diagnostics.STACK_LINES = 6

-- The errors of this session (since the UI loaded), for the bug report.
local sessionErrors = {}

function Diagnostics.Section()
	local section = Storage:GetGlobalSection(Diagnostics.SECTION)
	section.schema = section.schema or 1
	if type(section.log) ~= "table" then
		section.log = {}
	end
	if type(section.errors) ~= "table" then
		section.errors = {}
	end
	return section
end

local function trim(list, size)
	while #list > size do
		table.remove(list, 1)
	end
end

-- One debug line, the oldest dropped past LOG_SIZE.
function Diagnostics.Log(text)
	local log = Diagnostics.Section().log
	log[#log + 1] = ("%.2f %s"):format(Compat.GetTime(), tostring(text))
	trim(log, Diagnostics.LOG_SIZE)
end

-- The first lines of a stack.
local function head(stack, count)
	local lines = {}
	for line in tostring(stack or ""):gmatch("[^\n]+") do
		if #lines == count then
			break
		end
		lines[#lines + 1] = line
	end
	return table.concat(lines, "\n")
end

-- One error, the oldest dropped past ERRORS; kept in this session's list too.
-- Before the settings load (an error at startup) it is kept for the session only.
function Diagnostics.Error(message, stack)
	local entry = { at = Compat.GetTime(), message = tostring(message), stack = head(stack, Diagnostics.STACK_LINES) }
	sessionErrors[#sessionErrors + 1] = entry
	trim(sessionErrors, Diagnostics.ERRORS)
	if Storage.db then
		local errors = Diagnostics.Section().errors
		errors[#errors + 1] = entry
		trim(errors, Diagnostics.ERRORS)
	end
end

Compat.SetErrorListener(Diagnostics.Error)

function Diagnostics.SessionErrors()
	return sessionErrors
end

-- The journal's last count entries, errors and log lines in time order, each
-- a line of text ("12.34 text", "12.34 Error: message"); only the errors while
-- the extended log is off, or when only they are asked for.
function Diagnostics.Entries(count, errorsOnly)
	if not Storage.db then
		return {}
	end
	-- At the same time, the log's lines come before the errors: the log tells
	-- what led to one.
	local section, entries = Diagnostics.Section(), {}
	if not errorsOnly then
		for _, line in ipairs(section.log) do
			entries[#entries + 1] = { at = tonumber(tostring(line):match("^(%-?[%d.]+) ")) or 0, text = tostring(line) }
		end
	end
	for _, entry in ipairs(section.errors) do
		entries[#entries + 1] = { at = tonumber(entry.at) or 0, text = ("%.2f Error: %s"):format(tonumber(entry.at) or 0, tostring(entry.message)) }
	end
	for index, entry in ipairs(entries) do
		entry.index = index
	end
	table.sort(entries, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.index < b.index
	end)
	local lines = {}
	for index = math.max(1, #entries - count + 1), #entries do
		lines[#lines + 1] = entries[index].text
	end
	return lines
end

-- A new self-test run: its lines go into this table, which may still grow
-- (a line that comes from a timer). Nothing here may stop the self-test, which
-- reports what is broken itself: a broken client call, or settings that never
-- loaded (then the lines are not kept).
function Diagnostics.StartSelfTest()
	local ok, version, build = pcall(Compat.GetBuildInfo)
	local client = ok and ("%s (%s)"):format(tostring(version), tostring(build)) or "unknown"
	local run = { at = Compat.GetTime(), client = client, lines = {} }
	if Storage.db then
		Diagnostics.Section().selfTest = run
	end
	return run.lines
end

-- The log, the errors and the saved self-test, all gone.
function Diagnostics.Clear()
	sessionErrors = {}
	if not Storage.db then
		return
	end
	local section = Diagnostics.Section()
	section.log = {}
	section.errors = {}
	section.selfTest = nil
end
