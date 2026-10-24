std = "lua51"
max_line_length = false
self = false

exclude_files = {
	".release/",
}

-- WoW API globals are added to read_globals as the code starts using them.

files["tests/"] = {
	std = "+busted",
}
