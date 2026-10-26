local lfs = require("lfs")

-- The repository stands on its own: no file points at documents or folders
-- outside it, such as the specification's sections or the release plans.
-- The patterns are built from pieces, so this file does not match itself.
local OUTSIDE = {
	{ "\194\167", "a specification section sign" },
	{ "tech" .. "spec", "the specification" },
	{ "plans" .. "/", "the release plans" },
	{ "%.%./", "a folder above the repository" },
}

-- Folders that are not the project's own text: git, bundled libraries, and
-- tools installed into the checkout.
local SKIP = { [".git"] = true, Libs = true, [".luals"] = true, [".lua"] = true, [".luarocks"] = true, [".release"] = true }

-- Images are not text: their bytes can look like anything.
local IMAGES = { png = true, jpg = true, jpeg = true, tga = true, blp = true }

local function files(dir, found)
	found = found or {}
	for name in lfs.dir(dir) do
		if name ~= "." and name ~= ".." and not SKIP[name] then
			local path = dir .. "/" .. name
			if lfs.attributes(path, "mode") == "directory" then
				files(path, found)
			elseif name ~= ".DS_Store" and not IMAGES[(name:match("%.(%w+)$") or ""):lower()] then
				found[#found + 1] = path
			end
		end
	end
	return found
end

describe("the repository", function()
	it("does not point outside itself", function()
		for _, path in ipairs(files(".")) do
			local file = assert(io.open(path, "rb"))
			local number = 0
			for line in file:lines() do
				number = number + 1
				for _, outside in ipairs(OUTSIDE) do
					assert.is_nil(line:find(outside[1]), ("%s:%d mentions %s"):format(path, number, outside[2]))
				end
			end
			file:close()
		end
	end)
end)
