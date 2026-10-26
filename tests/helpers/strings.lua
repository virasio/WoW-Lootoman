-- Helpers for checking translation strings.

local Strings = {}

-- Format specifiers of a string as sorted "position:conversion" items, so a
-- translation may reorder them with "%2$s". "%%" is not a specifier.
function Strings.Placeholders(text)
	local found = {}
	local sequential = 0
	local position = 1
	while true do
		local start = text:find("%", position, true)
		if not start then
			break
		end
		if text:sub(start + 1, start + 1) == "%" then
			position = start + 2
		else
			local index, from = text:match("^(%d+)%$()", start + 1)
			local conversion, after = text:match("^[-+ #0]*%d*%.?%d*(%a)()", from or (start + 1))
			if not index then
				sequential = sequential + 1
				index = sequential
			end
			found[#found + 1] = index .. ":" .. (conversion or "?")
			position = after or (start + 1)
		end
	end
	table.sort(found)
	return found
end

-- Keys used as L["..."] or ns.L["..."] in Lua source, and the number of L[...]
-- uses whose key is not a plain string literal.
function Strings.FindKeys(source)
	local keys, nonLiteral = {}, 0
	local position = 1
	while true do
		local _, finish = source:find("%f[%w_]L%[", position)
		if not finish then
			break
		end
		local quote = source:match("^%s*([\"'])", finish + 1)
		local key, after
		if quote then
			key, after = source:match("^%s*" .. quote .. "(.-)" .. quote .. "%s*%]()", finish + 1)
		end
		if key then
			keys[#keys + 1] = key
			position = after
		else
			nonLiteral = nonLiteral + 1
			position = finish + 1
		end
	end
	return keys, nonLiteral
end

return Strings
