local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("bug report", function()
	local ns, Test

	before_each(function()
		SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		Test.state.capabilities["C_AddOns.GetAddOnMetadata"] = true
		Loader.Start(ns)
	end)

	it("has every part: the head, a self-test, the errors, the log, the options, the related addons", function()
		Test.state.time = 12
		ns.Compat.ReportError("Interface/AddOns/Lootoman/Here.lua:1: broken")
		local text = ns.BugReport.Build()
		local first = text:match("^[^\n]+")
		assert.equals("Lootoman @project-version@ · 12.1.5 (70575), interface 120105 · game Standard, project 1 · locale enUS · 2026-11-19 14:05", first)
		for _, part in ipairs({ "\nSelf%-test\n", "\n  Has: ", "\nErrors this session %(1%)\n  12%.00 Interface/AddOns/Lootoman/Here%.lua:1: broken\n      Interface/AddOns/Lootoman/Here%.lua:1: in function <here>\n",
			"\nExtended log: off\n", "\nOptions that differ from the defaults\n", "\n  Loot feed look “Default”: base large, view rows\n",
			"\nRelated addons loaded: none$" }) do
			assert.matches(part, text)
		end
		assert.matches("\nProfile Default\n", text)
	end)

	it("names neither the character nor its realm", function()
		ns.Storage:SetGlobal("debug", true)
		ns.Debug("Tester of Realm looted something")
		local text = ns.BugReport.Build()
		assert.is_nil(text:find("Tester", 1, true))
		-- The realm as a word: inside a function's name (GetNormalizedRealmName) it stays.
		assert.is_nil(text:find("%f[%w]Realm%f[%W]"))
		assert.matches("GetNormalizedRealmName", text)
		assert.matches("<name> of <realm> looted something", text)
	end)

	it("lists the options that differ from the defaults, the look's too, and the extended log while it is on", function()
		ns.Modules:Get("AutoLoot"):Set("confirmBind", false)
		ns.Feed.Looks.Set("Default", "maxRows", 9)
		ns.Storage:SetGlobal("debug", true)
		Test.state.time = 3
		ns.Debug("one line")
		local text = ns.BugReport.Build()
		assert.matches("\n  AutoLoot%.confirmBind = false\n", text)
		assert.matches("\n  account%.debug = true\n", text)
		assert.matches("\n  look%.maxRows = 9\n", text)
		assert.matches("\nExtended log %(the last 1 lines%)\n  3%.00 one line\n", text)
	end)

	it("names the related addons loaded, with their versions", function()
		Test.state.addons.Auctionator, Test.state.addons.BugSack = true, true
		Test.state.metadata.Auctionator = { Version = "300" }
		assert.matches("\nRelated addons loaded: Auctionator 300, BugSack %?$", ns.BugReport.Build())
	end)

	it("stays within 30,000 characters, the log cut first", function()
		ns.Storage:SetGlobal("debug", true)
		-- The last 100 lines of 400 letters: 40,000 characters of log alone.
		for index = 1, 300 do
			ns.Debug(("line %d %s"):format(index, ("x"):rep(400)))
		end
		local text = ns.BugReport.Build()
		assert.is_true(ns.Text.Length(text) <= ns.BugReport.MAX)
		assert.matches("line 300 ", text)
		assert.is_nil(text:find("line 201 ", 1, true))
		assert.matches("\nRelated addons loaded: none$", text)
	end)
end)

describe("bug report window", function()
	local ns, Window, frame

	before_each(function()
		SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Loader.Start(ns)
		Window = ns.BugReportWindow
		assert.is_true(Window.Open())
		frame = Window.Frame()
	end)

	it("opens with a fresh report, and builds it again on Refresh", function()
		assert.same({ true, "Bug Report", "LootomanBugReport" }, { frame.shown, frame.title, frame.name })
		assert.matches("^Lootoman ", frame.report.EditBox:GetText())
		ns.Compat.ReportError("late error")
		assert.not_matches("late error", frame.report.EditBox:GetText())
		frame.refresh.scripts.OnClick(frame.refresh)
		assert.matches("late error", frame.report.EditBox:GetText())
	end)

	it("switches the extended log with its checkbox", function()
		assert.is_false(frame.extended:GetChecked())
		frame.extended:SetChecked(true)
		frame.extended.scripts.OnClick(frame.extended)
		assert.is_true(ns.Storage:GetGlobal("debug"))
		assert.matches("\nExtended log %(the last 0 lines%)\n", frame.report.EditBox:GetText())
	end)

	it("keeps the address and the report as they are: typing puts them back", function()
		assert.equals("https://github.com/virasio/WoW-Lootoman/issues", frame.address:GetText())
		frame.address:SetText("something else")
		frame.address.scripts.OnTextChanged(frame.address, true)
		assert.equals("https://github.com/virasio/WoW-Lootoman/issues", frame.address:GetText())
		local report = frame.report.EditBox:GetText()
		frame.report.EditBox:SetText("typed")
		for _, hook in ipairs(frame.report.EditBox.hooks.OnTextChanged) do
			hook(frame.report.EditBox, true)
		end
		assert.equals(report, frame.report.EditBox:GetText())
	end)

	it("clears the log, the errors and the saved self-test", function()
		ns.Compat.ReportError("an error")
		frame.clear.scripts.OnClick(frame.clear)
		assert.same({ {}, {} }, { ns.Diagnostics.Section().errors, ns.Diagnostics.SessionErrors() })
		assert.matches("\nErrors this session %(0%)\n", frame.report.EditBox:GetText())
	end)

	it("opens with /ltm report, which the help lists", function()
		frame:Hide()
		local Test = ns.Compat.Test
		Test.RunSlashCommand("LOOTOMAN", "report")
		assert.is_true(frame.shown)
		Test.state.printed = {}
		Test.RunSlashCommand("LOOTOMAN", "help")
		local help = {}
		for _, line in ipairs(Test.state.printed) do
			help[#help + 1] = (line:gsub("^|cff%x+Lootoman|r: ", ""))
		end
		assert.same({ "/ltm junk: open the junk window", "/ltm report: open the bug report window", "/ltm help: list the commands" },
			{ help[#help - 2], help[#help - 1], help[#help] })
	end)

	it("closes with Escape, and opens the first time only out of combat", function()
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(frame.shown)
		SettingsAPI.Install()
		local fresh = Loader.LoadAddon({ skip = {} })
		Loader.Start(fresh)
		fresh.Compat.Test.SetCombat(true)
		assert.is_false(fresh.BugReportWindow.Open())
		assert.matches("out of combat", fresh.Compat.Test.state.printed[#fresh.Compat.Test.state.printed])
	end)
end)
