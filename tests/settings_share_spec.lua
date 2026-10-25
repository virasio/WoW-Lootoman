local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

describe("share and import dialogs", function()
	local ns, api, Dialogs, Storage, Layouts, Test

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
		Dialogs, Storage, Layouts, Test = ns.SettingsPanel.Share, ns.Storage, ns.Feed.Layouts, ns.Compat.Test
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
			Storage:Set("LootFeed", "maxRows", 12)
			Layouts.Create("Raid", "compact")
			Dialogs.OpenShare("profile")
			frame = Dialogs.shareFrame
		end)

		it("lists each module's settings with its parts under them, then the layouts, with only the profile's own ticked", function()
			assert.same({
				"Fast autoloot settings [x]", "Loot feed settings [x]", "  Position [x]", "  Use layout “Default” [x]",
				"# Loot feed layouts", "  Default [x]", "  Raid [ ]",
			}, shown(frame))
		end)

		it("shows the text of the ticked lines, selected", function()
			assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed", "layout:LootFeed" }, read().names)
			assert.same({ "Default" }, read().collections.layouts.names)
			assert.equals(12, read().sections["module:LootFeed"].maxRows)
			tick(frame, "Raid", true)
			assert.same({ "Default", "Raid" }, read().collections.layouts.names)
		end)

		it("leaves the parts under the loot feed's settings out without them, and Use layout without its layout", function()
			tick(frame, "Default", false)
			assert.same({ "Fast autoloot settings [x]", "Loot feed settings [x]", "  Position [x]", "  Use layout “Default” (off)",
				"# Loot feed layouts", "  Default [ ]", "  Raid [ ]" }, shown(frame))
			assert.same({ "module:AutoLoot", "module:LootFeed", "positions:LootFeed" }, read().names)
			tick(frame, "Default", true)
			tick(frame, "Loot feed settings", false)
			assert.same({ "Loot feed settings [ ]", "  Position (off)", "  Use layout “Default” (off)" }, { unpack(shown(frame), 2, 4) })
			assert.same({ "module:AutoLoot" }, read().names)
			tick(frame, "Loot feed settings", true)
			assert.same({ "  Position [x]", "  Use layout “Default” [x]" }, { unpack(shown(frame), 3, 4) })
		end)

		it("keeps its text as it was made", function()
			local made = frame.box.EditBox.text
			typeInto(frame.box.EditBox, made .. "x")
			assert.equals(made, frame.box.EditBox.text)
		end)

		it("shares only layouts from the designer's menu, the current one ticked", function()
			Layouts.Use("Raid")
			ns.Bus:Send("OpenShareDialog", "layouts")
			assert.same({ "layouts", { "# Loot feed layouts", "  Default [ ]", "  Raid [x]" } }, { frame.mode, shown(frame) })
			assert.same({ {}, { "Raid" } }, { read().names, read().collections.layouts.names })
		end)
	end)

	describe("Import", function()
		local frame, exported

		-- A text from another player: the loot feed's settings using their
		-- layout Raid (compact), and their layout Solo.
		before_each(function()
			Storage:Set("LootFeed", "maxRows", 12)
			Layouts.Create("Raid", "compact")
			Layouts.Create("Solo", "minimal")
			Layouts.Use("Raid")
			exported = ns.Share.Export({ parts = { "module:LootFeed", "layout:LootFeed" }, collections = { layouts = { "Raid", "Solo" } } })
			Layouts.Use("Default")
			Layouts.Delete("Solo")
			Layouts.Delete("Raid")
			Layouts.Create("Raid", "large")
			Storage:Set("LootFeed", "maxRows", 3)
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
			assert.same({ "Loot feed settings [x]", "  Use layout “Raid” [x]", "# Loot feed layouts", "  Raid [x] both", "  Solo [x]" },
				shown(frame))
			typeInto(frame.box.EditBox, "nonsense")
			assert.same({ "This is not a Lootoman profile text.", false, {} }, { frame.status.text, frame.importButton.enabled, shown(frame) })
		end)

		it("lets Use layout be ticked only with the loot feed's settings and the layout", function()
			typeInto(frame.box.EditBox, exported)
			tick(frame, "Raid", false)
			assert.equals("  Use layout “Raid” (off)", shown(frame)[2])
			tick(frame, "Raid", true)
			tick(frame, "Loot feed settings", false)
			assert.equals("  Use layout “Raid” (off)", shown(frame)[2])
			-- Layouts alone need no name for a profile.
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
			assert.same({ "Imported", 12, "Raid", "compact", false },
				{ ns.Profiles.GetCurrent(), Storage:Get("LootFeed", "maxRows"), Layouts.Current(), Layouts.Get("Raid").base, frame.shown })
			assert.matches("Imported Loot feed layouts: Raid, Solo%.$", Test.state.printed[#Test.state.printed])
			assert.matches("Imported into profile “Imported”%.$", Test.state.printed[#Test.state.printed - 1])
		end)

		it("keeps both by default: the profile uses the imported copy", function()
			typeInto(frame.box.EditBox, exported)
			click(frame.importButton)
			assert.same({ "Raid 2", "compact", "large" }, { Layouts.Current(), Layouts.Get("Raid 2").base, Layouts.Get("Raid").base })
		end)

		it("puts them into the current profile instead, after a confirmation", function()
			typeInto(frame.box.EditBox, exported)
			frame.replace.checked = true
			click(frame.replace)
			assert.is_false(frame.name.enabled)
			click(frame.importButton)
			assert.equals(3, Storage:Get("LootFeed", "maxRows"))
			assert.equals("Default", api.popups[1].data.text_arg1)
			api.AcceptPopup()
			assert.same({ "Default", 12, "Raid 2" }, { ns.Profiles.GetCurrent(), Storage:Get("LootFeed", "maxRows"), Layouts.Current() })
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
			typeInto(frame.box.EditBox, "LTM1:" .. ns.Compat.Encode({ format = 1, sections = { ["module:LootFeed"] = { maxRows = 99, fade = 2 } } }))
			click(frame.importButton)
			assert.matches("Values left out, unknown to this version of Lootoman or not valid: 1%.$", Test.state.printed[#Test.state.printed])
		end)

		it("takes only layouts from the designer's menu, touching no profile", function()
			ns.Bus:Send("OpenImportDialog", "layouts")
			typeInto(frame.box.EditBox, exported)
			assert.same({ "# Loot feed layouts", "  Raid [x] both", "  Solo [x]" }, shown(frame))
			assert.same({ false, false }, { frame.name.shown, frame.replace.shown })
			click(frame.importButton)
			assert.same({ "Default", 3, { "Default", "Raid", "Raid 2", "Solo" } },
				{ ns.Profiles.GetCurrent(), Storage:Get("LootFeed", "maxRows"), Layouts.List() })
		end)
	end)
end)
