local _, ns = ...
local Text = ns.Text

-- Exists only when the addon runs from the repository: the packager removes
-- the #@debug@ block from the TOC. /ltm demo <name> shows something made up,
-- for testing and for pictures: /ltm demo loot (loot in the feed), /ltm demo
-- roll (the loot rolls' demo), /ltm demo lootrolls (the Loot Rolls window on
-- made-up drops) and /ltm demo rollhistory (the roll history on a made-up
-- history); /ltm demo alone lists them. Neither /ltm help nor
-- /ltm debug help names them. Development text is not translated.

local demos = {}

-- A made-up thing to show, /ltm demo <name>, with its line in /ltm demo.
function ns.Slash.RegisterDemo(name, handler, help)
	assert(not demos[name], ("the demo %s is already registered"):format(name))
	demos[name] = { handler = handler, help = help }
end

local function list()
	ns.Print("Demos, in the repository's version only:")
	local names = {}
	for name in pairs(demos) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ns.Print(demos[name].help)
	end
end

-- A player's command without a line of help: /ltm help leaves it out.
ns.Slash.Register("demo", function(argument)
	local name, rest = (argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local demo = name ~= "" and demos[Text.FoldCase(name)]
	if demo then
		-- An error goes to the journal (and BugSack) instead of passing unseen.
		if not xpcall(function()
			demo.handler(rest)
		end, ns.Compat.ReportError) then
			ns.Print(("demo %s failed: /ltm debug log"):format(name))
		end
	else
		list()
	end
end)
