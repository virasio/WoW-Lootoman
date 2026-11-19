local _, ns = ...
local Compat, Storage = ns.Compat, ns.Storage

-- What a bug report needs, kept in the saved data so it can be read after a
-- /reload instead of copied from the chat: the last self-test's lines, and
-- while debug messages are on, the last LOG_SIZE of them, each with the
-- session time. An account-wide section, no part of any profile text; it holds
-- the character's name and realm as the self-test prints them, and stays in
-- the player's own saved data. /ltm debug log clear empties it.
--
--   { schema = 1, selfTest = { at, client, lines = { … } }, log = { "12.34 text", … } }
local Diagnostics = {}
ns.Diagnostics = Diagnostics

Diagnostics.SECTION = "diagnostics"
Diagnostics.LOG_SIZE = 300

function Diagnostics.Section()
	local section = Storage:GetGlobalSection(Diagnostics.SECTION)
	section.schema = section.schema or 1
	if type(section.log) ~= "table" then
		section.log = {}
	end
	return section
end

-- One debug line, the oldest dropped past LOG_SIZE.
function Diagnostics.Log(text)
	local log = Diagnostics.Section().log
	log[#log + 1] = ("%.2f %s"):format(Compat.GetTime(), tostring(text))
	while #log > Diagnostics.LOG_SIZE do
		table.remove(log, 1)
	end
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

function Diagnostics.Clear()
	if not Storage.db then
		return
	end
	local section = Diagnostics.Section()
	section.log = {}
	section.selfTest = nil
end
