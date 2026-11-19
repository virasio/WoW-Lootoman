local _, ns = ...

-- The text of the feed's low-space warning: a template of tokens in braces,
-- each with an optional colour, and the text between them, in the default
-- colour: "{general}+{reagent|1eff00}". Tokens are the same in every locale,
-- and stand for the free slots Bags.FreeSlots() counts. A colour is six hex
-- digits (RRGGBB) or eight (AARRGGBB). A token the template does not know, or
-- a broken colour, stays as typed, so a typo shows.
local L = ns.L

ns.Feed = ns.Feed or {}
local SlotsText = {}
ns.Feed.SlotsText = SlotsText

-- Today's warning: general slots white, reagent ones in the green of uncommon
-- items, joined by "+".
SlotsText.DEFAULT = "{general}+{reagent|1eff00}"

-- Token names and the Bags.FreeSlots() value each one shows.
SlotsText.TOKENS = {
	{ "free", "free" },
	{ "total", "total" },
	{ "used", "used" },
	{ "general", "general" },
	{ "general.total", "generalTotal" },
	{ "reagent", "reagent" },
	{ "reagent.total", "reagentTotal" },
	{ "profession", "profession" },
	{ "profession.total", "professionTotal" },
}

-- The Bags.FreeSlots() value a token shows, or nil for an unknown token.
local function valueOf(name)
	for _, token in ipairs(SlotsText.TOKENS) do
		if token[1] == name then
			return token[2]
		end
	end
end

-- The colour as AARRGGBB, or nil when it is not one.
local function color(text)
	if text:match("^%x%x%x%x%x%x$") then
		return "ff" .. text:lower()
	elseif text:match("^%x%x%x%x%x%x%x%x$") then
		return text:lower()
	end
	return nil
end

-- The template's parts in order: { text = … } for text as typed, { token =
-- name, color = AARRGGBB or nil } for a known token. A doubled "|", as an edit
-- box gives it back, counts as one.
function SlotsText.Parse(text)
	text = text:gsub("||", "|")
	local parts, position = {}, 1
	local function addText(piece)
		if piece ~= "" then
			local last = parts[#parts]
			if last and last.text then
				last.text = last.text .. piece
			else
				parts[#parts + 1] = { text = piece }
			end
		end
	end
	while true do
		local start, finish, inside = text:find("{([^{}]*)}", position)
		if not start then
			addText(text:sub(position))
			break
		end
		addText(text:sub(position, start - 1))
		local name, code = inside:match("^%s*([%w%.]+)%s*|%s*(%x+)%s*$")
		name = name or inside:match("^%s*([%w%.]+)%s*$")
		local tokenColor = code and color(code)
		if name and valueOf(name:lower()) and (code == nil or tokenColor) then
			parts[#parts + 1] = { token = name:lower(), color = tokenColor }
		else
			addText(text:sub(start, finish))
		end
		position = finish + 1
	end
	return parts
end

-- WoW reads "|" as the start of a colour or texture code; doubled, it is shown.
local function escape(text)
	return (text:gsub("|", "||"))
end

-- The text with the values (Bags.FreeSlots()), coloured: each token in its own
-- colour or the default one (AARRGGBB), the rest in the default colour.
function SlotsText.Render(text, values, defaultColor)
	local pieces = {}
	for _, part in ipairs(SlotsText.Parse(text)) do
		if part.token then
			local value = values[valueOf(part.token)]
			pieces[#pieces + 1] = ("|c%s%s|r"):format(part.color or defaultColor, tostring(value or 0))
		else
			pieces[#pieces + 1] = ("|c%s%s|r"):format(defaultColor, escape(part.text))
		end
	end
	return table.concat(pieces)
end

-- What the tokens stand for, one line each (or one per kind of bag), for the
-- look window to show under the template.
function SlotsText.Note()
	return table.concat({
		L["%s — free slots in all bags"]:format("{free}"),
		L["%s — slots taken in all bags"]:format("{used}"),
		L["%s — all slots in all bags"]:format("{total}"),
		L["%s — free slots in the general, reagent and profession bags"]:format("{general}, {reagent}, {profession}"),
		L["%s — all slots in those bags"]:format("{general.total}, {reagent.total}, {profession.total}"),
		L["A colour after a bar: %s"]:format("{reagent|33ff33}"),
	}, "\n")
end
