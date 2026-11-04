local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- The settings, in groups, for the module's own page.
local function settings()
	return {
		{ kind = "header", label = L["Toss button"] },
		{ kind = "dropdown", key = "tossButton", label = L["Show the toss button"],
			tooltip = L["The button by the loot window opens a window of your bags with the junk on top, to throw things away."],
			choices = { { "always", L["Always"] }, { "full", L["When the bags are full"] }, { "never", L["Never"] } } },
		{ kind = "dropdown", key = "tossStyle", label = L["Button style"],
			choices = { { "small", L["Small, on the loot window"] }, { "large", L["Large, outside the loot window"] } } },
		{ kind = "slider", key = "tossSize", label = L["Button size"], tooltip = L["For the large button."],
			min = 32, max = 64, step = 2, format = "%d" },
		{ kind = "dropdown", key = "tossSide", label = L["Side of the loot window"], tooltip = L["For the large button."],
			choices = { { "left", L["Left"] }, { "right", L["Right"] }, { "top", L["Top"] }, { "bottom", L["Bottom"] } } },
		{ kind = "slider", key = "tossOffset", label = L["Offset along the side"], tooltip = L["For the large button."],
			min = -200, max = 200, step = 2, format = "%d" },
		{ kind = "header", label = L["Selling"] },
		{ kind = "checkbox", key = "sellOnOpen", label = L["Sell junk at merchants"],
			tooltip = L["Sells the junk as soon as a merchant's window opens."] },
		{ kind = "checkbox", key = "swapClicks", label = L["Swap click and Shift-click"],
			tooltip = L["The sell-junk button then opens the sell window on a click, and sells the junk on Shift-click."] },
	}
end

-- Getting rid of junk (Rules/Junk.lua decides what it is): a toss button by
-- the loot window opens a bag-like window with the junk on top, to delete
-- things; at a merchant, Lootoman's sell-junk button sells the junk, and a sell
-- window like the toss window picks more. Dragging an item between the
-- sections of either window marks it.
local Junk = ns.Modules:Register({
	name = "Junk",
	title = L["Junk"],
	switchLabel = L["Enable junk tossing and selling"],
	description = L["A button by the loot window opens your bags with the junk on top, to throw things away, and junk is sold at merchants."],
	defaults = {
		enabled = true,
		tossButton = "full",
		tossStyle = "small",
		tossSize = 40,
		tossSide = "right",
		tossOffset = 0,
		sellOnOpen = true,
		swapClicks = false,
	},
	mainSettings = {
		{ kind = "checkbox", key = "sellOnOpen", label = L["Sell junk at merchants"],
			tooltip = L["Sells the junk as soon as a merchant's window opens."] },
	},
	settings = settings,
})

-- The module's parts (the toss button and window, the sale, the sell button
-- and window), started in order with the module and stopped in reverse:
-- part.Enable() and part.Disable(). Disable also undoes a part that started
-- halfway, or did not start.
local parts = {}

function Junk.AddPart(part)
	parts[#parts + 1] = part
end

-- Parts listen through the module, so several of them can listen to the same
-- event or message, and all of it stops with the module.
local listeners = { events = {}, messages = {} }

local function listen(kind, name, fn)
	local list = listeners[kind][name]
	if not list then
		list = {}
		listeners[kind][name] = list
		-- One broken part is reported and the others still hear it. (Lua 5.1's
		-- xpcall passes no arguments on.)
		local function dispatch(...)
			local count, args = select("#", ...), { ... }
			for _, listener in ipairs(list) do
				xpcall(function()
					listener(unpack(args, 1, count))
				end, Compat.ReportError)
			end
		end
		if kind == "events" then
			Junk:OnEvent(name, dispatch)
		else
			Junk:On(name, dispatch)
		end
	end
	list[#list + 1] = fn
end

-- fn(event, ...) for a game event while the module is on.
function Junk.ListenEvent(event, fn)
	listen("events", event, fn)
end

-- fn(message, ...) for a bus message while the module is on.
function Junk.Listen(message, fn)
	listen("messages", message, fn)
end

function Junk:OnEnable()
	for _, part in ipairs(parts) do
		part.Enable()
	end
end

function Junk:OnDisable()
	for index = #parts, 1, -1 do
		xpcall(parts[index].Disable, Compat.ReportError)
	end
	listeners = { events = {}, messages = {} }
end

function Junk:BuildSettings(category, layout)
	ns.SettingsPanel.AddSettings(category, layout, self.name, self:Settings())
	for _, builder in ipairs(Junk.pageBuilders or {}) do
		builder(category, layout)
	end
end

-- builder(category, layout) adds to the module's page, after its settings.
function Junk.AddToPage(builder)
	Junk.pageBuilders = Junk.pageBuilders or {}
	Junk.pageBuilders[#Junk.pageBuilders + 1] = builder
end
