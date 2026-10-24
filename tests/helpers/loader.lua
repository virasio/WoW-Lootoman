-- Loads the addon's Lua files in TOC order into one shared namespace, the way
-- the game does, so tests run against the real code.
--
-- Options:
--   toc       path to the TOC file (default "Lootoman.toc")
--   root      folder the TOC paths are relative to (default: the TOC's folder)
--   gameType  game type for [AllowLoadGameType] / [ExcludeLoadGameType] (default "standard")
--   debug     also load files inside #@debug@ blocks (default false)
--   replace   { ["Compat/Compat.lua"] = "tests/mocks/Compat.lua" } swaps files
--   skip      list of path prefixes not to load, e.g. { "Settings/" }
--   locale    what the global GetLocale() returns (default "enUS")
--
-- GetLocale is the only game global the loader provides, because Locales load
-- before Compat. Everything else comes through the Compat mock.

local Toc = require("tests.helpers.toc")

local Loader = {}

Loader.ADDON_NAME = "Lootoman"

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function allowedForGameType(entry, gameType)
	local allow = entry.directives.AllowLoadGameType
	if allow and not contains(allow, gameType) then
		return false
	end
	local exclude = entry.directives.ExcludeLoadGameType
	if exclude and contains(exclude, gameType) then
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
		-- XML files only build UI and are not loaded in tests.
		if wanted and entry.path:match("%.lua$") then
			local path = replace[entry.path] or (root .. "/" .. entry.path)
			local chunk = assert(loadfile(path))
			chunk(Loader.ADDON_NAME, ns)
		end
	end
	return ns
end

return Loader
