local lfs = require("lfs")

-- Blizzard functions that run their own code on Lootoman's behalf and leave
-- Blizzard's secure state tainted. RegisterGameMenuEscHandler sorts Blizzard's
-- list of Escape handlers from the caller's code; afterwards the game menu
-- cannot stop a cast, and the game blames Lootoman (ADDON_ACTION_FORBIDDEN,
-- SpellStopCasting). Frames close on Escape through UISpecialFrames instead.
local TAINTING = { "RegisterGameMenuEscHandler" }

-- The addon's own Lua files: everything but tests, libraries and tools.
local SKIP = { [".git"] = true, Libs = true, tests = true, [".luals"] = true, [".lua"] = true, [".luarocks"] = true }

local function luaFiles(dir, found)
	found = found or {}
	for name in lfs.dir(dir) do
		if name ~= "." and name ~= ".." and not SKIP[name] then
			local path = dir .. "/" .. name
			if lfs.attributes(path, "mode") == "directory" then
				luaFiles(path, found)
			elseif name:match("%.lua$") then
				found[#found + 1] = path
			end
		end
	end
	return found
end

describe("the addon", function()
	it("never calls Blizzard functions that taint its secure state", function()
		for _, path in ipairs(luaFiles(".")) do
			local number = 0
			for line in io.lines(path) do
				number = number + 1
				local code = line:gsub("%-%-.*$", "")
				for _, name in ipairs(TAINTING) do
					assert.is_nil(code:find(name, 1, true), ("%s:%d calls %s"):format(path, number, name))
				end
			end
		end
	end)
end)
