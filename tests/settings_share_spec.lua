local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("share and import dialogs", function()
	local ns, api, Dialogs, Storage, Looks, Test

	-- The profile menu's entry with this text.
	local function menuEntry(text)
		for _, entry in ipairs(api.OpenMenu(ns.SettingsPanel.main.profile).entries) do
			if entry.text == text then
				return entry
			end
		end
	end

	-- What a player does to an edit box: types, and its hooks run.
	local function typeInto(editBox, text)
		editBox.text = text
		for _, hook in ipairs(editBox.hooks.OnTextChanged) do
			hook(editBox, true)
		end
	end

	local function click(button)
		button.scripts.OnClick(button)
	end

	-- The dialog's lines from the top: a header as "# Text"; a row as its label
	-- with "  " for an indent, then [x], [ ] or "(off)" when it cannot be ticked,
	-- and the choice for a taken name.
	local function shown(frame)
		local list = {}
		for _, header in ipairs(frame.headers) do
			if header.shown then
				list[#list + 1] = { y = header.points[1][5], text = "# " .. header.text }
			end
		end
		for _, entry in ipairs(frame.rows) do
			if entry.check.shown then
				local check = entry.check
				local indent = (check.points[1][4] - 20) / 24
				local state = not check.enabled and "(off)" or check.checked and "[x]" or "[ ]"
				local how = entry.how and entry.how.shown and (" " .. frame.how[entry.item]) or ""
				list[#list + 1] = { y = check.points[1][5], text = ("  "):rep(indent) .. check.label.text .. " " .. state .. how }
			end
		end
		table.sort(list, function(a, b) return a.y > b.y end)
		for index, line in ipairs(list) do
			list[index] = line.text
		end
		return list
	end

	-- Ticks or unticks the row with this label.
	local function tick(frame, label, checked)
		for _, entry in ipairs(frame.rows) do
			if entry.check.shown and entry.check.label.text == label then
				entry.check.checked = checked
				return click(entry.check)
			end
		end
		error("no row " .. label)
	end

	before_each(function()
		api = SettingsAPI.Install()
		ns = Loader.LoadAddon({ skip = {} })
		Loader.Start(ns)
		Dialogs, Storage, Looks, Test = ns.SettingsPanel.Share, ns.Storage, ns.Feed.Looks, ns.Compat.Test
	end)

	it("open from Import and Share at the end of the profile menu", function()
		local entries = api.OpenMenu(ns.SettingsPanel.main.profile).entries
		assert.same({ "Import", "Share" }, { entries[#entries - 1].text, entries[#entries].text })
		assert.same({ "Share", "Makes a text of the current profile to copy and give to another character or player." },
			menuEntry("Share"):TooltipLines())
		menuEntry("Share").callback()
		assert.same({ true, "profile" }, { Dialogs.shareFrame.shown, Dialogs.shareFrame.mode })
		menuEntry("Import").callback()
		assert.same({ false, true, "profile" }, { Dialogs.shareFrame.shown, Dialogs.importFrame.shown, Dialogs.importFrame.mode })
	end)

	it("close on Escape, through the game's own list of windows", function()
		Dialogs.OpenShare("profile")
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(Dialogs.shareFrame.shown)
		Dialogs.OpenImport("profile")
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(Dialogs.importFrame.shown)
		assert.is_false(Loader.ui.PressEscape())
	end)

	it("cannot be opened on a client that cannot make profile texts", function()
		Test.state.encoder = false
		for _, text in ipairs({ "Import", "Share" }) do
			assert.is_false(menuEntry(text).enabled, text)
			assert.equals("This game client cannot make or read profile texts.", menuEntry(text):TooltipLines()[2])
		end
	end)

	it("open only out of combat the first time", function()
		Test.SetCombat(true)
		Dialogs.OpenShare("profile")
		assert.is_nil(Dialogs.shareFrame)
		assert.matches("out of combat", Test.state.printed[#Test.state.printed])
		Test.SetCombat(false)
		Dialogs.OpenShare("profile")
		assert.is_true(Dialogs.shareFrame.shown)
	end)

	describe("Share", function()
		local frame

		local function read()
			return assert(ns.Share.Read(frame.box.EditBox.text))
		end

		before_each(function()
			Storage:Set("AutoLoot", "confirmBind", false)
			Looks.Create("Raid")
			Dialogs.OpenShare("profile")
			frame = Dialogs.shareFrame
		end)

		it("lists each module's settings with its parts under them, then the looks, with only the profile's own ticked", function()
			assert.same({
				"Fast autoloot settings [x]", "Loot feed settings [x]", "  Position [x]", "  Use look “Default” [x]",
				"Junk settings [x]",
				"# Loot feed looks", "  Default [x]", "  Raid [ ]",
			}, shown(frame))
		end)

		it("shows the text of the ticked lines, selected", function()
			assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "look:LootFeed", "module:Junk" }, read().names)
			assert.same({ "Default" }, read().collections.looks.names)
			assert.is_false(read().sections["module:AutoLoot"].confirmBind)
			tick(frame, "Raid", true)
			assert.same({ "Default", "Raid" }, read().collections.looks.names)
		end)

		it("leaves the parts under the loot feed's settings out without them, and Use look without its look", function()
			tick(frame, "Default", false)
			assert.same({ "Fast autoloot settings [x]", "Loot feed settings [x]", "  Position [x]", "  Use look “Default” (off)",
				"Junk settings [x]",
				"# Loot feed looks", "  Default [ ]", "  Raid [ ]" }, shown(frame))
			assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "module:Junk" }, read().names)
			tick(frame, "Default", true)
			tick(frame, "Loot feed settings", false)
			assert.same({ "Loot feed settings [ ]", "  Position (off)", "  Use look “Default” (off)" }, { unpack(shown(frame), 2, 4) })
			assert.same({ "module:AutoLoot", "module:Junk" }, read().names)
			tick(frame, "Loot feed settings", true)
			assert.same({ "  Position [x]", "  Use look “Default” [x]" }, { unpack(shown(frame), 3, 4) })
		end)

		it("keeps its text as it was made", function()
			local made = frame.box.EditBox.text
			typeInto(frame.box.EditBox, made .. "x")
			assert.equals(made, frame.box.EditBox.text)
		end)

		it("shares only looks from the look menu, the current one ticked", function()
			Looks.Use("Raid")
			ns.Bus:Send("OpenShareDialog", "looks")
			assert.same({ "looks", { "# Loot feed looks", "  Default [ ]", "  Raid [x]" } }, { frame.mode, shown(frame) })
			assert.same({ {}, { "Raid" } }, { read().names, read().collections.looks.names })
		end)
	end)

	describe("Import", function()
		local frame, exported

		local function maxRows()
			return ns.Modules:Get("LootFeed"):Get("maxRows")
		end

		-- A text from another player: the loot feed using their look Raid
		-- (icons, 12 rows), and their look Solo.
		before_each(function()
			Looks.Create("Raid")
			Looks.SetView("Raid", "icons")
			Looks.Set("Raid", "maxRows", 12)
			Looks.Create("Solo")
			Looks.Use("Raid")
			exported = ns.Share.Export({ parts = { "module:LootFeed", "look:LootFeed" }, collections = { looks = { "Raid", "Solo" } } })
			Looks.Use("Default")
			Looks.Delete("Solo")
			Looks.Delete("Raid")
			Looks.Create("Raid")
			Dialogs.OpenImport("profile")
			frame = Dialogs.importFrame
		end)

		it("asks for a text, with a name for the new profile ready", function()
			assert.same({ "", "Paste a text made with Share.", "Imported", false },
				{ frame.box.EditBox.text, frame.status.text, frame.name.text, frame.importButton.enabled })
			assert.same({}, shown(frame))
			ns.Profiles.Create("Imported")
			Dialogs.OpenImport("profile")
			assert.equals("Imported 2", frame.name.text)
		end)

		it("says what a pasted text holds, everything ticked, and a choice for a taken name", function()
			typeInto(frame.box.EditBox, exported)
			assert.same({ "It holds the parts ticked below.", true }, { frame.status.text, frame.importButton.enabled })
			assert.same({ "Loot feed settings [x]", "  Use look “Raid” [x]", "# Loot feed looks", "  Raid [x] both", "  Solo [x]" },
				shown(frame))
			typeInto(frame.box.EditBox, "nonsense")
			assert.same({ "This is not a Lootoman profile text.", false, {} }, { frame.status.text, frame.importButton.enabled, shown(frame) })
		end)

		it("lets Use look be ticked only with the loot feed's settings and the look", function()
			typeInto(frame.box.EditBox, exported)
			tick(frame, "Raid", false)
			assert.equals("  Use look “Raid” (off)", shown(frame)[2])
			tick(frame, "Raid", true)
			tick(frame, "Loot feed settings", false)
			assert.equals("  Use look “Raid” (off)", shown(frame)[2])
			-- Looks alone need no name for a profile.
			assert.same({ false, true }, { frame.name.enabled, frame.importButton.enabled })
		end)

		it("puts the parts into a new profile, with the choice made for a taken name", function()
			typeInto(frame.box.EditBox, exported)
			for _, entry in ipairs(frame.rows) do
				if entry.how and entry.how.shown then
					local replace = api.OpenMenu(entry.how).entries[2]
					assert.equals("Replace", replace.text)
					replace.setSelected()
				end
			end
			assert.equals("  Raid [x] replace", shown(frame)[4])
			click(frame.importButton)
			assert.same({ "Imported", 12, "Raid", "icons", false },
				{ ns.Profiles.GetCurrent(), maxRows(), Looks.Current(), Looks.View("Raid"), frame.shown })
			assert.matches("Imported Loot feed looks: Raid, Solo%.$", Test.state.printed[#Test.state.printed])
			assert.matches("Imported into profile “Imported”%.$", Test.state.printed[#Test.state.printed - 1])
		end)

		it("keeps both by default: the profile uses the imported copy", function()
			typeInto(frame.box.EditBox, exported)
			click(frame.importButton)
			assert.same({ "Raid 2", "icons", "rows" }, { Looks.Current(), Looks.View("Raid 2"), Looks.View("Raid") })
		end)

		it("puts them into the current profile instead, after a confirmation", function()
			typeInto(frame.box.EditBox, exported)
			frame.replace.checked = true
			click(frame.replace)
			assert.is_false(frame.name.enabled)
			click(frame.importButton)
			assert.equals("Default", Looks.Current())
			assert.equals("Default", api.popups[1].data.text_arg1)
			api.AcceptPopup()
			assert.same({ "Default", 12, "Raid 2" }, { ns.Profiles.GetCurrent(), maxRows(), Looks.Current() })
		end)

		it("needs a name for the new profile, and tells why one is not taken", function()
			typeInto(frame.box.EditBox, exported)
			typeInto(frame.name, "  ")
			assert.is_false(frame.importButton.enabled)
			typeInto(frame.name, "Imported")
			ns.Profiles.Create("Imported")
			click(frame.importButton)
			assert.matches("already exists", Test.state.printed[#Test.state.printed])
			assert.is_true(frame.shown)
		end)

		it("tells how many values were left out", function()
			typeInto(frame.box.EditBox, "LTM1:" .. ns.Compat.Encode({ format = 1, sections = { ["module:AutoLoot"] = { confirmBind = 99, enabled = false } } }))
			click(frame.importButton)
			assert.matches("Values left out, unknown to this version of Lootoman or not valid: 1%.$", Test.state.printed[#Test.state.printed])
		end)

		it("takes only looks from the look menu, touching no profile", function()
			ns.Bus:Send("OpenImportDialog", "looks")
			typeInto(frame.box.EditBox, exported)
			assert.same({ "# Loot feed looks", "  Raid [x] both", "  Solo [x]" }, shown(frame))
			assert.same({ false, false }, { frame.name.shown, frame.replace.shown })
			click(frame.importButton)
			assert.same({ "Default", "Default", { "Default", "Raid", "Raid 2", "Solo" } },
				{ ns.Profiles.GetCurrent(), Looks.Current(), Looks.List() })
		end)
	end)
end)
