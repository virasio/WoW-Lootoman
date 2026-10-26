-- Loads the addon's Lua files in TOC order into one shared namespace, the way
-- the game does, so tests run against the real code.
--
-- Options:
--   toc       path to the TOC file (default "Lootoman.toc")
--   root      folder the TOC paths are relative to (default: the TOC's folder)
--   gameType  the client: "standard" (retail, the default) or "camelot" (WoW Forever),
--             for [AllowLoadGameType] / [ExcludeLoadGameType] as that client reads them
--   debug     also load files inside #@debug@ blocks (default false)
--   replace   { ["Compat/Compat.lua"] = "tests/mocks/Compat.lua" } swaps files
--   skip      list of path prefixes not to load, e.g. { "Settings/" }
--   locale    what the global GetLocale() returns (default "enUS")
--
-- GetLocale is the only game global Load provides, because Locales load before
-- Compat. Everything else comes through the Compat mock, and LoadAddon also
-- installs the fake frame API of tests/mocks/UI.lua (Loader.ui).
--
-- Third-party libraries in Libs/ are never loaded: they need the real client.

local Toc = require("tests.helpers.toc")
local UI = require("tests.mocks.UI")

local Loader = {}

Loader.ADDON_NAME = "Lootoman"

local LIBRARIES = "Libs/"

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- The clients a test can be: the game type names each one matches in TOC
-- conditions, the names it does not know, and what it puts in place of [Game]
-- and [Family]. The retail client (12.1.5) does not know camelot, and a
-- condition whose names it does not know does not apply: a file allowed only
-- for camelot loads on retail too, unless a condition it knows excludes it
-- (seen in game, and why Auctionator and BugSack exclude standard as well).
local CLIENTS = {
	standard = { matches = { "standard", "mainline" }, unknown = { "camelot" }, game = "Standard", family = "Mainline" },
	camelot = { matches = { "camelot", "mainline" }, unknown = {}, game = "Camelot", family = "Mainline" },
}

local function client(gameType)
	return CLIENTS[gameType] or error("unknown game type " .. tostring(gameType))
end

-- Whether a condition's names include one the client matches; nil when the
-- client knows none of them, so the condition does not apply.
local function matches(names, gameType)
	local known = false
	for _, name in ipairs(names) do
		if not contains(client(gameType).unknown, name) then
			known = true
			if contains(client(gameType).matches, name) then
				return true
			end
		end
	end
	if known then
		return false
	end
	return nil
end

local function allowedForGameType(entry, gameType)
	local allow = entry.directives.AllowLoadGameType
	if allow and matches(allow, gameType) == false then
		return false
	end
	local exclude = entry.directives.ExcludeLoadGameType
	if exclude and matches(exclude, gameType) then
		return false
	end
	return true
end

local function skipped(path, prefixes)
	for _, prefix in ipairs(prefixes) do
		if path:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function Loader.Load(options)
	options = options or {}
	local tocPath = options.toc or "Lootoman.toc"
	local root = options.root or tocPath:match("^(.*)/[^/]*$") or "."
	local gameType = options.gameType or "standard"
	client(gameType)
	local replace = options.replace or {}
	local skip = options.skip or {}
	local locale = options.locale or "enUS"

	rawset(_G, "GetLocale", function()
		return locale
	end)

	local ns = {}
	for _, entry in ipairs(Toc.Parse(tocPath).files) do
		local wanted = (options.debug or not entry.debug)
			and allowedForGameType(entry, gameType)
			and not skipped(entry.path, skip)
			and not skipped(entry.path, { LIBRARIES })
		-- XML files only build UI and are not loaded in tests.
		if wanted and entry.path:match("%.lua$") then
			local path = replace[entry.path] or (root .. "/" .. entry.path)
			local chunk = assert(loadfile(path))
			chunk(Loader.ADDON_NAME, ns)
		end
	end
	return ns
end

-- The addon as unit tests use it: Compat replaced by the mock, no Settings UI,
-- and a fresh fake frame API in Loader.ui, so UI modules can start. The mock
-- answers metadata from the TOC, with [Game] and [Family] filled in as the
-- client does.
function Loader.LoadAddon(options)
	Loader.ui = UI.Install()
	local merged = {
		replace = { ["Compat/Compat.lua"] = "tests/mocks/Compat.lua" },
		skip = { "Settings/" },
	}
	for key, value in pairs(options or {}) do
		merged[key] = value
	end
	local ns = Loader.Load(merged)
	local current = client(merged.gameType or "standard")
	local metadata = {}
	for key, value in pairs(Toc.Parse(merged.toc or "Lootoman.toc").metadata) do
		metadata[key] = value:gsub("%[Game%]", current.game):gsub("%[Family%]", current.family)
	end
	ns.Compat.Test.state.metadata[Loader.ADDON_NAME] = metadata
	return ns
end

-- Plays the game's start sequence on an addon loaded with LoadAddon:
-- ADDON_LOADED with the given saved variables, then PLAYER_LOGIN.
function Loader.Start(ns, saved)
	local Test = ns.Compat.Test
	for name, value in pairs(saved or {}) do
		Test.state.saved[name] = value
	end
	Test.FireEvent("ADDON_LOADED", Loader.ADDON_NAME)
	Test.FireEvent("PLAYER_LOGIN")
	return ns
end

return Loader
