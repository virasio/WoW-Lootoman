local lfs = require("lfs")
local Toc = require("tests.helpers.toc")

-- Top-level folders in load order: the addon's layers, bottom-up.
local LAYERS = { "Libs", "Locales", "Compat", "Data", "Core", "Rules", "Providers", "Integrations", "Modules", "Settings", "Dev" }

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

-- Every file the game loads: the TOC's files and, inside them, the files that
-- XML files load (libraries list their files in an embed.xml).
local function loadedFiles(toc)
	local files = {}
	local function add(path)
		files[#files + 1] = path
		if path:match("%.xml$") and lfs.attributes(path, "mode") == "file" then
			for _, included in ipairs(Toc.ParseXml(path)) do
				add(included)
			end
		end
	end
	for _, entry in ipairs(toc.files) do
		add(entry.path)
	end
	return files
end

describe("Lootoman.toc", function()
	local toc = Toc.Parse("Lootoman.toc")

	it("has the metadata the game and the packager need", function()
		assert.equals("Lootoman", toc.metadata.Title)
		assert.equals("@project-version@", toc.metadata.Version)
		assert.matches("^%d+[%d, ]*$", toc.metadata.Interface)
		assert.equals("LootomanDB", toc.metadata.SavedVariables)
		assert.equals("LootomanCharDB", toc.metadata.SavedVariablesPerCharacter)
		assert.matches("^%d+$", toc.metadata["X-Curse-Project-ID"])
		assert.equals("[Game]", toc.metadata["X-Game"])
		assert.equals("[Family]", toc.metadata["X-Family"])
	end)

	it("loads only files that exist", function()
		for _, path in ipairs(loadedFiles(toc)) do
			assert.equals("file", lfs.attributes(path, "mode"), path .. " is missing")
		end
	end)

	it("loads every Lua and XML file of the addon", function()
		local listed = {}
		for _, path in ipairs(loadedFiles(toc)) do
			listed[path] = true
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

	it("loads the development files only from the repository", function()
		for _, entry in ipairs(toc.files) do
			assert.equals(entry.path:match("^Dev/") ~= nil, entry.debug, entry.path)
		end
	end)
end)

-- What the packager puts into the release: every file in git, less what
-- .pkgmeta ignores. Only the addon itself, its README, its license and its
-- changelog may go.
describe("the release package", function()
	local function ignored()
		local names, inList = {}, false
		for line in io.lines(".pkgmeta") do
			if line:match("^ignore:") then
				inList = true
			elseif line:match("^%S") then
				inList = false
			elseif inList and line:match("^%s*%-") then
				names[line:match("^%s*%-%s*(.-)%s*$")] = true
			end
		end
		return names
	end

	it("leaves out the tests, the development files and the tool configs", function()
		local names = ignored()
		for _, name in ipairs({ "tests", "Dev", ".github", ".busted", ".editorconfig", ".luacheckrc", ".luarc.json" }) do
			assert.is_true(names[name] == true, name .. " is not ignored by .pkgmeta")
		end
	end)

	it("holds only the addon, its README, its license and its changelog", function()
		local allowed = { ["Lootoman.toc"] = true, ["README.md"] = true, LICENSE = true, ["CHANGELOG.md"] = true,
			[".pkgmeta"] = true, [".gitignore"] = true }
		for _, layer in ipairs(LAYERS) do
			allowed[layer] = true
		end
		for name in pairs(ignored()) do
			allowed[name] = true
		end
		local git = assert(io.popen("git ls-files"))
		for path in git:lines() do
			local top = path:match("^[^/]+")
			assert.is_true(allowed[top] == true, path .. " would go into the package")
		end
		git:close()
	end)

	it("uploads the hand-written changelog, which has an entry", function()
		local filename
		for line in io.lines(".pkgmeta") do
			filename = filename or line:match("^%s+filename:%s*(%S+)")
		end
		assert.equals("CHANGELOG.md", filename)
		local entry
		for line in io.lines(filename) do
			entry = entry or line:match("^## (%S+)")
		end
		assert.is_not_nil(entry, "CHANGELOG.md has no release entry")
	end)
end)
