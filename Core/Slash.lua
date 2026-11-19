local _, ns = ...
local Bus, Compat, L, Storage, Text = ns.Bus, ns.Compat, ns.L, ns.Storage, ns.Text

-- /ltm and /lootoman. Without a command they open the options; the player's
-- commands are few (help lists them), and the ones for testing and bug
-- reports go under /ltm debug, listed by /ltm debug help only.

Storage:RegisterGlobalDefaults({ debug = false })

-- A line of the extended log, for development and bug reports: kept in the
-- journal while the log is on, never printed. It is not translated.
function ns.Debug(text)
	if Storage.db and Storage:GetGlobal("debug") then
		ns.Diagnostics.Log(text)
	end
end

ns.Slash = {}

-- Each registry maps a command to its handler and its line of help; a handler
-- gets the rest of the line after the command's name.
local commands, debugCommands = {}, {}

local function register(registry, name, handler, help)
	assert(not registry[name], ("the command %s is already registered"):format(name))
	registry[name] = { handler = handler, help = help }
end

-- A player's command, /ltm <name>, with its line in /ltm help (translated).
function ns.Slash.Register(name, handler, help)
	register(commands, name, handler, help)
end

-- A command for testing and bug reports, /ltm debug <name>, with its line in
-- /ltm debug help (in English, as all debug output).
function ns.Slash.RegisterDebug(name, handler, help)
	register(debugCommands, name, handler, help)
end

-- The help lines of a registry, by the commands' names.
local function helpOf(registry)
	local names = {}
	for name, command in pairs(registry) do
		if command.help then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	local lines = {}
	for _, name in ipairs(names) do
		lines[#lines + 1] = registry[name].help
	end
	return lines
end

local function help()
	ns.Print(L["Commands:"])
	ns.Print(L["/ltm or /lootoman: open the options"])
	for _, line in ipairs(helpOf(commands)) do
		ns.Print(line)
	end
	ns.Print(L["/ltm help: list the commands"])
end

local function debugHelp()
	ns.Print("Debug commands:")
	for _, line in ipairs(helpOf(debugCommands)) do
		ns.Print(line)
	end
end

-- The command's name and the rest of the line.
local function split(line)
	return (line or ""):match("^%s*(%S*)%s*(.-)%s*$")
end

local function debug(argument)
	local name, rest = split(argument)
	if name == "" then
		ns.Print("Debug commands for testing and bug reports: /ltm debug help")
		return
	end
	local command = debugCommands[Text.FoldCase(name)]
	if command then
		command.handler(rest)
	else
		debugHelp()
	end
end

ns.Slash.RegisterDebug("help", debugHelp, "/ltm debug help: list the debug commands")

-- Values accepted by on/off commands, compared in lower case (a number is a
-- count of entries).
local SWITCH = { on = true, off = false }

-- The journal in the chat: the last LOG_LINES entries, or as many as asked
-- (up to the log's size); while the extended log is off, only the errors kept
-- and how to turn it on.
local LOG_LINES = 20

local function printJournal(count)
	local on = Storage.db and Storage:GetGlobal("debug")
	local lines = ns.Diagnostics.Entries(count, not on)
	for _, line in ipairs(lines) do
		ns.Print(line)
	end
	if not on then
		ns.Print("The extended log is off: /ltm debug log on")
	elseif #lines == 0 then
		ns.Print("The journal is empty.")
	end
end

-- The extended log: one switch for the whole account, not part of a profile
-- (the errors are kept whether it is on or off). "clear" empties the journal:
-- the log, the errors and the last self-test.
ns.Slash.RegisterDebug("log", function(argument)
	local word = Text.FoldCase(argument)
	local count = tonumber(word)
	if word == "" then
		printJournal(LOG_LINES)
	elseif count and count == math.floor(count) and count >= 1 and count <= ns.Diagnostics.LOG_SIZE then
		printJournal(count)
	elseif word == "clear" then
		ns.Diagnostics.Clear()
		ns.Print("The journal is cleared: the extended log, the errors and the saved self-test.")
	elseif SWITCH[word] ~= nil then
		Storage:SetGlobal("debug", SWITCH[word])
		ns.Print(SWITCH[word] and "The extended log is on for all characters."
			or "The extended log is off for all characters; errors are still kept.")
	else
		ns.Print(("Unknown value “%s”. Use /ltm debug log, a number from 1 to %d, on, off or clear.")
			:format(argument, ns.Diagnostics.LOG_SIZE))
	end
end, "/ltm debug log [N | on | off | clear]: the journal's last 20 or N entries; turn the extended log on or off; clear the journal")

ns.Slash.RegisterDebug("selftest", function()
	ns.SelfTest.Run({ print = true })
end, "/ltm debug selftest: check the addon against the game client")

Compat.RegisterSlashCommand("LOOTOMAN", { "/lootoman", "/ltm" }, function(message)
	local name, argument = split(message)
	name = Text.FoldCase(name)
	if name == "" then
		Bus:Send("OpenSettings")
	elseif name == "debug" then
		debug(argument)
	elseif commands[name] and name ~= "help" then
		commands[name].handler(argument)
	else
		help()
	end
end)
