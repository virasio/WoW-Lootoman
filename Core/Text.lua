local _, ns = ...

-- Text helpers for UTF-8 strings.
local Text = {}
ns.Text = Text

-- Lower case for comparing text regardless of letter case: A–Z, the Latin-1
-- letters with accents (À–Þ) and Cyrillic (А–Я, Ѐ–Џ). Lua's string.lower
-- changes only A–Z. Other characters stay as they are.
function Text.FoldCase(text)
	return (text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(char)
		if #char == 1 then
			return char:lower()
		end
		if #char ~= 2 then
			return char
		end
		local first, second = char:byte(1, 2)
		local code = (first - 192) * 64 + (second - 128)
		if (code >= 0xC0 and code <= 0xDE and code ~= 0xD7) or (code >= 0x410 and code <= 0x42F) then
			code = code + 0x20
		elseif code >= 0x400 and code <= 0x40F then
			code = code + 0x50
		else
			return char
		end
		return string.char(192 + math.floor(code / 64), 128 + code % 64)
	end))
end
