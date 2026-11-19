local _, ns = ...
local Bus, Compat, L, Storage, Text = ns.Bus, ns.Compat, ns.L, ns.Storage, ns.Text

-- /ltm and /lootoman. Without a command they open the options; the player's
-- commands are few (help lists them), and the ones for testing and bug
-- reports go under /ltm debug, listed by /ltm debug help only.

Storage:RegisterGlobalDefaults({ debug = false })

-- Debug output for development and bug reports, kept in the saved
-- diagnostics while the extended log is on. It is not translated.
function ns.Debug(text)
	if Storage.db and Storage:GetGlobal("debug") then
		ns.Print("|cff999999" .. text .. "|r")
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

-- Values accepted by on/off commands, compared in lower case.
local SWITCH = {
	on = true,
	["1"] = true,
	off = false,
	["0"] = false,
}

-- The extended log: one switch for the whole account, not part of a profile.
-- "clear" empties the saved diagnostics (the log and the last self-test).
ns.Slash.RegisterDebug("log", function(argument)
	if Text.FoldCase(argument) == "clear" then
		ns.Diagnostics.Clear()
		ns.Print("The extended log and the saved self-test are cleared.")
		return
	end
	if argument ~= "" then
		local enabled = SWITCH[Text.FoldCase(argument)]
		if enabled == nil then
			ns.Print(("Unknown value “%s”. Use /ltm debug log on, off or clear."):format(argument))
			return
		end
		Storage:SetGlobal("debug", enabled)
	end
	ns.Print(Storage:GetGlobal("debug") and "The extended log is on for all characters."
		or "The extended log is off for all characters.")
end, "/ltm debug log [on | off | clear]: turn the extended log on or off, or clear it")

ns.Slash.RegisterDebug("selftest", function()
	ns.SelfTest.Run()
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
