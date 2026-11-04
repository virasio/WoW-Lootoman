local lfs = require("lfs")
local Loader = require("tests.helpers.loader")

-- The bus messages in the code against the table in Core/EventBus.lua.

-- Folders that are not the addon's code: git, bundled libraries, tools, and
-- the tests, which send messages of their own.
local SKIP = { [".git"] = true, Libs = true, tests = true, [".luals"] = true, [".lua"] = true, [".luarocks"] = true, [".release"] = true }

-- Where a message name may come from a variable: the bus itself, the module
-- mixin that hands its listeners to the bus, and modules that hand their parts'
-- listeners on (Module.Listen).
local FORWARDERS = { ["Core/EventBus.lua"] = true, ["Core/Modules.lua"] = true, ["Modules/Junk/Junk.lua"] = true }

-- Calls that send or listen to a message.
local SENDS = { Send = true }
local LISTENS = { On = true, Off = true, Listen = true }

local function files(dir, found)
	found = found or {}
	for name in lfs.dir(dir) do
		if name ~= "." and name ~= ".." and not SKIP[name] then
			local path = dir == "." and name or (dir .. "/" .. name)
			if lfs.attributes(path, "mode") == "directory" then
				files(path, found)
			elseif name:match("%.lua$") then
				found[#found + 1] = path
			end
		end
	end
	return found
end

-- Each use as { name, where }: sends (Bus:Send), listens (Bus:On, a module's
-- self:On, Bus:Off, a module part's Module.Listen) and calls whose name is not
-- a string literal.
local function uses()
	local found = { sends = {}, listens = {}, dynamic = {} }
	for _, path in ipairs(files(".")) do
		local number = 0
		for line in io.lines(path) do
			number = number + 1
			local where = ("%s:%d"):format(path, number)
			if not line:match("^%s*function") and not line:match("^%s*%-%-") then
				-- The name is the first argument; the call's other arguments may go on
				-- over the next lines.
				for call, quote, name in line:gmatch('[%w_]+[:.](%u%a+)%(%s*("?)([%w_]*)') do
					if SENDS[call] or LISTENS[call] then
						if quote == "" or name == "" then
							if not FORWARDERS[path] then
								found.dynamic[#found.dynamic + 1] = where
							end
						elseif SENDS[call] then
							found.sends[#found.sends + 1] = { name, where }
						else
							found.listens[#found.listens + 1] = { name, where }
						end
					end
				end
			end
		end
	end
	return found
end

describe("bus messages", function()
	local messages, found, sent, heard

	setup(function()
		messages = Loader.LoadAddon().Bus.MESSAGES
		found = uses()
		sent, heard = {}, {}
		for _, use in ipairs(found.sends) do
			sent[use[1]] = use[2]
		end
		for _, use in ipairs(found.listens) do
			heard[use[1]] = use[2]
		end
	end)

	it("are found in the code", function()
		assert.is_not_nil(sent.Ready)
		assert.is_not_nil(heard.ProfileChanged)
	end)

	it("are all in the table, with their payload and sender", function()
		for _, list in ipairs({ found.sends, found.listens }) do
			for _, use in ipairs(list) do
				assert.is_not_nil(messages[use[1]], ("%s uses %s, which is not in Bus.MESSAGES"):format(use[2], use[1]))
			end
		end
		for name, message in pairs(messages) do
			assert.equals("string", type(message.payload), name .. " has no payload")
			assert.is_true(type(message.from) == "string" and message.from ~= "", name .. " has no sender")
		end
	end)

	it("are sent when something listens to them", function()
		for name, where in pairs(heard) do
			assert.is_not_nil(sent[name], ("%s listens to %s, which nothing sends"):format(where, name))
		end
	end)

	it("are listened to, or the table says why not", function()
		for name, message in pairs(messages) do
			assert.is_not_nil(sent[name], name .. " is in Bus.MESSAGES but nothing sends it")
			if message.unheard then
				assert.is_nil(heard[name], ("%s listens to %s, which the table calls unheard"):format(heard[name] or "", name))
			else
				assert.is_not_nil(heard[name], ("%s sends %s, which nothing listens to"):format(sent[name], name))
			end
		end
	end)

	it("are named in place, so the table can be checked", function()
		assert.same({}, found.dynamic)
	end)
end)
