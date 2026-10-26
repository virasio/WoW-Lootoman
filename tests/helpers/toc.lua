-- Reads a TOC file the way the game does: metadata, file lines with inline
-- directives, and the packager's #@debug@ blocks.

local Toc = {}

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitList(text)
	local values = {}
	for value in text:gmatch("[^,]+") do
		values[#values + 1] = trim(value)
	end
	return values
end

-- "Data\Forever\Data.lua [AllowLoadGameType camelot]" → path and directives.
local function parseFileLine(line)
	local path, rest = line:match("^(.-)%s*(%[.*%])%s*$")
	path = path or line
	local directives = {}
	for directive in (rest or ""):gmatch("%[(.-)%]") do
		local name, values = directive:match("^(%S+)%s*(.*)$")
		if name then
			directives[name] = splitList(values)
		end
	end
	return (trim(path):gsub("\\", "/")), directives
end

function Toc.ParseText(text)
	local toc = { metadata = {}, files = {} }
	local inDebugBlock = false
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		if line:match("^#@debug@") then
			inDebugBlock = true
		elseif line:match("^#@end%-debug@") then
			inDebugBlock = false
		elseif line:match("^##") then
			local key, value = line:match("^##%s*([^:]-)%s*:%s*(.-)%s*$")
			if key then
				toc.metadata[key] = value
			end
		elseif not line:match("^#") and not line:match("^%s*$") then
			local path, directives = parseFileLine(line)
			toc.files[#toc.files + 1] = { path = path, directives = directives, debug = inDebugBlock }
		end
	end
	return toc
end

local function readFile(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

function Toc.Parse(path)
	return Toc.ParseText(readFile(path))
end

-- Files an XML file loads with <Script file="…"/> and <Include file="…"/>,
-- as paths next to the XML file, with forward slashes.
function Toc.ParseXml(path)
	local folder = path:match("^(.*)/[^/]*$")
	local files = {}
	for tag, _, file in readFile(path):gmatch("<(%a+)[^>]-%sfile%s*=%s*([\"'])(.-)%2") do
		if tag == "Script" or tag == "Include" then
			file = file:gsub("\\", "/")
			files[#files + 1] = folder and (folder .. "/" .. file) or file
		end
	end
	return files
end

return Toc
