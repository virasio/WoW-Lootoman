local _, ns = ...
local Compat, L = ns.Compat, ns.L

-- Getting rid of junk (Rules/Junk.lua decides what it is): a button by the
-- loot window opens the sort window, a bag-like window with the junk on top,
-- to delete things; at a merchant, Lootoman's sell-junk button sells the junk
-- or opens the same window to pick what to sell. Dragging an item between the
-- sections of either window marks it.
-- No switch of its own: the sort window's button can be turned off (Never),
-- and the sell button always takes the place of the game's.
local Junk = ns.Modules:Register({
	name = "Junk",
	title = L["Junk"],
	switchLabel = false,
	defaults = {
		enabled = true,
		-- The sort window's button on the loot window: "never", "always" or "full".
		tossButton = "full",
		-- Small on the loot window's title bar, or large next to it.
		tossStyle = "large",
		-- At merchants (SellButton.lua): "auto", "button" or "window".
		selling = "window",
	},
	mainSettings = {
		{ kind = "choice", key = "tossButton", label = L["Sort window button"],
			tooltip = L["The button by the loot window opens a window of your bags with the junk on top, to throw things away."],
			choices = { { "never", L["Never"] }, { "always", L["Always"] }, { "full", L["When the bags are full"] } } },
		{ kind = "choice", key = "tossStyle", label = L["Style"], level = 2,
			choices = { { "small", L["Small, in the window's title"] }, { "large", L["Large, next to the window"] } },
			enabledWhen = function()
				return ns.Storage:Get("Junk", "tossButton") ~= "never"
			end },
		{ kind = "choice", key = "selling", label = L["At merchants"],
			choices = { { "auto", L["Sell automatically"] }, { "button", L["Sell with the sell button"] },
				{ "window", L["The sell button opens the sort window"] } } },
		{ kind = "button", label = L["Set up the junk list"],
			tooltip = L["Every item you marked as junk or as not junk, to remove marks."],
			click = function()
				ns.JunkList.Open()
			end },
	},
})

-- Texts of 0.1 to 0.4 (format 1) held selling as two switches and the large
-- button's size and place: they become the choices of now, as saved data did
-- (Migrations.JunkFrom).
ns.Share.RegisterUpgrade(1, function(data)
	local sections = type(data.sections) == "table" and data.sections or nil
	local junk = sections and sections["module:Junk"]
	if type(junk) == "table" then
		sections["module:Junk"] = ns.Migrations.JunkFrom(junk)
	end
end)

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
