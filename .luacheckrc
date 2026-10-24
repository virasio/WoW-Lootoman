std = "lua51"
max_line_length = false
self = false

exclude_files = {
	".release/",
	-- Lua and LuaRocks installed into the checkout by CI.
	".lua/",
	".luarocks/",
}

-- WoW API globals are added here as the code starts using them.
read_globals = {
	"GetLocale",
}

files["tests/"] = {
	std = "+busted",
}
