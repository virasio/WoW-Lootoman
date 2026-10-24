local lfs = require("lfs")
local Toc = require("tests.helpers.toc")

-- Top-level folders in load order (techspec §3).
local LAYERS = { "Locales", "Compat", "Data", "Core", "Rules", "Providers", "Integrations", "Modules", "Settings", "Dev" }

-- Top-level folders that are not part of the addon.
local NOT_ADDON = { tests = true }

local function addonFiles(dir, prefix, found)
	found = found or {}
	for name in lfs.dir(dir) do
		-- Skips ".", ".." and dot folders such as .git and .github.
		if not name:match("^%.") then
			local path = dir .. "/" .. name
			local relative = prefix and (prefix .. "/" .. name) or name
			if lfs.attributes(path, "mode") == "directory" then
				if prefix or not NOT_ADDON[name] then
					addonFiles(path, relative, found)
				end
			elseif name:match("%.lua$") or name:match("%.xml$") then
				found[#found + 1] = relative
			end
		end
	end
	return found
end

describe("Lootoman.toc", function()
	local toc = Toc.Parse("Lootoman.toc")

	it("has the metadata the game and the packager need", function()
		assert.equals("Lootoman", toc.metadata.Title)
		assert.equals("@project-version@", toc.metadata.Version)
		assert.matches("^%d+[%d, ]*$", toc.metadata.Interface)
	end)

	it("lists only files that exist", function()
		for _, entry in ipairs(toc.files) do
			assert.equals("file", lfs.attributes(entry.path, "mode"), entry.path .. " is missing")
		end
	end)

	it("lists every Lua and XML file of the addon", function()
		local listed = {}
		for _, entry in ipairs(toc.files) do
			listed[entry.path] = true
		end
		for _, path in ipairs(addonFiles(".")) do
			assert.is_true(listed[path] == true, path .. " is not in the TOC")
		end
	end)

	it("loads the layers bottom-up", function()
		local order = {}
		for index, layer in ipairs(LAYERS) do
			order[layer] = index
		end
		local last = 0
		for _, entry in ipairs(toc.files) do
			local index = order[entry.path:match("^([^/]+)/")]
			assert.is_not_nil(index, entry.path .. " is not in a layer folder")
			assert.is_true(index >= last, entry.path .. " loads after a higher layer")
			last = index
		end
	end)
end)
