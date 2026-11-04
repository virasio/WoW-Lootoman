local _, ns = ...

-- The free-slot bar's text: a template of tokens in braces, each with an
-- optional colour, and the text between them, in the default colour:
-- "{free|33ff33} ({reagent|ffd100}) / {general}". Tokens are the same in every
-- locale. A colour is six hex digits (RRGGBB) or eight (AARRGGBB). A token the
-- template does not know, or a broken colour, stays as typed, so a typo shows.
local FreeSlots = ns.Modules:Get("FreeSlots")
local Template = {}
FreeSlots.Template = Template

-- Token names and the Bags.FreeSlots() value each one shows, in the order the
-- options list them.
Template.TOKENS = {
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

local valueOf = {}
for _, token in ipairs(Template.TOKENS) do
	valueOf[token[1]] = token[2]
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
function Template.Parse(text)
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
		if name and valueOf[name:lower()] and (code == nil or tokenColor) then
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
function Template.Render(text, values, defaultColor)
	local pieces = {}
	for _, part in ipairs(Template.Parse(text)) do
		if part.token then
			local value = values[valueOf[part.token]]
			pieces[#pieces + 1] = ("|c%s%s|r"):format(part.color or defaultColor, tostring(value or 0))
		else
			pieces[#pieces + 1] = ("|c%s%s|r"):format(defaultColor, escape(part.text))
		end
	end
	return table.concat(pieces)
end
