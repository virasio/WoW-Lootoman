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

-- Hundredths as a number with up to two decimals ("12", "1.5", "1.23"), or
-- always two ("1.20"); point is the decimal point.
local function decimals(hundredths, point, keepZeros)
	local whole, rest = math.floor(hundredths / 100), hundredths % 100
	if keepZeros then
		return ("%d%s%02d"):format(whole, point, rest)
	elseif rest == 0 then
		return tostring(whole)
	elseif rest % 10 == 0 then
		return ("%d%s%d"):format(whole, point, rest / 10)
	end
	return ("%d%s%02d"):format(whole, point, rest)
end

-- A number of 0 or more, short enough for an icon, cut and never rounded:
-- below 1,000 whole ("850"); thousands with up to two decimals below 100,000
-- ("1.5K", "12.34K"), then whole thousands ("123K"); millions alike ("1.23M",
-- "123M"). point is the decimal point, "." by default.
function Text.ShortNumber(number, point)
	point = point or "."
	local whole = math.floor(number)
	if whole < 1000 then
		return tostring(whole)
	end
	local unit, format = 1000, ns.L["%sK"]
	if whole >= 1000000 then
		unit, format = 1000000, ns.L["%sM"]
	end
	if whole < 100 * unit then
		return format:format(decimals(math.floor(whole * 100 / unit), point))
	end
	return format:format(tostring(math.floor(whole / unit)))
end

-- Money short enough for an icon, cut and never rounded: the text and the
-- coin it counts ("gold", "silver" or "copper"). Copper below a silver
-- ("78"); silver with its copper as two decimals ("1.23"); gold below 100 with
-- its silver ("1.02"), then whole gold below 1,000 ("123"), then as
-- ShortNumber ("1.23K").
function Text.ShortMoney(copper, point)
	point = point or "."
	copper = math.floor(copper)
	if copper < 100 then
		return tostring(copper), "copper"
	elseif copper < 10000 then
		return decimals(copper, point, true), "silver"
	end
	local gold = math.floor(copper / 10000)
	if gold < 100 then
		return decimals(math.floor(copper / 100), point, true), "gold"
	elseif gold < 1000 then
		return tostring(gold), "gold"
	end
	return Text.ShortNumber(gold, point), "gold"
end

-- Characters, not bytes: Cyrillic letters take two bytes in UTF-8.
function Text.Length(text)
	return select(2, text:gsub("[^\128-\191]", ""))
end

-- The first maxLength characters of a text, never half a character.
function Text.Truncate(text, maxLength)
	local count, cut = 0, 0
	for start, char in text:gmatch("()([^\128-\191][\128-\191]*)") do
		count = count + 1
		if count > maxLength then
			break
		end
		cut = start + #char - 1
	end
	return text:sub(1, cut)
end

-- A name for a profile or a layout: without spaces around it, not empty, at
-- most maxLength characters, and none of the keys of names regardless of
-- letter case, also in Cyrillic. "Default" is shown in the client language,
-- so that name is taken too. renaming is the name being changed, which the
-- new one may match. Returns the name, or nil and "empty", "too_long" or
-- "exists".
function Text.CheckName(name, names, maxLength, renaming)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return nil, "empty"
	end
	if Text.Length(name) > maxLength then
		return nil, "too_long"
	end
	local folded = Text.FoldCase(name)
	for existing in pairs(names) do
		if existing ~= renaming and Text.FoldCase(existing) == folded then
			return nil, "exists"
		end
	end
	if folded == Text.FoldCase(ns.L["Default"]) then
		return nil, "exists"
	end
	return name
end
