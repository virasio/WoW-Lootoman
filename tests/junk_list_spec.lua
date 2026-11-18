local Loader = require("tests.helpers.loader")
local SettingsAPI = require("tests.mocks.SettingsAPI")

-- The junk list window.
describe("junk list window", function()
	local ns, api, JunkList, Marks, Test, inserted

	local function texts(mark)
		local list = {}
		for index, line in ipairs(JunkList.Lines(mark)) do
			list[index] = line.text
		end
		return list
	end

	local function rowFor(itemID)
		for _, entry in ipairs(JunkList.Window().rows) do
			if entry:IsShown() and entry.line and entry.line.itemID == itemID then
				return entry
			end
		end
	end

	local function click(button)
		button.scripts.OnClick(button)
	end

	before_each(function()
		api = SettingsAPI.Install()
		inserted = {}
		rawset(_G, "ChatFrameUtil", { InsertLink = function(text)
			inserted[#inserted + 1] = text
			return false
		end })
		ns = Loader.LoadAddon({ skip = {} })
		Test = ns.Compat.Test
		Loader.Start(ns)
		JunkList, Marks = ns.JunkList, ns.Marks
		Test.SetItems({
			[10] = { name = "Zebra Hide", link = "|Hitem:10|h[Zebra Hide]|h", icon = 1010 },
			[20] = { name = "Apple", link = "|Hitem:20|h[Apple]|h", icon = 1020 },
			[30] = { name = "Old Boot", link = "|Hitem:30|h[Old Boot]|h", icon = 1030 },
		})
		Test.SetBags({ [0] = { size = 4, items = {
			[1] = { itemID = 30, link = "|Hitem:30|h[Old Boot]|h", name = "Old Boot", quality = 0, count = 1 },
		} } })
	end)

	after_each(function()
		rawset(_G, "ChatFrameUtil", nil)
	end)

	local function mainButton()
		for _, entry in ipairs(ns.SettingsPanel.main.items) do
			if entry.text == "Edit the Junk List" then
				return entry.region
			end
		end
	end

	it("is a window of its own, opened from the options' main page and from the junk windows, closed with Escape", function()
		assert.is_nil(api.FindCategory("Junk List"))
		assert.is_nil(JunkList.Window())
		click(mainButton())
		local frame = JunkList.Window().frame
		assert.same({ true, "Junk List", "LootomanJunkList" }, { frame.shown, frame.title, frame.name })
		-- Over the game's options window, which is HIGH.
		assert.equals("DIALOG", frame.strata)
		-- No button of its own to open itself.
		assert.is_nil(JunkList.Window().grid.listButton)
		assert.is_true(Loader.ui.PressEscape())
		assert.is_false(frame.shown)
		local grid = ns.Modules:Get("Junk").ItemGrid.Create({ name = "LootomanTestGrid", title = "Sort junk", kind = "toss" })
		assert.equals("Junk List", grid.listButton.text)
		click(grid.listButton)
		assert.is_true(frame.shown)
	end)

	it("opens right of the game's options window, level with its top, over it when the screen has no room", function()
		local panel = rawget(_G, "SettingsPanel")
		panel.shown, panel.right, panel.top = true, 1000, 900
		Loader.ui.UIParent.GetRight = function() return 1920 end
		JunkList.Open()
		local frame = JunkList.Window().frame
		assert.same({ { "TOPLEFT", Loader.ui.UIParent, "BOTTOMLEFT", 1004, 900 } }, frame.points)
		panel.right = 1800
		JunkList.Open()
		assert.same({ { "TOPLEFT", Loader.ui.UIParent, "BOTTOMLEFT", 1920 - frame:GetWidth(), 900 } }, frame.points)
		-- With the options closed (from the toss or sell window): in the middle.
		panel.shown = false
		JunkList.Open()
		assert.same({ { "CENTER" } }, frame.points)
	end)

	it("opens only out of combat the first time, and only while junk management is on", function()
		Test.SetCombat(true)
		assert.is_false(JunkList.Open())
		assert.matches("out of combat", Test.state.printed[#Test.state.printed])
		Test.SetCombat(false)
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(JunkList.Open())
		assert.matches("is off", Test.state.printed[#Test.state.printed])
		ns.Modules:SetEnabled("Junk", true)
		assert.is_true(JunkList.Open())
		ns.Modules:SetEnabled("Junk", false)
		assert.is_false(JunkList.Window().frame:IsShown())
	end)

	it("shows the bags on its first tab, where every move marks the item for good", function()
		JunkList.Open()
		local window = JunkList.Window()
		assert.same({ 1, 3, true, false }, { window.frame.selectedTab, window.frame.numTabs,
			window.grid.sections.junk.frame:IsShown(), window.list:IsShown() })
		local entry = window.grid.built.junk.entries[1]
		assert.equals(30, entry.item.itemID)
		window.grid:MoveTo(entry, "rest", window.grid:ForGood())
		assert.equals("notJunk", Marks.Get(30))
	end)

	it("lists the items marked junk, and those marked not junk, each by name", function()
		assert.same({}, texts("junk"))
		Marks.Set(10, "junk")
		Marks.Set(20, "junk")
		Marks.Set(30, "notJunk")
		Marks.Set(99, "junk")
		assert.same({ "Item 99", "|Hitem:20|h[Apple]|h", "|Hitem:10|h[Zebra Hide]|h" }, texts("junk"))
		assert.same({ "|Hitem:30|h[Old Boot]|h" }, texts("notJunk"))
		JunkList.Open(JunkList.JUNK)
		local window = JunkList.Window()
		assert.same({ 2, false, true }, { window.frame.selectedTab, window.grid.sections.junk.frame:IsShown(), window.list:IsShown() })
		assert.is_not_nil(rowFor(10))
		assert.is_nil(rowFor(30))
		assert.is_false(window.empty:IsShown())
		click(window.frame.Tabs[3])
		assert.same({ true, false }, { rowFor(30) ~= nil, rowFor(10) ~= nil })
	end)

	it("adds an item dropped from the bags, a pasted link, or a typed item ID to the tab's list", function()
		JunkList.Open(JunkList.NOT_JUNK)
		local window = JunkList.Window()
		Test.state.cursorItem = 10
		window.list.scripts.OnReceiveDrag(window.list)
		assert.same({ "notJunk", nil }, { Marks.Get(10), Test.state.cursorItem })
		click(window.frame.Tabs[2])
		window.field:SetText("|cff9d9d9d|Hitem:20::::::::60:::::|h[Apple]|h|r")
		click(window.add)
		window.field:SetText(" 30 ")
		window.field.scripts.OnEnterPressed(window.field)
		assert.same({ "notJunk", "junk", "junk", "" }, { Marks.Get(10), Marks.Get(20), Marks.Get(30), window.field:GetText() })
		window.field:SetText("Apple")
		click(window.add)
		assert.matches("neither an item link nor an item ID", Test.state.printed[#Test.state.printed])
		assert.equals("Apple", window.field:GetText())
	end)

	it("takes a Shift-clicked item's link into the field while it is active", function()
		JunkList.Open(JunkList.JUNK)
		local window = JunkList.Window()
		local insertLink = rawget(_G, "ChatFrameUtil").InsertLink
		insertLink("|Hitem:20|h[Apple]|h")
		assert.equals("", window.field:GetText())
		window.field.HasFocus = function() return true end
		insertLink("|Hspell:5|h[Spell]|h")
		assert.equals("", window.field:GetText())
		insertLink("|Hitem:20|h[Apple]|h")
		assert.equals("|Hitem:20|h[Apple]|h", window.field:GetText())
		assert.same({ "|Hitem:20|h[Apple]|h", "|Hspell:5|h[Spell]|h", "|Hitem:20|h[Apple]|h" }, inserted)
	end)

	it("reads item IDs from links and numbers only", function()
		assert.same({ 2589, 2589, 12, nil, nil, nil }, { JunkList.ParseItem("|Hitem:2589::|h[Linen]|h"), JunkList.ParseItem("item:2589"),
			JunkList.ParseItem("12"), JunkList.ParseItem("0"), JunkList.ParseItem("Linen"), JunkList.ParseItem(nil) })
	end)

	it("removes one mark, and clears them all after a question", function()
		Marks.Set(10, "junk")
		Marks.Set(30, "notJunk")
		JunkList.Open(JunkList.JUNK)
		local window = JunkList.Window()
		local zebra = rowFor(10)
		click(zebra.remove)
		assert.same({ { itemID = 30, mark = "notJunk" } }, Marks.List())
		assert.is_nil(rowFor(10))
		assert.is_true(window.empty:IsShown())
		click(window.clear)
		assert.same({ { itemID = 30, mark = "notJunk" } }, Marks.List())
		api.AcceptPopup()
		assert.same({}, Marks.List())
		assert.is_false(window.clear:IsEnabled())
	end)

	it("clears nothing when the profile changed while the question was open", function()
		Marks.Set(10, "junk")
		JunkList.Open(JunkList.JUNK)
		click(JunkList.Window().clear)
		ns.Profiles.Create("Alt")
		ns.Profiles.Switch("Alt")
		Marks.Set(20, "junk")
		api.AcceptPopup()
		assert.same({ { itemID = 20, mark = "junk" } }, Marks.List())
		ns.Profiles.Switch("Default")
		assert.same({ { itemID = 10, mark = "junk" } }, Marks.List())
	end)

	it("follows the profile", function()
		Marks.Set(10, "junk")
		JunkList.Open(JunkList.JUNK)
		ns.Profiles.Create("Alt")
		ns.Profiles.Switch("Alt")
		assert.is_nil(rowFor(10))
		ns.Profiles.Switch("Default")
		assert.is_not_nil(rowFor(10))
	end)

	it("shares and imports the junk list alone", function()
		JunkList.Open()
		local window, Dialogs = JunkList.Window(), ns.SettingsPanel.Share
		click(window.share)
		assert.same({ true, "part:marks" }, { Dialogs.shareFrame:IsShown(), Dialogs.shareFrame.mode })
		click(window.import)
		assert.same({ true, "part:marks" }, { Dialogs.importFrame:IsShown(), Dialogs.importFrame.mode })
	end)

	describe("items marked otherwise in an imported list", function()
		local conflicts

		before_each(function()
			Marks.Set(10, "notJunk")
			Marks.Set(20, "junk")
			JunkList.ShowConflicts({ { itemID = 10, mine = "notJunk", theirs = "junk" }, { itemID = 20, mine = "junk", theirs = "notJunk" } })
			conflicts = JunkList.Conflicts()
		end)

		it("shows them one by one, with the item's tooltip: what it is here and in the text", function()
			assert.same({ true, "1 of 2", "|Hitem:10|h[Zebra Hide]|h", 1010, "Here: Not Junk", "In the text: Junk" },
				{ conflicts:IsShown(), conflicts.count.text, conflicts.name.text, conflicts.icon.texture, conflicts.here.text, conflicts.there.text })
			assert.same({ true, 10, conflicts }, { Loader.ui.tooltip.shown, Loader.ui.tooltip.item, Loader.ui.tooltip.owner })
		end)

		it("keeps mine or takes theirs, then closes after the last", function()
			click(conflicts.take)
			assert.same({ "junk", "2 of 2" }, { Marks.Get(10), conflicts.count.text })
			click(conflicts.keep)
			assert.same({ "junk", false }, { Marks.Get(20), conflicts:IsShown() })
		end)

		it("changes nothing once the profile is another", function()
			ns.Profiles.Create("Alt")
			ns.Profiles.Switch("Alt")
			click(conflicts.take)
			assert.same({ false, nil }, { conflicts:IsShown(), Marks.Get(10) })
			ns.Profiles.Switch("Default")
			assert.equals("notJunk", Marks.Get(10))
		end)
	end)
end)

